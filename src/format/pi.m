#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#import "../rsiv.h"

//Pi展開用
typedef struct {
	const uint8_t *data;
	size_t size;
	size_t bpos; //ビット読み位置（バイト）
	int bbit; //ビット読み位置（0..7、MSBから）
	uint8_t *out; //インデックス列
	size_t pos;
	size_t total;
	int32_t width;
	int ncolors;
	int depth;
	uint8_t *table; //デルタテーブル（ncolors x ncolors）
} PiDec;

static int pi_bit(PiDec *d) {
	if (d->bpos >= d->size)
		return 0;

	int bit = (d->data[d->bpos] >> (7 - d->bbit)) & 1;
	d->bbit++;
	if (d->bbit == 8) {
		d->bbit = 0;
		d->bpos++;
	}
	return bit;
}

static int pi_bits(PiDec *d, int n) {
	int v = 0;
	for (int i = 0; i < n; i++)
		v = (v << 1) | pi_bit(d);
	return v;
}

//デルタ符号（疑似ハフマン）
static int pi_delta_code(PiDec *d) {
	if (pi_bit(d) == 1)
		return pi_bits(d, 1); //0-1

	if (pi_bit(d) == 0)
		return 2 + pi_bits(d, 1); //2-3

	if (d->depth == 4) {
		if (pi_bit(d) == 0)
			return 4 + pi_bits(d, 2); //4-7
		return 8 + pi_bits(d, 3); //8-15
	}

	if (pi_bit(d) == 0)
		return 4 + pi_bits(d, 2); //4-7
	if (pi_bit(d) == 0)
		return 8 + pi_bits(d, 3); //8-15
	if (pi_bit(d) == 0)
		return 16 + pi_bits(d, 4); //16-31
	if (pi_bit(d) == 0)
		return 32 + pi_bits(d, 5); //32-63
	if (pi_bit(d) == 0)
		return 64 + pi_bits(d, 6); //64-127
	return 128 + pi_bits(d, 7); //128-255
}

//デルタ符号を1つ処理して1バイト出力
static void pi_delta(PiDec *d) {
	int a = d->pos > 0 ? d->out[d->pos - 1] : 0;
	int code = pi_delta_code(d);
	uint8_t *row = d->table + (size_t)a * (size_t)d->ncolors;
	uint8_t v = row[code];

	//move-to-front
	memmove(row + 1, row, (size_t)code);
	row[0] = v;

	if (d->pos < d->total) {
		d->out[d->pos] = v;
		d->pos++;
	}
}

//繰り返し長（単位はバイト対）
static int pi_length(PiDec *d) {
	int n = 0;
	while (pi_bit(d) == 1) {
		n++;
		if (n >= 24)
			break;
	}
	return (1 << n) + pi_bits(d, n);
}

//繰り返し位置（0:直前 1:1行上 2:2行上 3:1行上+1 4:1行上-1）
static int pi_location(PiDec *d) {
	if (pi_bit(d) == 0)
		return pi_bit(d) == 0 ? 0 : 1;
	if (pi_bit(d) == 0)
		return 2;
	return pi_bit(d) == 0 ? 3 : 4;
}

//繰り返し列（同じ位置符号が続いたら終わり）
static void pi_repeat(PiDec *d, int first) {
	int prev_loc = -1;
	int is_first = first;

	while (d->pos < d->total) {
		int loc = pi_location(d);
		if (loc == prev_loc)
			return;
		prev_loc = loc;

		int length = pi_length(d) * 2;
		if (is_first) {
			length -= 2;
			is_first = 0;
		}

		int64_t src;
		int rev = 0;

		if (loc == 0) {
			if (d->pos >= 4 && d->out[d->pos - 2] != d->out[d->pos - 1])
				src = (int64_t)d->pos - 4;
			else
				src = (int64_t)d->pos - 2;
		} else if (loc == 1) {
			src = (int64_t)d->pos - d->width;
		} else if (loc == 2) {
			src = (int64_t)d->pos - 2 * (int64_t)d->width;
		} else if (loc == 3) {
			src = (int64_t)d->pos - d->width + 1;
			rev = 1;
		} else {
			src = (int64_t)d->pos - d->width - 1;
			rev = 1;
		}

		for (int i = 0; i < length; i++) {
			if (d->pos >= d->total)
				return;

			int64_t s = src + i;
			if (s >= 0) {
				d->out[d->pos] = d->out[s];
			} else if (rev) {
				//バッファ先頭の2バイトを逆順に繰り返す
				d->out[d->pos] = d->out[((s + 1) % 2 + 2) % 2];
			} else {
				//バッファ先頭の2バイトを繰り返す
				d->out[d->pos] = d->out[((s % 2) + 2) % 2];
			}
			d->pos++;
		}
	}
}

Image *load_pi(FILE *f) {
	//ファイル全体を読む
	fseek(f, 0, SEEK_END);
	long file_size = ftell(f);
	fseek(f, 0, SEEK_SET);

	if (file_size <= 0)
		return NULL;

	uint8_t *buf = malloc((size_t)file_size);
	if (buf == NULL)
		return NULL;

	if (fread(buf, 1, (size_t)file_size, f) != (size_t)file_size) {
		free(buf);
		return NULL;
	}

	if (file_size < 4 || buf[0] != 'P' || buf[1] != 'i') {
		free(buf);
		return NULL;
	}

	//コメントは0x1Aで終わり、本ヘッダーはその後の最初の0x00から
	size_t z = 2;
	while (z < (size_t)file_size && buf[z] != 0x1A)
		z++;
	size_t head = z;
	while (head < (size_t)file_size && buf[head] != 0x00)
		head++;
	if (head + 15 >= (size_t)file_size) {
		free(buf);
		return NULL;
	}

	int depth = buf[head + 4];
	if (depth != 4 && depth != 8 && depth != 0xFF) {
		free(buf);
		return NULL;
	}

	int ncolors = depth == 8 ? 256 : 16;
	uint32_t ext_size = ((uint32_t)buf[head + 9] << 8) | buf[head + 10];
	size_t p = head + 11 + ext_size;

	if (p + 4 + (size_t)ncolors * 3 > (size_t)file_size) {
		free(buf);
		return NULL;
	}

	int32_t width = ((int32_t)buf[p] << 8) | buf[p + 1];
	int32_t height = ((int32_t)buf[p + 2] << 8) | buf[p + 3];
	p += 4;

	if (width <= 0 || height <= 0) {
		free(buf);
		return NULL;
	}

	//パレット（RGB順）。X68000系は5ビット、それ以外は4ビットが有効
	int x68k = memcmp(buf + head + 5, "X68K", 4) == 0;
	RGBA palette[256];

	for (int i = 0; i < ncolors; i++) {
		const uint8_t *cp = buf + p + (size_t)i * 3;
		uint8_t *px = (uint8_t *)(palette + i);

		if (x68k) {
			px[0] = (cp[0] & 0xF8) | (cp[0] >> 5);
			px[1] = (cp[1] & 0xF8) | (cp[1] >> 5);
			px[2] = (cp[2] & 0xF8) | (cp[2] >> 5);
		} else {
			px[0] = (cp[0] & 0xF0) | (cp[0] >> 4);
			px[1] = (cp[1] & 0xF0) | (cp[1] >> 4);
			px[2] = (cp[2] & 0xF0) | (cp[2] >> 4);
		}
		px[3] = 0xFF;
	}

	p += (size_t)ncolors * 3;

	PiDec d;
	d.data = buf;
	d.size = (size_t)file_size;
	d.bpos = p;
	d.bbit = 0;
	d.pos = 0;
	d.total = (size_t)width * (size_t)height;
	d.width = width;
	d.ncolors = ncolors;
	d.depth = depth == 8 ? 8 : 4;
	d.out = calloc(d.total, 1);
	d.table = malloc((size_t)ncolors * (size_t)ncolors);

	if (d.out == NULL || d.table == NULL) {
		free(d.out);
		free(d.table);
		free(buf);
		return NULL;
	}

	//デルタテーブルの初期化
	for (int a = 0; a < ncolors; a++) {
		for (int b = 0; b < ncolors; b++) {
			d.table[a * ncolors + b] = (uint8_t)((ncolors + a - b) % ncolors);
		}
	}

	//本体：デルタ2つ→繰り返し列、の繰り返し
	pi_delta(&d);
	pi_delta(&d);
	pi_repeat(&d, 1);

	while (d.pos < d.total) {
		pi_delta(&d);
		pi_delta(&d);
		if (d.pos >= d.total)
			break;
		if (pi_bit(&d) == 1)
			continue;
		pi_repeat(&d, 0);
	}

	free(d.table);
	free(buf);

	RGBA *data = malloc(d.total * sizeof(RGBA));
	if (data == NULL) {
		free(d.out);
		return NULL;
	}

	for (size_t i = 0; i < d.total; i++)
		data[i] = palette[d.out[i]];

	free(d.out);

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
