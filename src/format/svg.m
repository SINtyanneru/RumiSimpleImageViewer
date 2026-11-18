#import <stdio.h>
#import <stdlib.h>
#import <stdint.h>
#import <string.h>

#import <librsvg/rsvg.h>
#import <cairo.h>

#import "../rsiv.h"

//SVGをラスタライズする最大サイズ（FHD）
#define SVG_MAX_W 1920.0
#define SVG_MAX_H 1080.0

Image *load_svg(FILE *f) {
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

	GError *error = NULL;
	RsvgHandle *handle = rsvg_handle_new_from_data(buf, (gsize)file_size, &error);
	if (handle == NULL) {
		if (error != NULL)
			g_error_free(error);
		free(buf);
		return NULL;
	}

	//元の大きさ（取れなければFHDを仮の大きさにする）
	double base_w = SVG_MAX_W;
	double base_h = SVG_MAX_H;
	double px_w = 0;
	double px_h = 0;

	if (rsvg_handle_get_intrinsic_size_in_pixels(handle, &px_w, &px_h) && px_w > 0 && px_h > 0) {
		base_w = px_w;
		base_h = px_h;
	} else {
		//ピクセルで大きさが取れないときはviewBoxを使う
		gboolean has_viewbox = FALSE;
		RsvgRectangle viewbox = { 0, 0, 0, 0 };
		rsvg_handle_get_intrinsic_dimensions(handle, NULL, NULL, NULL, NULL, &has_viewbox, &viewbox);
		if (has_viewbox && viewbox.width > 0 && viewbox.height > 0) {
			base_w = viewbox.width;
			base_h = viewbox.height;
		}
	}

	//FHDに収まる大きさへ（縦横比は維持）
	double scale = SVG_MAX_W / base_w;
	double scale_y = SVG_MAX_H / base_h;
	if (scale_y < scale)
		scale = scale_y;

	int32_t out_w = (int32_t)(base_w * scale + 0.5);
	int32_t out_h = (int32_t)(base_h * scale + 0.5);
	if (out_w < 1)
		out_w = 1;
	if (out_h < 1)
		out_h = 1;

	cairo_surface_t *surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, out_w, out_h);
	cairo_t *cr = cairo_create(surface);

	RsvgRectangle viewport = { 0, 0, (double)out_w, (double)out_h };
	rsvg_handle_render_document(handle, cr, &viewport, &error);

	cairo_destroy(cr);
	cairo_surface_flush(surface);

	if (error != NULL) {
		g_error_free(error);
		cairo_surface_destroy(surface);
		g_object_unref(handle);
		free(buf);
		return NULL;
	}

	RGBA *data = malloc((size_t)out_w * (size_t)out_h * sizeof(RGBA));
	if (data == NULL) {
		cairo_surface_destroy(surface);
		g_object_unref(handle);
		free(buf);
		return NULL;
	}

	//cairoのARGB32（乗算済みBGRA）→RGBA（乗算なし）へ
	const uint8_t *src = cairo_image_surface_get_data(surface);
	int stride = cairo_image_surface_get_stride(surface);

	for (int32_t y = 0; y < out_h; y++) {
		const uint8_t *row = src + (size_t)y * (size_t)stride;

		for (int32_t x = 0; x < out_w; x++) {
			const uint8_t *sp = row + (size_t)x * 4;
			uint8_t *dp = (uint8_t *)(data + (size_t)y * (size_t)out_w + x);
			uint32_t a = sp[3];

			if (a == 0) {
				dp[0] = 0;
				dp[1] = 0;
				dp[2] = 0;
			} else if (a == 255) {
				dp[0] = sp[2];
				dp[1] = sp[1];
				dp[2] = sp[0];
			} else {
				dp[0] = (uint8_t)(((uint32_t)sp[2] * 255 + a / 2) / a);
				dp[1] = (uint8_t)(((uint32_t)sp[1] * 255 + a / 2) / a);
				dp[2] = (uint8_t)(((uint32_t)sp[0] * 255 + a / 2) / a);
			}
			dp[3] = (uint8_t)a;
		}
	}

	cairo_surface_destroy(surface);
	g_object_unref(handle);
	free(buf);

	Image *img = malloc(sizeof(Image));
	if (img == NULL) {
		free(data);
		return NULL;
	}

	img->data = data;
	img->width = (uint64_t)out_w;
	img->height = (uint64_t)out_h;
	img->count = 1;
	img->fps = 0;

	return img;
}
