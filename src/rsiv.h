#import "UnFoundation.h"
#import <stdint.h>
#import <pthread.h>
#import <GLFW/glfw3.h>

#define UIITEM_LENGTH 16

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




typedef enum {
	UIItem_None,
	UIItem_Rect,
	UIItem_Image,
	UIItem_Text
} UIItemType;

typedef struct {
	UIItemType type;
	void *item;
} UIItem;

typedef struct {
	int32_t x;
	int32_t y;
	int32_t w;
	int32_t h;
	RGBA color;

	uint64_t texture_version;
	uint64_t texture_synced_version;
	GLuint texture;
} UIItemRect;

typedef struct {
	int32_t x;
	int32_t y;
	int32_t w;
	int32_t h;
	Image img;

	uint64_t texture_version;
	uint64_t texture_synced_version;
	double anim_start;
	int32_t cur_frame;
	GLuint texture;
} UIItemImage;

typedef struct {
	int32_t x;
	int32_t y;
	uint32_t size;
	char *text;
	RGBA color;

	uint32_t texture_w;
	uint32_t texture_h;
	uint64_t texture_version;
	uint64_t texture_synced_version;
	GLuint texture;
} UIItemText;

typedef struct {
	pthread_mutex_t lock;
	UnStringList *path_list;
} DD;

typedef struct {
	pthread_mutex_t lock;
	char title[256];
	uint32_t version;
} TitleBar;

typedef struct {
	//画像データ
	pthread_mutex_t lock;

	UIItem item_list[UIITEM_LENGTH];

	DD dd;
	TitleBar title_bar;
} UISharedData;