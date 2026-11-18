#import <stdio.h>
#import <stdlib.h>
#import <gif_lib.h>
#import <string.h>

#import "../rsiv.h"

Image *load_gif(FILE *f) {
	int err = 0;
	GifFileType *gif = DGifOpenFileHandle(fileno(f), &err);

	if (!gif) return NULL;

	if (DGifSlurp(gif) != GIF_OK) {
		DGifCloseFile(gif, NULL);
		return NULL;
	}

	uint32_t w = (uint32_t)gif->SWidth;
	uint32_t h = (uint32_t)gif->SHeight;
	int32_t count = gif->ImageCount;

	if (w == 0 || h == 0 || count == 0) {
		DGifCloseFile(gif, NULL);
		return NULL;
	}

	RGBA *data = malloc((size_t)w * h * count * sizeof(RGBA));
	RGBA *canvas = calloc((size_t)w * h, sizeof(RGBA));
	RGBA *prev = malloc((size_t)w * h * sizeof(RGBA));

	if (!data || !canvas || !prev) {
		free(data);
		free(canvas);
		free(prev);
		DGifCloseFile(gif, NULL);
		return NULL;
	}

	double fps = 0;

	for (int32_t i = 0; i < count; i++) {
		SavedImage *frame = &gif->SavedImages[i];
		GifImageDesc *desc = &frame->ImageDesc;
		ColorMapObject *cmap = desc->ColorMap ? desc->ColorMap : gif->SColorMap;

		//グラフィック制御拡張（遅延・透明・廃棄方法）
		int disposal = 0;
		int trans_index = -1;
		int delay = 0;

		for (int j = 0; j < frame->ExtensionBlockCount; j++) {
			ExtensionBlock *ext = &frame->ExtensionBlocks[j];
			if (ext->Function == GRAPHICS_EXT_FUNC_CODE && ext->ByteCount == 4) {
				disposal = (ext->Bytes[0] >> 2) & 0x07;
				if (ext->Bytes[0] & 0x01)
					trans_index = ext->Bytes[3];
				delay = ext->Bytes[1] | (ext->Bytes[2] << 8);
			}
		}

		if (i == 0 && delay != 0)
			fps = delay / 100.0;

		//廃棄方法3（直前に戻す）用に退避
		if (disposal == 3)
			memcpy(prev, canvas, (size_t)w * h * sizeof(RGBA));

		//キャンバスへ合成
		for (int32_t y = 0; y < desc->Height; y++) {
			for (int32_t x = 0; x < desc->Width; x++) {
				uint8_t index = frame->RasterBits[(size_t)y * desc->Width + x];
				if ((int)index == trans_index)
					continue;

				GifColorType color = cmap->Colors[index];
				uint8_t *px = (uint8_t *)(canvas + (size_t)(desc->Top + y) * w + (desc->Left + x));
				px[0] = color.Red;
				px[1] = color.Green;
				px[2] = color.Blue;
				px[3] = 0xFF;
			}
		}

		memcpy(data + (size_t)i * w * h, canvas, (size_t)w * h * sizeof(RGBA));

		//廃棄
		if (disposal == 2) {
			for (int32_t y = 0; y < desc->Height; y++) {
				memset(canvas + (size_t)(desc->Top + y) * w + desc->Left, 0, (size_t)desc->Width * sizeof(RGBA));
			}
		} else if (disposal == 3) {
			memcpy(canvas, prev, (size_t)w * h * sizeof(RGBA));
		}
	}

	free(canvas);
	free(prev);
	DGifCloseFile(gif, NULL);

	Image *img = malloc(sizeof(Image));

	if (!img) {
		free(data);
		return NULL;
	}

	img->data = data;
	img->width = w;
	img->height = h;
	img->count = count;
	img->fps = (count > 1) ? fps : 0;

	return img;
}
