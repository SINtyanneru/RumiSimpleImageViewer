#import "../foundation.h"
#import <stdint.h>
#import <stdlib.h>
#import <stdbool.h>

#import "../rsiv.h"
#import "../testpattern.h"
#import "../platform.h"

#import "png.h"
#import "jpeg.h"
#import "webp.h"
#import "gif.h"
#import "mag.h"
#import "maki.h"
#import "bmp.h"
#import "pi.h"
#import "svg.h"

static const uint8_t PNG_MAGIC[] = { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A };

typedef enum {
	Image_Unknown,
	Image_PNG,
	Image_JPEG,
	Image_WEBP,
	Image_GIF,
	Image_Video,
	Image_MAG,
	Image_MAKI,
	Image_BMP,
	Image_PI,
	Image_SVG
} ImageType;

ImageType get_type(FILE *f) {
	uint8_t header[12] = {0};
	size_t size = fread(header, 1, sizeof(header), f);

	//PNG
	if (size >= 8) {
		if (memcmp(header, PNG_MAGIC, 8) == 0) return Image_PNG;
	}

	//JPEG
	if (size >= 3) {
		if (header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF) return Image_JPEG;
	}

	//WebP (RIFF)
	if (size >= 12) {
		if (memcmp(header, "RIFF", 4) == 0 && memcmp(header + 8, "WEBP", 4) == 0) return Image_WEBP;
	}

	//GIF
	if (size >= 6) {
		if (memcmp(header, "GIF87a", 6) == 0 || memcmp(header, "GIF89a", 6) == 0) return Image_GIF;
	}

	//MAG
	if (size >= 6) {
		if (memcmp(header, "MAKI02", 6) == 0) return Image_MAG;
	}

	//MAKI
	if (size >= 6) {
		if (memcmp(header, "MAKI01", 6) == 0) return Image_MAKI;
	}

	//BMP
	if (size >= 2) {
		if (header[0] == 'B' && header[1] == 'M') return Image_BMP;
	}

	//Pi
	if (size >= 2) {
		if (header[0] == 'P' && header[1] == 'i') return Image_PI;
	}

	//SVG（XMLテキストなので先頭2KB以内に<svgがあるかで判定）
	{
		uint8_t buf[2048];
		fseek(f, 0, SEEK_SET);
		size_t n = fread(buf, 1, sizeof(buf), f);
		for (size_t i = 0; i + 4 <= n; i++) {
			if (memcmp(buf + i, "<svg", 4) == 0) return Image_SVG;
		}
	}

	return Image_Unknown;
}

static Image *load_image_impl(NSString *path, bool *want_fallback) {
	Image *image = NULL;
	*want_fallback = false;

	FILE *f = rsiv_fopen([path UTF8String], "rb");
	if (f == false) {
		*want_fallback = true;
		return NULL;
	}

	ImageType type = get_type(f);
	rewind(f);

	switch (type) {
		case Image_PNG: {
			image = load_png(f);
			break;
		}

		case Image_JPEG: {
			image = load_jpeg(f);
			break;
		}

		case Image_WEBP: {
			image = load_webp(f);
			break;
		}

		case Image_GIF: {
			image = load_gif(f);
			break;
		}

		case Image_MAG: {
			image = load_mag(f);
			break;
		}

		case Image_MAKI: {
			image = load_maki(f);
			break;
		}

		case Image_BMP: {
			image = load_bmp(f);
			break;
		}

		case Image_PI: {
			image = load_pi(f);
			break;
		}

		case Image_SVG: {
			image = load_svg(f);
			break;
		}

		default: {
			*want_fallback = true;
		}
	}

	fclose(f);

	return image;
}

static Image *make_fallback_image() {
	Image *image = malloc(sizeof(Image));
	image->width = 1920;
	image->height = 1440;
	image->count = 1;
	image->fps = 0;
	image->data = malloc(image->width * image->height * sizeof(RGBA));
	draw_fubk(image);
	return image;
}

Image *load_image(NSString *path) {
	bool want_fallback = false;
	Image *image = load_image_impl(path, &want_fallback);

	if (image == NULL && want_fallback)
		image = make_fallback_image();

	return image;
}

Image *load_image_strict(NSString *path) {
	bool want_fallback = false;
	return load_image_impl(path, &want_fallback);
}