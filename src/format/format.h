#import "../rsiv.h"

ImageType get_type(FILE *f);

Image *load_image(const char *path);

//テストパターンの代替をしない版（開けない・形式不明ならNULLを返す）
Image *load_image_strict(const char *path);