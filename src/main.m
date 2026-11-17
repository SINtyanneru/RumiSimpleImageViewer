#include "Foundation/NSArray.h"
#import <Foundation/Foundation.h>
#import <stdlib.h>
#import <stdio.h>
#import <pthread.h>
#import <stdbool.h>
#import <stdatomic.h>
#import <GLFW/glfw3.h>

#import "rsiv.h"
#import "format/format.h"
#import "gpuui.h"
#import "chinko.h"

int main(void) {
	//共有変数
	SharedImage *shared_image = malloc(sizeof(SharedImage));
	pthread_mutex_init(&shared_image->lock, NULL);

	//ドラドロを初期化
	pthread_mutex_init(&shared_image->dd.lock, NULL);
	shared_image->dd.path_list = [[NSMutableArray alloc] init];

	//別スレッドでちんこを開始
	pthread_t ui_thread;
	pthread_create(&ui_thread, NULL, chinko_main, shared_image);

	//メインスレッドでUIを軌道
	gpuui_main(shared_image);

	pthread_join(ui_thread, NULL);
	pthread_mutex_destroy(&shared_image->lock);
}