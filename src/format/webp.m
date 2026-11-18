#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <webp/demux.h>

#import "../rsiv.h"

Image *load_webp(FILE *f) {
	fseek(f, 0, SEEK_END);
	long file_size = ftell(f);
	rewind(f);

	if (file_size <= 0) {
		return NULL;
	}

	uint8_t *buffer = malloc(file_size);
	if (buffer == NULL) {
		return NULL;
	}

	if (fread(buffer, 1, file_size, f) != (size_t)file_size) {
		free(buffer);
		return NULL;
	}

	WebPAnimDecoderOptions opt;
	WebPAnimDecoderOptionsInit(&opt);

	WebPData webp_data = { buffer, (size_t)file_size };
	WebPAnimDecoder *dec = WebPAnimDecoderNew(&webp_data, &opt);

	if (dec == NULL) {
		free(buffer);
		return NULL;
	}

	WebPAnimInfo info;
	if (!WebPAnimDecoderGetInfo(dec, &info)) {
		WebPAnimDecoderDelete(dec);
		free(buffer);
		return NULL;
	}

	uint32_t w = info.canvas_width;
	uint32_t h = info.canvas_height;
	int32_t count = (int32_t)info.frame_count;

	if (w == 0 || h == 0 || count == 0 ||
		(size_t)w > SIZE_MAX / 4 / (size_t)h / (size_t)count) {
		WebPAnimDecoderDelete(dec);
		free(buffer);
		return NULL;
	}

	RGBA *data = malloc((size_t)w * h * count * sizeof(RGBA));

	if (data == NULL) {
		WebPAnimDecoderDelete(dec);
		free(buffer);
		return NULL;
	}

	double fps = 0;

	for (int32_t i = 0; i < count; i++) {
		uint8_t *frame = NULL;
		int timestamp = 0;

		if (!WebPAnimDecoderGetNext(dec, &frame, &timestamp)) {
			free(data);
			WebPAnimDecoderDelete(dec);
			free(buffer);
			return NULL;
		}

		memcpy(data + (size_t)i * w * h, frame, (size_t)w * h * sizeof(RGBA));

		//先頭フレームの表示時間（ミリ秒）→秒
		if (i == 0)
			fps = timestamp / 1000.0;
	}

	WebPAnimDecoderDelete(dec);
	free(buffer);

	if (count > 1 && fps == 0)
		fps = 0.1;

	Image *img = malloc(sizeof(Image));
	if (img == NULL) {
		free(data);
		return NULL;
	}

	img->width = (int32_t)w;
	img->height = (int32_t)h;
	img->data = data;
	img->count = count;
	img->fps = (count > 1) ? fps : 0;

	return img;
}
