//名前が思いつかんかった
#import <stdlib.h>
#import <Foundation/Foundation.h>
#import <pthread.h>
#import <stdatomic.h>
#import <GLFW/glfw3.h>

#import "rsiv.h"
#import "format/format.h"

static NSMutableArray *global_path_list;

void shared_image_update(SharedImage *shared_image, Image *img) {
	pthread_mutex_lock(&shared_image->lock);

	shared_image->image = img;

	atomic_fetch_add(&shared_image->version, 1);

	pthread_mutex_unlock(&shared_image->lock);

	glfwPostEmptyEvent();
}

void check_event_dd(SharedImage *shared_image) {
	[global_path_list removeAllObjects];

	pthread_mutex_lock(&shared_image->dd.lock);
	pthread_mutex_lock(&shared_image->lock);

	@autoreleasepool {
		NSMutableArray *path_list = shared_image->dd.path_list;

		for (NSString *path in path_list) {
			shared_image->image = load_image(path);
			shared_image->version += 1;

			[global_path_list addObject:path];
		}

		[shared_image->dd.path_list removeAllObjects];
	}

	pthread_mutex_unlock(&shared_image->lock);
	pthread_mutex_unlock(&shared_image->dd.lock);
}

void *chinko_main(void *p) {
	SharedImage *shared_image = (SharedImage *)p;

	shared_image->image = load_image(@"");

	//初期化
	global_path_list = [[NSMutableArray alloc] init];

	while (true) {
		check_event_dd(shared_image);

		//なんらかの作業
	}

	return NULL;
}