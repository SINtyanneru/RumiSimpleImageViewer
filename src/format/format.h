#import "../foundation.h"

#import "../rsiv.h"

Image *load_image(NSString *path);

//テストパターンの代替をしない版（開けない・形式不明ならNULLを返す）
Image *load_image_strict(NSString *path);