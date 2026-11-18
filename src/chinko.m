//名前が思いつかんかった
#import <stdlib.h>
#import <stdio.h>
#import <stdbool.h>
#import <pthread.h>
#import <stdatomic.h>
#import <GLFW/glfw3.h>

#import "rsiv.h"
#import "format/format.h"

static UnStringList *global_path_list;

// static void shared_image_update(SharedImage *shared_image, Image *img) {
// 	pthread_mutex_lock(&shared_image->lock);

// 	shared_image->image = img;

// 	atomic_fetch_add(&shared_image->version, 1);

// 	pthread_mutex_unlock(&shared_image->lock);

// 	glfwPostEmptyEvent();
// }

static void shared_title_update(SharedImage *shared_image, const char *title) {
	pthread_mutex_lock(&shared_image->title_bar.lock);

	snprintf(shared_image->title_bar.title, sizeof(shared_image->title_bar.title), "RSIV - %s", title);

	__atomic_fetch_add(&shared_image->title_bar.version, 1, __ATOMIC_SEQ_CST);

	pthread_mutex_unlock(&shared_image->title_bar.lock);
}

void check_event_dd(SharedImage *shared_image) {
	un_list_clear(global_path_list);

	pthread_mutex_lock(&shared_image->dd.lock);
	pthread_mutex_lock(&shared_image->lock);

	UnStringList *path_list = shared_image->dd.path_list;

	int count = un_list_count(path_list);
	for (int i = 0; i < count; i++) {
		const char *path = un_list_get(path_list, i);

		shared_image->image = load_image(path);
		shared_image->version += 1;

		shared_title_update(shared_image, path);

		un_list_add(global_path_list, path);
	}

	un_list_clear(shared_image->dd.path_list);

	pthread_mutex_unlock(&shared_image->lock);
	pthread_mutex_unlock(&shared_image->dd.lock);
}

void *chinko_main(void *p) {
	SharedImage *shared_image = (SharedImage *)p;

	shared_image->image = load_image("");

	//初期化
	global_path_list = un_list_create();

	while (true) {
		check_event_dd(shared_image);

		//なんらかの作業
	}

	return NULL;
}
