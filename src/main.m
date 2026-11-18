#import "UnFoundation.h"
#import <stdlib.h>
#import <stdio.h>
#import <string.h>
#import <pthread.h>
#import <stdbool.h>
#import <stdatomic.h>
#import <GLFW/glfw3.h>

#import "rsiv.h"
#import "format/format.h"
#import "gpuui.h"
#import "chinko.h"
#import "thumbnail.h"
#ifdef __APPLE__
#import "macopen.h"
#endif

int main(int argc, char **argv) {
#if !defined(__linux__) && !defined(__APPLE__)
	//UnFoundation.c の引数受け口へ渡しておく（Windows では使われない）
	rsiv_argc = argc;
	rsiv_argv = argv;
#endif

	//サムネイル生成モード（ファイルマネージャーから呼ばれる、ウィンドウは開かない）
	{
		if (un_arg_count() >= 2 && strcmp(un_arg_get(1), "--thumbnail") == 0) {
			if (un_arg_count() != 5)
				return 1;
			return make_thumbnail(un_arg_get(2), un_arg_get(3), atoi(un_arg_get(4)));
		}
	}

	//共有変数
	SharedImage *shared_image = malloc(sizeof(SharedImage));
	pthread_mutex_init(&shared_image->lock, NULL);

	//ドラドロを初期化
	pthread_mutex_init(&shared_image->dd.lock, NULL);
	shared_image->dd.path_list = un_list_create();

#ifdef __APPLE__
	//Finder の関連付けから開かれたときの受け口（macOS は argv ではなく Apple Event で渡してくる）
	rsiv_mac_install_open_handler(shared_image);
#endif

	//引数
	if (un_arg_count() >= 2)
		un_list_add(shared_image->dd.path_list, un_arg_get(1));

	//タイトルバーを初期化
	pthread_mutex_init(&shared_image->title_bar.lock, NULL);
	snprintf(shared_image->title_bar.title, sizeof(shared_image->title_bar.title), "%s", "RSIV - んご");
	shared_image->title_bar.version = 0;

	//デフォルト画像を初期化
	shared_image->image = load_image("");

	//別スレッドでちんこを開始
	pthread_t ui_thread;
	pthread_create(&ui_thread, NULL, chinko_main, shared_image);

	//メインスレッドでUIを軌道
	gpuui_main(shared_image);

	pthread_join(ui_thread, NULL);
	pthread_mutex_destroy(&shared_image->lock);
}
