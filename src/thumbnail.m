#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#import <Foundation/Foundation.h>
#import <png.h>

#import "rsiv.h"
#import "thumbnail.h"
#import "platform.h"
#import "format/format.h"

//ボックスフィルタで縮小する（拡大はしない）
static Image *scale_down(Image *src, int size) {
	uint64_t sw = src->width;
	uint64_t sh = src->height;

	Image *img = malloc(sizeof(Image));
	if (img == NULL)
		return NULL;

	img->count = 1;
	img->fps = 0;

	//指定サイズに収まっているときはそのままコピー
	if (sw <= (uint64_t)size && sh <= (uint64_t)size) {
		img->width = sw;
		img->height = sh;
		img->data = malloc(sw * sh * sizeof(RGBA));
		if (img->data == NULL) {
			free(img);
			return NULL;
		}
		memcpy(img->data, src->data, sw * sh * sizeof(RGBA));
		return img;
	}

	double scale;
	if (sw > sh) {
		scale = (double)size / (double)sw;
	} else {
		scale = (double)size / (double)sh;
	}

	uint64_t dw = (uint64_t)(sw * scale + 0.5);
	uint64_t dh = (uint64_t)(sh * scale + 0.5);
	if (dw < 1)
		dw = 1;
	if (dh < 1)
		dh = 1;

	img->width = dw;
	img->height = dh;
	img->data = malloc(dw * dh * sizeof(RGBA));
	if (img->data == NULL) {
		free(img);
		return NULL;
	}

	for (uint64_t y = 0; y < dh; y++) {
		uint64_t sy0 = (y * sh) / dh;
		uint64_t sy1 = ((y + 1) * sh) / dh;
		if (sy1 <= sy0)
			sy1 = sy0 + 1;

		for (uint64_t x = 0; x < dw; x++) {
			uint64_t sx0 = (x * sw) / dw;
			uint64_t sx1 = ((x + 1) * sw) / dw;
			if (sx1 <= sx0)
				sx1 = sx0 + 1;

			uint64_t sum_r = 0;
			uint64_t sum_g = 0;
			uint64_t sum_b = 0;
			uint64_t sum_a = 0;

			for (uint64_t sy = sy0; sy < sy1; sy++) {
				for (uint64_t sx = sx0; sx < sx1; sx++) {
					RGBA *p = src->data + sy * sw + sx;
					sum_r += p->r;
					sum_g += p->g;
					sum_b += p->b;
					sum_a += p->a;
				}
			}

			uint64_t count = (sx1 - sx0) * (sy1 - sy0);
			RGBA *dp = img->data + y * dw + x;
			dp->r = (uint8_t)((sum_r + count / 2) / count);
			dp->g = (uint8_t)((sum_g + count / 2) / count);
			dp->b = (uint8_t)((sum_b + count / 2) / count);
			dp->a = (uint8_t)((sum_a + count / 2) / count);
		}
	}

	return img;
}

static int save_png(NSString *path, Image *img) {
	FILE *f = rsiv_fopen([path UTF8String], "wb");
	if (f == NULL)
		return 1;

	png_structp png = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
	if (png == NULL) {
		fclose(f);
		return 1;
	}

	png_infop info = png_create_info_struct(png);
	if (info == NULL) {
		png_destroy_write_struct(&png, NULL);
		fclose(f);
		return 1;
	}

	if (setjmp(png_jmpbuf(png))) {
		png_destroy_write_struct(&png, &info);
		fclose(f);
		return 1;
	}

	png_init_io(png, f);
	png_set_IHDR(png, info, (png_uint_32)img->width, (png_uint_32)img->height, 8, PNG_COLOR_TYPE_RGBA, PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_DEFAULT);
	png_write_info(png, info);

	for (uint64_t y = 0; y < img->height; y++)
		png_write_row(png, (png_bytep)(img->data + y * img->width));

	png_write_end(png, NULL);
	png_destroy_write_struct(&png, &info);
	fclose(f);

	return 0;
}

int make_thumbnail(NSString *in_path, NSString *out_path, int size) {
	if (size <= 0)
		return 1;

	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	int rc = 1;
	Image *src = load_image_strict(in_path);

	if (src != NULL) {
		Image *thumb = scale_down(src, size);

		if (thumb != NULL) {
			rc = save_png(out_path, thumb);
			free(thumb->data);
			free(thumb);
		}

		free(src->data);
		free(src);
	}

	[pool drain];

	return rc;
}
