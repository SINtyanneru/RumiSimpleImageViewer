#import <Foundation/Foundation.h>
#import <stdint.h>
#import <stdlib.h>
#import <stdbool.h>

#import "../rsiv.h"
#import "../testpattern.h"

#import "png.h"
#import "jpeg.h"
#import "webp.h"
#import "gif.h"
#import "mag.h"
#import "maki.h"
#import "bmp.h"
#import "pi.h"

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
	Image_PI
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

	return Image_Unknown;
}

Image *load_image(NSString *path) {
	Image *image = NULL;

	FILE *f = fopen([path UTF8String], "rb");
	if (f == false) {
		image = malloc(sizeof(Image));
		image->width = 1920;
		image->height = 1440;
		image->count = 1;
		image->fps = 0;
		image->data = malloc(image->width * image->height * sizeof(RGBA));
		draw_fubk(image);
		return image;
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

		default: {
			image = malloc(sizeof(Image));
			image->width = 1920;
			image->height = 1440;
			image->count = 1;
			image->fps = 0;
			image->data = malloc(image->width * image->height * sizeof(RGBA));
			draw_fubk(image);
		}
	}

	fclose(f);

	return image;
}