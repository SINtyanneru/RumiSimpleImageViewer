//Linux / macOS では本物の Foundation、それ以外（Windows・BSD 等）では自前の UnFoundation を使う
#if defined(__linux__) || defined(__APPLE__)
#import <Foundation/Foundation.h>
#else
#import "UnFoundation.h"
#endif
