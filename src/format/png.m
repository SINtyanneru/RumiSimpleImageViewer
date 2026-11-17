#import <png.h>
#import <setjmp.h>

#import "../rsiv.h"

Image *load_png(FILE *f) {
	uint8_t sig[8];

	if (fread(sig, 1, 8, f) != 8 || png_sig_cmp(sig, 0, 8)) {
		return NULL;
	}

	png_structp png = png_create_read_struct(
		PNG_LIBPNG_VER_STRING, NULL, NULL, NULL
	);

	if (!png) return NULL;

	png_infop info = png_create_info_struct(png);

	if (!info) {
		png_destroy_read_struct(&png, NULL, NULL);
		return NULL;
	}

	typedef struct {
		RGBA *data;
		png_bytep *rows;
	} PNGMemory;

	volatile PNGMemory memory = { NULL, NULL };

	if (setjmp(png_jmpbuf(png))) {
		free(memory.data);
		free(memory.rows);

		png_destroy_read_struct(&png, &info, NULL);
		return NULL;
	}

	png_init_io(png, f);
	png_set_sig_bytes(png, 8);

	png_read_info(png, info);

	png_uint_32 w = png_get_image_width(png, info);
	png_uint_32 h = png_get_image_height(png, info);

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

	if (color_type == PNG_COLOR_TYPE_GRAY ||
		color_type == PNG_COLOR_TYPE_GRAY_ALPHA)
		png_set_gray_to_rgb(png);

	if (!(color_type & PNG_COLOR_MASK_ALPHA) &&
		!png_get_valid(png, info, PNG_INFO_tRNS))
		png_set_filler(png, 0xFF, PNG_FILLER_AFTER);

	png_set_interlace_handling(png);
	png_read_update_info(png, info);

	if (png_get_rowbytes(png, info) != (png_size_t)w * sizeof(RGBA))
		png_error(png, "Invalid row size");

	memory.data = malloc((size_t)w * h * sizeof(RGBA));
	memory.rows = malloc(sizeof(png_bytep) * h);

	if (!memory.data || !memory.rows)
		png_error(png, "Out of memory");

	for (png_uint_32 y = 0; y < h; y++) {
		memory.rows[y] = (png_bytep)(memory.data + (size_t)y * w);
	}

	png_read_image(png, (png_bytepp)memory.rows);
	png_read_end(png, NULL);

	free(memory.rows);
	memory.rows = NULL;

	png_destroy_read_struct(&png, &info, NULL);

	Image *img = malloc(sizeof(Image));

	if (!img) {
		free(memory.data);
		return NULL;
	}

	img->data = memory.data;
	img->width = w;
	img->height = h;

	return img;
}
