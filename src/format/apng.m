#import <stdio.h>
#import <stdlib.h>
#import <stdbool.h>
#import <string.h>
#import <png.h>
#import <setjmp.h>

#import "../rsiv.h"
#import "apng.h"

//フレーム1枚分
typedef struct {
	uint32_t width;
	uint32_t height;
	uint32_t x;
	uint32_t y;
	uint16_t delay_num;
	uint16_t delay_den;
	uint8_t dispose;
	uint8_t blend;
	uint8_t *data; //IDATの中身を連結したもの（fdATはシーケンス番号を取り除いてある）
	size_t data_len;
	size_t data_cap;
} APNGFrame;

static uint32_t read_be32(const uint8_t *p) {
	return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) | ((uint32_t)p[2] << 8) | (uint32_t)p[3];
}

static bool buf_append(uint8_t **buf, size_t *len, size_t *cap, const uint8_t *data, size_t n) {
	if (*len + n > *cap) {
		size_t ncap = (*cap == 0) ? 65536 : *cap;
		while (*len + n > ncap) ncap *= 2;
		uint8_t *nb = realloc(*buf, ncap);
		if (!nb) return false;
		*buf = nb;
		*cap = ncap;
	}
	memcpy(*buf + *len, data, n);
	*len += n;
	return true;
}

//CRC32（PNGチャンク用、更新式）
static uint32_t crc32_update(uint32_t crc, const uint8_t *data, size_t len) {
	for (size_t i = 0; i < len; i++) {
		crc ^= data[i];
		for (int j = 0; j < 8; j++) {
			if (crc & 1)
				crc = (crc >> 1) ^ 0xEDB88320;
			else
				crc >>= 1;
		}
	}
	return crc;
}

static void write_chunk(FILE *out, const char *type, const uint8_t *data, uint32_t len) {
	uint8_t buf[4];
	buf[0] = (uint8_t)(len >> 24);
	buf[1] = (uint8_t)(len >> 16);
	buf[2] = (uint8_t)(len >> 8);
	buf[3] = (uint8_t)len;
	fwrite(buf, 1, 4, out);
	fwrite(type, 1, 4, out);
	if (len > 0)
		fwrite(data, 1, len, out);

	uint32_t crc = crc32_update(0xFFFFFFFF, (const uint8_t *)type, 4);
	if (len > 0)
		crc = crc32_update(crc, data, len);
	crc ^= 0xFFFFFFFF;

	buf[0] = (uint8_t)(crc >> 24);
	buf[1] = (uint8_t)(crc >> 16);
	buf[2] = (uint8_t)(crc >> 8);
	buf[3] = (uint8_t)crc;
	fwrite(buf, 1, 4, out);
}

//フレームのPNGストリームをlibpngでRGBAにデコードする（load_pngと同じ変換）
static RGBA *decode_frame(FILE *tmp, uint32_t w, uint32_t h) {
	uint8_t sig[8];

	rewind(tmp);
	if (fread(sig, 1, 8, tmp) != 8 || png_sig_cmp(sig, 0, 8)) {
		return NULL;
	}

	png_structp png = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
	if (!png) return NULL;

	png_infop info = png_create_info_struct(png);
	if (!info) {
		png_destroy_read_struct(&png, NULL, NULL);
		return NULL;
	}

	typedef struct {
		RGBA *data;
		png_bytep *rows;
	} FrameMemory;

	volatile FrameMemory memory = { NULL, NULL };

	if (setjmp(png_jmpbuf(png))) {
		free(memory.data);
		free(memory.rows);
		png_destroy_read_struct(&png, &info, NULL);
		return NULL;
	}

	png_init_io(png, tmp);
	png_set_sig_bytes(png, 8);
	png_read_info(png, info);

	int color_type = png_get_color_type(png, info);
	int bit_depth = png_get_bit_depth(png, info);

	if (bit_depth == 16)
		png_set_strip_16(png);
	if (color_type == PNG_COLOR_TYPE_PALETTE)
		png_set_palette_to_rgb(png);
	if (color_type == PNG_COLOR_TYPE_GRAY && bit_depth < 8)
		png_set_expand_gray_1_2_4_to_8(png);
	if (png_get_valid(png, info, PNG_INFO_tRNS))
		png_set_tRNS_to_alpha(png);
	if (color_type == PNG_COLOR_TYPE_GRAY || color_type == PNG_COLOR_TYPE_GRAY_ALPHA)
		png_set_gray_to_rgb(png);
	if (!(color_type & PNG_COLOR_MASK_ALPHA) && !png_get_valid(png, info, PNG_INFO_tRNS))
		png_set_filler(png, 0xFF, PNG_FILLER_AFTER);

	png_set_interlace_handling(png);
	png_read_update_info(png, info);

	if (png_get_rowbytes(png, info) != (png_size_t)w * sizeof(RGBA))
		png_error(png, "Invalid row size");

	memory.data = malloc((size_t)w * h * sizeof(RGBA));
	memory.rows = malloc(sizeof(png_bytep) * h);

	if (!memory.data || !memory.rows)
		png_error(png, "Out of memory");

	for (uint32_t y = 0; y < h; y++) {
		memory.rows[y] = (png_bytep)(memory.data + (size_t)y * w);
	}

	png_read_image(png, (png_bytepp)memory.rows);

	free(memory.rows);
	png_destroy_read_struct(&png, &info, NULL);

	return memory.data;
}

//OVER合成（ストレートアルファ）
static void blend_over(RGBA *dst, const RGBA *src) {
	if (src->a == 0) return;
	if (src->a == 255 || dst->a == 0) {
		*dst = *src;
		return;
	}

	double sa = src->a / 255.0;
	double da = dst->a / 255.0;
	double oa = sa + da * (1.0 - sa);

	dst->r = (uint8_t)((src->r * sa + dst->r * da * (1.0 - sa)) / oa + 0.5);
	dst->g = (uint8_t)((src->g * sa + dst->g * da * (1.0 - sa)) / oa + 0.5);
	dst->b = (uint8_t)((src->b * sa + dst->b * da * (1.0 - sa)) / oa + 0.5);
	dst->a = (uint8_t)(oa * 255.0 + 0.5);
}

Image *load_apng(FILE *f) {
	uint8_t sig[8];
	if (fread(sig, 1, 8, f) != 8 || png_sig_cmp(sig, 0, 8)) {
		return NULL;
	}

	uint8_t ihdr[13];
	bool have_ihdr = false;
	uint32_t canvas_w = 0;
	uint32_t canvas_h = 0;

	uint8_t *head = NULL; //IHDRの後、IDATの前に有る補助チャンク（生のまま各フレームへ引き継ぐ）
	size_t head_len = 0;
	size_t head_cap = 0;

	APNGFrame *frames = NULL;
	uint32_t frame_count = 0;
	uint32_t frame_cap = 0;
	int32_t current = -1;
	bool first_frame_is_idat = false;
	bool seen_idat = false;
	bool seen_actl = false;
	bool reached_iend = false;

	//チャンク走査
	while (true) {
		uint8_t hdr[8];
		if (fread(hdr, 1, 8, f) != 8) break;

		uint32_t len = read_be32(hdr);
		char type[5] = { (char)hdr[4], (char)hdr[5], (char)hdr[6], (char)hdr[7], '\0' };

		uint8_t *data = malloc(len > 0 ? len : 1);
		if (!data) break;
		if (len > 0 && fread(data, 1, len, f) != len) {
			free(data);
			break;
		}
		uint8_t crcbuf[4];
		if (fread(crcbuf, 1, 4, f) != 4) {
			free(data);
			break;
		}

		if (strcmp(type, "IHDR") == 0 && len == 13) {
			memcpy(ihdr, data, 13);
			canvas_w = read_be32(data);
			canvas_h = read_be32(data + 4);
			have_ihdr = true;
		} else if (strcmp(type, "acTL") == 0) {
			seen_actl = true;
		} else if (strcmp(type, "fcTL") == 0 && len == 26) {
			if (frame_count >= frame_cap) {
				frame_cap = (frame_cap == 0) ? 16 : frame_cap * 2;
				frames = realloc(frames, sizeof(APNGFrame) * frame_cap);
				if (!frames) {
					free(data);
					break;
				}
			}
			APNGFrame *fr = &frames[frame_count];
			memset(fr, 0, sizeof(APNGFrame));
			fr->width = read_be32(data + 4);
			fr->height = read_be32(data + 8);
			fr->x = read_be32(data + 12);
			fr->y = read_be32(data + 16);
			fr->delay_num = (uint16_t)((data[20] << 8) | data[21]);
			fr->delay_den = (uint16_t)((data[22] << 8) | data[23]);
			fr->dispose = data[24];
			fr->blend = data[25];
			current = (int32_t)frame_count;
			frame_count++;
			if (!seen_idat && frame_count == 1)
				first_frame_is_idat = true;
		} else if (strcmp(type, "IDAT") == 0) {
			if (current == 0 && first_frame_is_idat) {
				buf_append(&frames[0].data, &frames[0].data_len, &frames[0].data_cap, data, len);
			}
			seen_idat = true;
		} else if (strcmp(type, "fdAT") == 0) {
			if (current >= 0 && len > 4) {
				buf_append(&frames[current].data, &frames[current].data_len, &frames[current].data_cap, data + 4, len - 4);
			}
		} else if (strcmp(type, "IEND") == 0) {
			free(data);
			reached_iend = true;
			break;
		} else if (!seen_idat) {
			buf_append(&head, &head_len, &head_cap, hdr, 8);
			buf_append(&head, &head_len, &head_cap, data, len);
			buf_append(&head, &head_len, &head_cap, crcbuf, 4);
		}

		free(data);
	}

	Image *img = NULL;
	RGBA *out = NULL;
	RGBA *canvas = NULL;
	RGBA *saved = NULL;

	if (!have_ihdr || !seen_actl || !reached_iend || frame_count == 0 || canvas_w == 0 || canvas_h == 0) {
		goto cleanup;
	}

	out = malloc((size_t)canvas_w * canvas_h * frame_count * sizeof(RGBA));
	canvas = calloc((size_t)canvas_w * canvas_h, sizeof(RGBA));
	saved = malloc((size_t)canvas_w * canvas_h * sizeof(RGBA));
	if (!out || !canvas || !saved) {
		goto cleanup;
	}

	for (uint32_t i = 0; i < frame_count; i++) {
		APNGFrame *fr = &frames[i];
		if (fr->data_len == 0 || fr->width == 0 || fr->height == 0) {
			goto cleanup;
		}

		//フレーム単体のPNGストリームを組み立てる
		FILE *tmp = tmpfile();
		if (!tmp) goto cleanup;

		fwrite(sig, 1, 8, tmp);

		uint8_t fihdr[13];
		fihdr[0] = (uint8_t)(fr->width >> 24);
		fihdr[1] = (uint8_t)(fr->width >> 16);
		fihdr[2] = (uint8_t)(fr->width >> 8);
		fihdr[3] = (uint8_t)fr->width;
		fihdr[4] = (uint8_t)(fr->height >> 24);
		fihdr[5] = (uint8_t)(fr->height >> 16);
		fihdr[6] = (uint8_t)(fr->height >> 8);
		fihdr[7] = (uint8_t)fr->height;
		memcpy(fihdr + 8, ihdr + 8, 5);
		write_chunk(tmp, "IHDR", fihdr, 13);

		if (head_len > 0)
			fwrite(head, 1, head_len, tmp);

		write_chunk(tmp, "IDAT", fr->data, (uint32_t)fr->data_len);
		write_chunk(tmp, "IEND", NULL, 0);

		RGBA *px = decode_frame(tmp, fr->width, fr->height);
		fclose(tmp);
		if (!px) goto cleanup;

		//dispose=PREVIOUS用に退避
		if (fr->dispose == 2)
			memcpy(saved, canvas, (size_t)canvas_w * canvas_h * sizeof(RGBA));

		//キャンバスへ貼る
		for (uint32_t y = 0; y < fr->height; y++) {
			uint32_t cy = fr->y + y;
			if (cy >= canvas_h) continue;
			for (uint32_t x = 0; x < fr->width; x++) {
				uint32_t cx = fr->x + x;
				if (cx >= canvas_w) continue;
				RGBA *dst = canvas + (size_t)cy * canvas_w + cx;
				const RGBA *src = px + (size_t)y * fr->width + x;
				if (fr->blend == 0) {
					*dst = *src; //SOURCE
				} else {
					blend_over(dst, src); //OVER
				}
			}
		}
		free(px);

		memcpy(out + (size_t)i * canvas_w * canvas_h, canvas, (size_t)canvas_w * canvas_h * sizeof(RGBA));

		//廃棄
		if (fr->dispose == 1) { //BACKGROUND（透明でクリア）
			for (uint32_t y = 0; y < fr->height; y++) {
				uint32_t cy = fr->y + y;
				if (cy >= canvas_h) continue;
				uint32_t w = fr->width;
				if (fr->x + w > canvas_w) w = canvas_w - fr->x;
				memset(canvas + (size_t)cy * canvas_w + fr->x, 0, (size_t)w * sizeof(RGBA));
			}
		} else if (fr->dispose == 2) { //PREVIOUS
			memcpy(canvas, saved, (size_t)canvas_w * canvas_h * sizeof(RGBA));
		}
	}

	img = malloc(sizeof(Image));
	if (img) {
		img->data = out;
		img->width = canvas_w;
		img->height = canvas_h;
		if (frame_count > 1) {
			uint16_t den = (frames[0].delay_den == 0) ? 100 : frames[0].delay_den;
			img->count = frame_count;
			img->fps = frames[0].delay_num / (double)den;
		} else {
			img->count = 1;
			img->fps = 0;
		}
		out = NULL; //imgへ譲渡
	}

cleanup:
	free(out);
	free(canvas);
	free(saved);
	free(head);
	for (uint32_t i = 0; i < frame_count; i++) {
		free(frames[i].data);
	}
	free(frames);

	return img;
}
