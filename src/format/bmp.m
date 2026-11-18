#import <stdio.h>
#import <stdlib.h>
#import <stdint.h>
#import <string.h>

#import "../rsiv.h"

static uint16_t bmp_rd16(const uint8_t *p) {
	return (uint16_t)(p[0] | (p[1] << 8));
}

static uint32_t bmp_rd32(const uint8_t *p) {
	return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

//ビットフィールドの1チャンネルを8ビットへ
static uint8_t bmp_channel(uint32_t px, uint32_t mask) {
	if (mask == 0)
		return 0;

	int shift = 0;
	while (((mask >> shift) & 1) == 0)
		shift++;

	uint32_t v = (px & mask) >> shift;
	uint32_t max = mask >> shift;
	return (uint8_t)((v * 255) / max);
}

static void rle_put(uint8_t *idx, int32_t width, int32_t height, int32_t x, int32_t y, int v) {
	if (x >= 0 && x < width && y >= 0 && y < height)
		idx[(size_t)y * (size_t)width + x] = (uint8_t)v;
}

//RLE展開（下段から書く。範囲外への書き込みは捨てる）
static void bmp_rle(FILE *f, uint8_t *idx, int32_t width, int32_t height, int rle4) {
	int32_t x = 0;
	int32_t y = height - 1;

	for (;;) {
		int c1 = fgetc(f);
		if (c1 == EOF)
			return;

		if (c1 != 0) {
			//ランモード
			int v = fgetc(f);
			if (v == EOF)
				return;

			for (int i = 0; i < c1; i++) {
				int p = v;
				if (rle4)
					p = (i & 1) ? (v & 0x0F) : (v >> 4);
				rle_put(idx, width, height, x, y, p);
				x++;
			}
			continue;
		}

		int c2 = fgetc(f);
		if (c2 == EOF)
			return;

		if (c2 == 0) {
			//行末
			x = 0;
			y--;
		} else if (c2 == 1) {
			//ビットマップ終端
			return;
		} else if (c2 == 2) {
			//デルタ（相対移動）
			int dx = fgetc(f);
			int dy = fgetc(f);
			if (dx == EOF || dy == EOF)
				return;
			x += dx;
			y -= dy;
		} else if (rle4) {
			//絶対モード（RLE4）
			int nbytes = (c2 + 1) / 2;
			for (int i = 0; i < nbytes; i++) {
				int v = fgetc(f);
				if (v == EOF)
					return;
				rle_put(idx, width, height, x, y, v >> 4);
				x++;
				if (i * 2 + 1 < c2) {
					rle_put(idx, width, height, x, y, v & 0x0F);
					x++;
				}
			}
			if (nbytes & 1)
				fgetc(f);
		} else {
			//絶対モード（RLE8）
			for (int i = 0; i < c2; i++) {
				int v = fgetc(f);
				if (v == EOF)
					return;
				rle_put(idx, width, height, x, y, v);
				x++;
			}
			if (c2 & 1)
				fgetc(f);
		}
	}
}

Image *load_bmp(FILE *f) {
	uint8_t filehdr[14];

	if (fread(filehdr, 1, 14, f) != 14)
		return NULL;

	if (filehdr[0] != 'B' || filehdr[1] != 'M')
		return NULL;

	uint32_t data_off = bmp_rd32(filehdr + 10);

	uint8_t sizebuf[4];
	if (fread(sizebuf, 1, 4, f) != 4)
		return NULL;

	uint32_t dib_size = bmp_rd32(sizebuf);
	if (dib_size > 124)
		return NULL;

	int core = 0;
	int32_t width = 0;
	int32_t height_raw = 0;
	uint16_t bpp = 0;
	uint32_t compression = 0;
	uint32_t colors_used = 0;
	uint32_t rmask = 0;
	uint32_t gmask = 0;
	uint32_t bmask = 0;
	uint32_t amask = 0;
	long pal_pos = 0;
	long mask_pos = -1;

	if (dib_size == 12) {
		//BITMAPCOREHEADER（OS/2）
		core = 1;

		uint8_t dib[8];
		if (fread(dib, 1, 8, f) != 8)
			return NULL;

		width = bmp_rd16(dib + 0);
		height_raw = bmp_rd16(dib + 2);
		bpp = bmp_rd16(dib + 6);
		pal_pos = 14 + 12;
	} else if (dib_size >= 40) {
		uint8_t dib[120];
		size_t dib_rest = dib_size - 4;
		if (fread(dib, 1, dib_rest, f) != dib_rest)
			return NULL;

		width = (int32_t)bmp_rd32(dib + 0);
		height_raw = (int32_t)bmp_rd32(dib + 4);
		bpp = bmp_rd16(dib + 10);
		compression = bmp_rd32(dib + 12);
		colors_used = bmp_rd32(dib + 28);
		pal_pos = 14 + (long)dib_size;

		if (compression == 3) {
			//BI_BITFIELDS
			if (dib_size >= 52) {
				//マスクはヘッダーの中
				rmask = bmp_rd32(dib + 36);
				gmask = bmp_rd32(dib + 40);
				bmask = bmp_rd32(dib + 44);
				if (dib_size >= 56)
					amask = bmp_rd32(dib + 48);
			} else {
				//40バイトヘッダーのときはヘッダーの直後
				mask_pos = pal_pos;
				pal_pos += 12;
			}
		}
	} else {
		return NULL;
	}

	if (width <= 0 || height_raw == 0)
		return NULL;

	if (compression != 0 && compression != 1 && compression != 2 && compression != 3)
		return NULL;

	if (bpp != 1 && bpp != 4 && bpp != 8 && bpp != 16 && bpp != 24 && bpp != 32)
		return NULL;

	//圧縮形式とbppの組み合わせ
	if (compression == 1 && bpp != 8)
		return NULL;
	if (compression == 2 && bpp != 4)
		return NULL;
	if (compression == 3 && bpp != 16 && bpp != 32)
		return NULL;

	int top_down = 0;
	int32_t height = height_raw;
	if (height < 0) {
		//RLE圧縮ではトップダウン不可
		if (compression == 1 || compression == 2)
			return NULL;
		top_down = 1;
		height = -height;
	}

	//既定のビットフィールド（BI_RGB）
	if (bpp == 16 && rmask == 0) {
		rmask = 0x7C00;
		gmask = 0x03E0;
		bmask = 0x001F;
	}
	if (bpp == 32 && rmask == 0) {
		rmask = 0x00FF0000;
		gmask = 0x0000FF00;
		bmask = 0x000000FF;
		amask = 0xFF000000;
	}

	//40バイトヘッダーのビットフィールドマスクを読む
	if (mask_pos >= 0) {
		if (fseek(f, mask_pos, SEEK_SET) != 0)
			return NULL;

		uint8_t m[12];
		if (fread(m, 1, 12, f) != 12)
			return NULL;

		rmask = bmp_rd32(m + 0);
		gmask = bmp_rd32(m + 4);
		bmask = bmp_rd32(m + 8);
	}

	//パレット（8bpp以下）
	RGBA palette[256];
	memset(palette, 0, sizeof(palette));

	if (bpp <= 8) {
		int pal_count = colors_used != 0 ? (int)colors_used : (1 << bpp);
		if (pal_count > 256)
			pal_count = 256;

		int entry_size = core ? 3 : 4;

		if (fseek(f, pal_pos, SEEK_SET) != 0)
			return NULL;

		for (int i = 0; i < pal_count; i++) {
			uint8_t entry[4];
			if (fread(entry, 1, (size_t)entry_size, f) != (size_t)entry_size)
				return NULL;

			uint8_t *px = (uint8_t *)(palette + i);
			px[0] = entry[2];
			px[1] = entry[1];
			px[2] = entry[0];
			px[3] = 0xFF;
		}
	}

	if (fseek(f, (long)data_off, SEEK_SET) != 0)
		return NULL;

	RGBA *data = malloc((size_t)width * (size_t)height * sizeof(RGBA));
	if (data == NULL)
		return NULL;

	if (bpp <= 8) {
		//パレット形式はいったんインデックス列へ展開してから色にする
		uint8_t *idx = calloc((size_t)width * (size_t)height, 1);
		if (idx == NULL) {
			free(data);
			return NULL;
		}

		if (compression == 1 || compression == 2) {
			bmp_rle(f, idx, width, height, compression == 2);
		} else {
			//1行は4バイト境界までパディングされる
			uint32_t row_size = ((uint32_t)bpp * (uint32_t)width + 31) / 32 * 4;
			uint8_t *row = malloc(row_size);

			if (row == NULL) {
				free(idx);
				free(data);
				return NULL;
			}

			for (int32_t y = 0; y < height; y++) {
				if (fread(row, 1, row_size, f) != row_size) {
					free(row);
					free(idx);
					free(data);
					return NULL;
				}

				int32_t dy = top_down ? y : (height - 1 - y);

				for (int32_t x = 0; x < width; x++) {
					uint8_t v = 0;

					if (bpp == 8) {
						v = row[x];
					} else if (bpp == 4) {
						uint8_t byte = row[x / 2];
						v = (x & 1) ? (byte & 0x0F) : (byte >> 4);
					} else {
						uint8_t byte = row[x / 8];
						v = (byte >> (7 - (x & 7))) & 1;
					}

					idx[(size_t)dy * (size_t)width + x] = v;
				}
			}

			free(row);
		}

		for (int32_t i = 0; i < width * height; i++)
			data[i] = palette[idx[i]];

		free(idx);
	} else {
		//直接色形式
		uint32_t row_size = ((uint32_t)bpp * (uint32_t)width + 31) / 32 * 4;
		uint8_t *row = malloc(row_size);

		if (row == NULL) {
			free(data);
			return NULL;
		}

		for (int32_t y = 0; y < height; y++) {
			if (fread(row, 1, row_size, f) != row_size) {
				free(row);
				free(data);
				return NULL;
			}

			int32_t dy = top_down ? y : (height - 1 - y);

			for (int32_t x = 0; x < width; x++) {
				RGBA *dst = data + (size_t)dy * (size_t)width + x;
				uint8_t *px = (uint8_t *)dst;

				if (bpp == 24) {
					px[0] = row[x * 3 + 2];
					px[1] = row[x * 3 + 1];
					px[2] = row[x * 3 + 0];
					px[3] = 0xFF;
				} else if (bpp == 16) {
					uint32_t v = bmp_rd16(row + x * 2);
					px[0] = bmp_channel(v, rmask);
					px[1] = bmp_channel(v, gmask);
					px[2] = bmp_channel(v, bmask);
					px[3] = 0xFF;
				} else {
					uint32_t v = bmp_rd32(row + x * 4);
					px[0] = bmp_channel(v, rmask);
					px[1] = bmp_channel(v, gmask);
					px[2] = bmp_channel(v, bmask);
					if (amask != 0)
						px[3] = bmp_channel(v, amask);
					else
						px[3] = 0xFF;
				}
			}
		}

		free(row);
	}

	Image *img = malloc(sizeof(Image));
	if (img == NULL) {
		free(data);
		return NULL;
	}

	img->data = data;
	img->width = width;
	img->height = height;
	img->count = 1;
	img->fps = 0;

	return img;
}
