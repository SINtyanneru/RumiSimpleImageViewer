#import <stdio.h>
#import <stdlib.h>
#import <stdint.h>
#import <string.h>

#import "../rsiv.h"

static uint16_t mag_rd16(const uint8_t *p) {
	return (uint16_t)(p[0] | (p[1] << 8));
}

static uint32_t mag_rd32(const uint8_t *p) {
	return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

//相対コピー位置（Xは16ビット単位、Yは行単位）
static const int8_t MAG_DX[16] = {0, -1, -2, -4, 0, -1, 0, -1, -2, 0, -1, -2, 0, -1, -2, 0};
static const int8_t MAG_DY[16] = {0, 0, 0, 0, -1, -1, -2, -2, -2, -4, -4, -4, -8, -8, -8, -16};

Image *load_mag(FILE *f) {
	//ファイル全体を読み込む
	fseek(f, 0, SEEK_END);
	long file_size = ftell(f);
	rewind(f);

	if (file_size < 64)
		return NULL;

	uint8_t *buf = malloc(file_size);
	if (buf == NULL)
		return NULL;

	if (fread(buf, 1, file_size, f) != (size_t)file_size) {
		free(buf);
		return NULL;
	}

	//シグネチャ
	if (memcmp(buf, "MAKI02  ", 8) != 0) {
		free(buf);
		return NULL;
	}

	//コメントの後、最初の0x00がヘッダー先頭
	long hdr = -1;
	for (long i = 12; i < file_size; i++) {
		if (buf[i] == 0x00) {
			hdr = i;
			break;
		}
	}

	if (hdr < 0 || hdr + 32 > file_size) {
		free(buf);
		return NULL;
	}

	const uint8_t *head = buf + hdr;
	uint8_t scrmode = head[3];
	uint32_t xorig = mag_rd16(head + 4);
	uint32_t yorig = mag_rd16(head + 6);
	uint32_t xend = mag_rd16(head + 8);
	uint32_t yend = mag_rd16(head + 10);
	uint32_t flaga_off = mag_rd32(head + 12);
	uint32_t flagb_off = mag_rd32(head + 16);
	uint32_t flagb_size = mag_rd32(head + 20);
	uint32_t pxl_off = mag_rd32(head + 24);
	uint32_t pxl_size = mag_rd32(head + 28);

	int color256 = (scrmode & 0x80) != 0;

	//各ストリーム（オフセットはヘッダー先頭からの相対）
	if (hdr + pxl_off > file_size || flagb_off < flaga_off) {
		free(buf);
		return NULL;
	}

	const uint8_t *flaga = buf + hdr + flaga_off;
	const uint8_t *flagb = buf + hdr + flagb_off;
	const uint8_t *pxl = buf + hdr + pxl_off;
	size_t flaga_size = flagb_off - flaga_off;

	if (hdr + flagb_off + flagb_size > file_size)
		flagb_size = (uint32_t)(file_size - hdr - flagb_off);
	if (hdr + pxl_off + pxl_size > file_size)
		pxl_size = (uint32_t)(file_size - hdr - pxl_off);

	//パレット（ヘッダー直後〜フラグA直前、GRB順）
	RGBA palette[256];
	memset(palette, 0, sizeof(palette));

	int pal_count = (int)((long)flaga_off - 32) / 3;
	if (pal_count > 256)
		pal_count = 256;
	if (pal_count < 0)
		pal_count = 0;

	for (int i = 0; i < pal_count; i++) {
		const uint8_t *p = head + 32 + (size_t)i * 3;
		uint8_t *px = (uint8_t *)(palette + i);

		if (color256) {
			px[0] = p[1];
			px[1] = p[0];
			px[2] = p[2];
		} else {
			//上位4ビットが有効 → 下位にも複写して8ビット化
			px[0] = (p[1] & 0xF0) | (p[1] >> 4);
			px[1] = (p[0] & 0xF0) | (p[0] >> 4);
			px[2] = (p[2] & 0xF0) | (p[2] >> 4);
		}
		px[3] = 0xFF;
	}

	//左右は4バイト境界までパディングされる
	int ppb = color256 ? 1 : 2;
	uint32_t left_byte = (xorig / ppb) & ~3u;
	uint32_t right_byte = ((xend / ppb) + 4) & ~3u;
	uint32_t byte_width = right_byte - left_byte;
	uint32_t width = xend - xorig + 1;
	uint32_t height = yend - yorig + 1;
	uint32_t crop_left = xorig - left_byte * ppb;

	if (byte_width == 0 || height == 0) {
		free(buf);
		return NULL;
	}

	uint8_t *out = calloc((size_t)byte_width * height, 1);
	uint8_t *action = calloc(byte_width / 4, 1);

	if (out == NULL || action == NULL) {
		free(out);
		free(action);
		free(buf);
		return NULL;
	}

	//展開
	size_t out_size = (size_t)byte_width * height;
	size_t out_pos = 0;
	size_t apos = 0;
	size_t flaga_bit = 0;
	size_t flagb_pos = 0;
	size_t pxl_pos = 0;

	while (out_pos < out_size) {
		int bit = 0;
		if (flaga_bit / 8 < flaga_size)
			bit = (flaga[flaga_bit / 8] >> (7 - (flaga_bit & 7))) & 1;
		flaga_bit++;

		if (bit) {
			uint8_t fb = 0;
			if (flagb_pos < flagb_size)
				fb = flagb[flagb_pos];
			flagb_pos++;
			action[apos] ^= fb;
		}

		uint8_t act = action[apos];
		apos = (apos + 1) % (byte_width / 4);

		for (int half = 0; half < 2 && out_pos < out_size; half++) {
			int nib = (half == 0) ? (act >> 4) : (act & 0x0F);

			if (nib == 0) {
				//新しい16ビット値を色データから
				if (pxl_pos < pxl_size)
					out[out_pos] = pxl[pxl_pos];
				if (pxl_pos + 1 < pxl_size)
					out[out_pos + 1] = pxl[pxl_pos + 1];
				pxl_pos += 2;
			} else {
				//相対位置から16ビットをコピー
				long src = (long)out_pos + MAG_DX[nib] * 2 + (long)MAG_DY[nib] * (long)byte_width;
				if (src >= 0) {
					out[out_pos] = out[src];
					out[out_pos + 1] = out[src + 1];
				}
			}

			out_pos += 2;
		}
	}

	free(action);

	//パディングを切り落としながらRGBAへ
	RGBA *data = malloc((size_t)width * height * sizeof(RGBA));

	if (data == NULL) {
		free(out);
		free(buf);
		return NULL;
	}

	for (uint32_t y = 0; y < height; y++) {
		for (uint32_t x = 0; x < width; x++) {
			uint32_t sx = crop_left + x;
			uint8_t index;

			if (color256) {
				index = out[(size_t)y * byte_width + sx];
			} else {
				uint8_t byte = out[(size_t)y * byte_width + sx / 2];
				index = (sx & 1) ? (byte & 0x0F) : (byte >> 4);
			}

			data[(size_t)y * width + x] = palette[index];
		}
	}

	free(out);
	free(buf);

	Image *img = malloc(sizeof(Image));
	if (img == NULL) {
		free(data);
		return NULL;
	}

	img->data = data;
	img->width = (int32_t)width;
	img->height = (int32_t)height;
	img->count = 1;
	img->fps = 0;

	return img;
}
