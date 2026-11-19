//名前が思いつかんかった
#import <stdlib.h>
#import <stdio.h>
#import <stdbool.h>
#import <pthread.h>
#import <stdatomic.h>
#import <GLFW/glfw3.h>

#import "rsiv.h"
#import "format/format.h"
#import "main.h"

static UnStringList *global_path_list;

// static void shared_image_update(SharedImage *shared_image, Image *img) {
// 	pthread_mutex_lock(&shared_image->lock);

// 	shared_image->image = img;

// 	atomic_fetch_add(&shared_image->version, 1);

// 	pthread_mutex_unlock(&shared_image->lock);

// 	glfwPostEmptyEvent();
// }

static void shared_title_update(UISharedData *shared, const char *title) {
	pthread_mutex_lock(&shared->title_bar.lock);

	snprintf(shared->title_bar.title, sizeof(shared->title_bar.title), "RSIV - %s", title);

	__atomic_fetch_add(&shared->title_bar.version, 1, __ATOMIC_SEQ_CST);

	pthread_mutex_unlock(&shared->title_bar.lock);
}

void check_event_dd(UISharedData *shared) {
	un_list_clear(global_path_list);

	pthread_mutex_lock(&shared->dd.lock);
	pthread_mutex_lock(&shared->lock);

	UnStringList *path_list = shared->dd.path_list;

	int count = un_list_count(path_list);
	for (int i = 0; i < count; i++) {
		const char *path = un_list_get(path_list, i);

		UIItemImage *image = (UIItemImage *)shared->item_list[0].item;
		image->img = *load_image(path);
		image->texture_version += 1;

		//画像サイズに合わせて変形
		image->w = image->img.width;
		image->h = image->img.height;

		image_fit_center();

		shared_title_update(shared, path);

		un_list_add(global_path_list, path);
	}

	un_list_clear(shared->dd.path_list);

	pthread_mutex_unlock(&shared->lock);
	pthread_mutex_unlock(&shared->dd.lock);
}

void *chinko_main(void *p) {
	UISharedData *shared = (UISharedData *)p;

	//初期化
	global_path_list = un_list_create();

	while (true) {
		check_event_dd(shared);
	}

	return NULL;
}
