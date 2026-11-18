#import "UnFoundation.h"
#import <stdint.h>
#import <pthread.h>

//C++（jpeg.mm）からは stdatomic.h を読まない（GCC の stdatomic.h は C++ で使えない）。
//レイアウト互換のためだけに素の uint32_t にしておく（C++ 側はこのフィールドを操作しない）
#ifdef __cplusplus
typedef uint32_t RsivAtomicU32;
#else
#import <stdatomic.h>
typedef _Atomic uint32_t RsivAtomicU32;
#endif

typedef struct {
	uint8_t r;
	uint8_t g;
	uint8_t b;
	uint8_t a;
} RGBA;

typedef struct {
	uint64_t width;
	uint64_t height;
	RGBA *data;

	uint64_t count;
	double fps;
} Image;








typedef struct {
	pthread_mutex_t lock;
	UnStringList *path_list;
} DD;

typedef struct {
	pthread_mutex_t lock;
	char title[256];
	RsivAtomicU32 version;
} TitleBar;

typedef struct {
	//画像データ
	pthread_mutex_t lock;
	RsivAtomicU32 version;
	Image *image;

	DD dd;
	TitleBar title_bar;
} SharedImage;