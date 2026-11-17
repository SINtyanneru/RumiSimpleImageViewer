#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <webp/decode.h>

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

	int width;
	int height;

	if (!WebPGetInfo(buffer, file_size, &width, &height)) {
		free(buffer);
		return NULL;
	}

	uint8_t *decoded = WebPDecodeRGBA(buffer, file_size, &width, &height);

	free(buffer);

	if (decoded == NULL) {
		return NULL;
	}

	if ((size_t)width > SIZE_MAX / 4 / (size_t)height) {
		WebPFree(decoded);
		return NULL;
	}

	size_t data_size = (size_t)width * height * sizeof(RGBA);

	RGBA *data = malloc(data_size);
	if (data == NULL) {
		WebPFree(decoded);
		return NULL;
	}

	memcpy(data, decoded, data_size);
	WebPFree(decoded);

	Image *img = malloc(sizeof(Image));
	if (img == NULL) {
		free(data);
		return NULL;
	}

	img->width = width;
	img->height = height;
	img->data = data;
	img->count = 1;
	img->fps = 0;

	return img;
}