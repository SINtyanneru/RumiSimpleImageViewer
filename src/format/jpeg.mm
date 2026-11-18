#import <stdio.h>
#import <stdlib.h>
#import <stdint.h>
#ifdef _WIN32
//MSYS2のjmorecfg.hは先頭でshlwapi.hを読むが、shlwapi.hはinterface等の定義（windows.h経由のobjbase.h）が前提なので、先にwindows.hを読んでおく
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#import <windows.h>
#endif
#import <jpeglib.h>

#import "../rsiv.h"
#import "jpeg.h"

Image *load_jpeg(FILE *f) {
	struct jpeg_decompress_struct cinfo;
	struct jpeg_error_mgr jerr;

	cinfo.err = jpeg_std_error(&jerr);
	jpeg_create_decompress(&cinfo);

	jpeg_stdio_src(&cinfo, f);

	jpeg_read_header(&cinfo, TRUE);

	//RGBA相当のRGB出力
	cinfo.out_color_space = JCS_RGB;

	jpeg_start_decompress(&cinfo);

	uint64_t width = cinfo.output_width;
	uint64_t height = cinfo.output_height;

	RGBA *data = (RGBA *)malloc(width * height * sizeof(RGBA));
	if (data == NULL) {
		jpeg_finish_decompress(&cinfo);
		jpeg_destroy_decompress(&cinfo);
		fclose(f);
		return NULL;
	}

	uint8_t *row = (uint8_t *)malloc(width * 3);
	if (row == NULL) {
		free(data);
		jpeg_finish_decompress(&cinfo);
		jpeg_destroy_decompress(&cinfo);
		fclose(f);
		return NULL;
	}

	while (cinfo.output_scanline < cinfo.output_height) {
		JSAMPROW row_pointer = row;

		jpeg_read_scanlines(&cinfo, &row_pointer, 1);

		uint64_t y = cinfo.output_scanline - 1;

		for (uint64_t x = 0; x < width; x++) {
			uint64_t i = y * width + x;

			data[i].r = row[x * 3 + 0];
			data[i].g = row[x * 3 + 1];
			data[i].b = row[x * 3 + 2];
			data[i].a = 255;
		}
	}

	free(row);

	jpeg_finish_decompress(&cinfo);
	jpeg_destroy_decompress(&cinfo);

	Image *img = (Image *)malloc(sizeof(Image));
	img->width = width;
	img->height = height;
	img->data = data;
	img->count = 1;
	img->fps = 0;

	return img;
}