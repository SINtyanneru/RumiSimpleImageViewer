#import "foundation.h"
#import <stdint.h>
#import <stdatomic.h>
#import <pthread.h>

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
	NSMutableArray *path_list;
} DD;

typedef struct {
	pthread_mutex_t lock;
	char title[256];
	_Atomic uint32_t version;
} TitleBar;

typedef struct {
	//画像データ
	pthread_mutex_t lock;
	_Atomic uint32_t version;
	Image *image;

	DD dd;
	TitleBar title_bar;
} SharedImage;