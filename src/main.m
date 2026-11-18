#import "Foundation/NSArray.h"
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
#import "thumbnail.h"

int main(void) {
	//サムネイル生成モード（ファイルマネージャーから呼ばれる、ウィンドウは開かない）
	{
		NSArray<NSString *> *args = [[NSProcessInfo processInfo] arguments];
		if ([args count] >= 2 && [[args objectAtIndex:1] isEqualToString:@"--thumbnail"]) {
			if ([args count] != 5)
				return 1;
			return make_thumbnail([args objectAtIndex:2], [args objectAtIndex:3], [[args objectAtIndex:4] intValue]);
		}
	}

	//共有変数
	SharedImage *shared_image = malloc(sizeof(SharedImage));
	pthread_mutex_init(&shared_image->lock, NULL);

	//ドラドロを初期化
	pthread_mutex_init(&shared_image->dd.lock, NULL);
	shared_image->dd.path_list = [[NSMutableArray alloc] init];

	//引数
	NSArray<NSString *> *args = [[NSProcessInfo processInfo] arguments];
	if ([args count] >= 2) {
		NSString *path = [args objectAtIndex:1];
		[shared_image->dd.path_list addObject:path];
	}

	//タイトルバーを初期化
	pthread_mutex_init(&shared_image->title_bar.lock, NULL);
	snprintf(shared_image->title_bar.title, sizeof(shared_image->title_bar.title), "%s", "RSIV - んご");
	shared_image->title_bar.version = 0;

	//デフォルト画像を初期化
	shared_image->image = load_image(@"");

	//別スレッドでちんこを開始
	pthread_t ui_thread;
	pthread_create(&ui_thread, NULL, chinko_main, shared_image);

	//メインスレッドでUIを軌道
	gpuui_main(shared_image);

	pthread_join(ui_thread, NULL);
	pthread_mutex_destroy(&shared_image->lock);
}