#import <stdio.h>
#import <stdlib.h>
#import <stdint.h>
#import <string.h>

#import "../rsiv.h"

Image *load_maki(FILE *f) {
	uint8_t head[96];

	if (fread(head, 1, 96, f) != 96)
		return NULL;

	//XORフィルターの行間隔が01Aと01Bで違う
	int row_gap;
	if (memcmp(head, "MAKI01A ", 8) == 0)
		row_gap = 2;
	else if (memcmp(head, "MAKI01B ", 8) == 0)
		row_gap = 4;
	else
		return NULL;

	//パレット（GRB順、上位4ビットが有効）
	RGBA palette[16];
	for (int i = 0; i < 16; i++) {
		const uint8_t *p = head + 48 + (size_t)i * 3;
		uint8_t *px = (uint8_t *)(palette + i);
		px[0] = (p[1] & 0xF0) | (p[1] >> 4);
		px[1] = (p[0] & 0xF0) | (p[0] >> 4);
		px[2] = (p[2] & 0xF0) | (p[2] >> 4);
		px[3] = 0xFF;
	}

	uint8_t *flaga = malloc(1000);
	uint8_t *mask = calloc(320 * 400, 1);
	uint8_t *out = calloc(320 * 400, 1);

	if (flaga == NULL || mask == NULL || out == NULL ||
		fread(flaga, 1, 1000, f) != 1000) {
		free(flaga);
		free(mask);
		free(out);
		return NULL;
	}

	//マスク生成（4x4チャンク単位、フラグBは必要分だけ読む）
	size_t abit = 0;
	for (int cy = 0; cy < 100; cy++) {
		for (int cx = 0; cx < 80; cx++) {
			int bit = (flaga[abit / 8] >> (7 - (abit & 7))) & 1;
			abit++;

			if (!bit)
				continue;

			uint8_t fb[2];
			if (fread(fb, 1, 2, f) != 2) {
				free(flaga);
				free(mask);
				free(out);
				return NULL;
			}

			uint32_t bits = ((uint32_t)fb[0] << 8) | fb[1];
			for (int r = 0; r < 4; r++) {
				for (int c = 0; c < 4; c++) {
					mask[(cy * 4 + r) * 320 + cx * 4 + c] =
						(uint8_t)(bits >> (15 - (r * 4 + c))) & 1;
				}
			}
		}
	}

	free(flaga);

	//ピクセルデータ（残り全部。開始位置はフラグBの消費分で決まる）
	long pos = ftell(f);
	fseek(f, 0, SEEK_END);
	long rest = ftell(f) - pos;
	fseek(f, pos, SEEK_SET);

	uint8_t *pxl = malloc(rest > 0 ? (size_t)rest : 1);

	if (pxl == NULL || fread(pxl, 1, (size_t)rest, f) != (size_t)rest) {
		free(pxl);
		free(mask);
		free(out);
		return NULL;
	}

	size_t ppos = 0;
	for (int i = 0; i < 320 * 400; i++) {
		if (mask[i] && ppos < (size_t)rest)
			out[i] = pxl[ppos++];
	}

	free(mask);
	free(pxl);

	//XORフィルター
	for (int y = row_gap; y < 400; y++) {
		for (int x = 0; x < 320; x++) {
			out[y * 320 + x] ^= out[(y - row_gap) * 320 + x];
		}
	}

	//RGBAへ（下位ニブルが左のピクセル。MAGと逆）
	RGBA *data = malloc(640 * 400 * sizeof(RGBA));

	if (data == NULL) {
		free(out);
		return NULL;
	}

	for (int y = 0; y < 400; y++) {
		for (int x = 0; x < 320; x++) {
			uint8_t byte = out[y * 320 + x];
			data[y * 640 + x * 2] = palette[byte & 0x0F];
			data[y * 640 + x * 2 + 1] = palette[byte >> 4];
		}
	}

	free(out);

	Image *img = malloc(sizeof(Image));
	if (img == NULL) {
		free(data);
		return NULL;
	}

	img->data = data;
	img->width = 640;
	img->height = 400;
	img->count = 1;
	img->fps = 0;

	return img;
}
