#import "UnFoundation.h"
#include <stdint.h>
#import <stdlib.h>
#import <stdio.h>
#import <string.h>
#import <math.h>
#import <pthread.h>
#import <stdbool.h>
#import <stdatomic.h>
#import <GLFW/glfw3.h>

#import "rsiv.h"
#import "format/format.h"
#import "gpuui.h"
#import "chinko.h"
#import "thumbnail.h"

#define IMAGE_KEY_MOVE 50
#define IMAGE_KEY_ZOOM 1.0f

#define MENU_HEIGHT 100

static UISharedData *shared_data;

//UIアイテム
static UIItemImage *image_item;
static UIItemRect *menu_rect;

//マウス関係
static double mouse_x = 0;
static double mouse_y = 0;
static bool mouse_left_click = false;

//中央にフィットさせた後、動かしていないか
static bool fit_after_no_move = false;

//メニュー関係
static bool is_open_menu = false;
static double menu_open_time;
static double menu_close_time;
static bool menu_oc_anim_active = false;

static void clamp_axis(int32_t *pos, int32_t size, int32_t win) {
	int32_t center = (win - size) / 2;
	int32_t limit = abs(size - win) / 2;
	if (limit < size / 2) limit = size / 2;
	if (*pos < center - limit) *pos = center - limit;
	if (*pos > center + limit) *pos = center + limit;
}

static void clamp_view() {
	clamp_axis(&image_item->x, image_item->w, get_screen_width());
	clamp_axis(&image_item->y, image_item->h, get_screen_height());
}

/**
 * 画像を中央に設置する
*/
void image_fit_center() {
	uint32_t fw = get_screen_width();
	uint32_t fh = get_screen_height();
	double scale = fmin((double)fw / image_item->img.width, (double)fh / image_item->img.height);
	image_item->w = (int32_t)(image_item->img.width * scale);
	image_item->h = (int32_t)(image_item->img.height * scale);
	image_item->x = (fw - image_item->w) / 2;
	image_item->y = (fh - image_item->h) / 2;

	fit_after_no_move = true;
}

/**
 * 画像を移動する
*/
void image_move(double dx, double dy) {
	image_item->x += (int32_t)dx;
	image_item->y += (int32_t)dy;

	clamp_view();
	fit_after_no_move = false;
}

/**
 * 画像をズームする
*/
void image_zoom(double d) {
	double scale = 1.0 + d * 0.1;
	int32_t cx = get_screen_width() / 2; //画面中央
	int32_t cy = get_screen_height() / 2;
	image_item->x = cx - (int32_t)((cx - image_item->x) * scale);
	image_item->y = cy - (int32_t)((cy - image_item->y) * scale);
	image_item->w = (int32_t)(image_item->w * scale);
	image_item->h = (int32_t)(image_item->h * scale);
	if (image_item->w < 1) image_item->w = 1;
	if (image_item->h < 1) image_item->h = 1;

	clamp_view();
	fit_after_no_move = false;
}

/**
 * 画像を前へ
*/
void image_prev() {
	pthread_mutex_lock(&shared_data->image_loder.lock);

	if (shared_data->image_loder.image_select != 0) {
		shared_data->image_loder.image_select -= 1;
	}

	pthread_mutex_unlock(&shared_data->image_loder.lock);
}

/**
 * 画像を次へ
*/
void image_next() {
	pthread_mutex_lock(&shared_data->image_loder.lock);

	if ((shared_data->image_loder.image_select + 1) < shared_data->image_loder.image_count) {
		shared_data->image_loder.image_select += 1;
	}

	pthread_mutex_unlock(&shared_data->image_loder.lock);
}

/**
 * キーを押下した
*/
void on_key_press(int key, int mods) {
	if (key == GLFW_KEY_X) {
		image_fit_center();

	} else if (key == GLFW_KEY_M) {
		if (is_open_menu) {
			is_open_menu = false;
			menu_oc_anim_active = true;
			menu_close_time = glfwGetTime();
		} else {
			is_open_menu = true;
			menu_oc_anim_active = true;
			menu_open_time = glfwGetTime();
		}

	} else if (key == GLFW_KEY_ESCAPE && is_open_menu) {
		is_open_menu = false;
		menu_oc_anim_active = true;
		menu_close_time = glfwGetTime();
	}

	if (is_open_menu == false) {
		if ((key == GLFW_KEY_UP || key == GLFW_KEY_F) && (mods & GLFW_MOD_CONTROL || mods & GLFW_MOD_ALT)) {
			image_zoom(IMAGE_KEY_ZOOM);

		} else if ((key == GLFW_KEY_DOWN || key == GLFW_KEY_V) && (mods & GLFW_MOD_CONTROL || mods & GLFW_MOD_ALT)) {
			image_zoom(-IMAGE_KEY_ZOOM);

		} else if (key == GLFW_KEY_UP || key == GLFW_KEY_F) {
			image_move(0, IMAGE_KEY_MOVE);

		} else if (key == GLFW_KEY_DOWN || key == GLFW_KEY_V) {
			image_move(0, -IMAGE_KEY_MOVE);

		} else if (key == GLFW_KEY_LEFT || key == GLFW_KEY_C) {
			image_move(IMAGE_KEY_MOVE, 0);

		} else if (key == GLFW_KEY_RIGHT || key == GLFW_KEY_B) {
			image_move(-IMAGE_KEY_MOVE, 0);

		} else if (key == GLFW_KEY_COMMA) {
			image_prev();

		} else if (key == GLFW_KEY_PERIOD) {
			image_next();

		}
	}
}

/**
 * キーを離した
*/
void on_key_release(int key, int mods) {}

/**
 * キー押しっぱ
*/
void on_key_pressing(int key, int mods) {
	if (is_open_menu == false) {
		if ((key == GLFW_KEY_UP || key == GLFW_KEY_F) && (mods & GLFW_MOD_CONTROL || mods & GLFW_MOD_ALT)) {
			image_zoom(IMAGE_KEY_ZOOM);

		} else if ((key == GLFW_KEY_DOWN || key == GLFW_KEY_V) && (mods & GLFW_MOD_CONTROL || mods & GLFW_MOD_ALT)) {
			image_zoom(-IMAGE_KEY_ZOOM);

		} else if (key == GLFW_KEY_UP || key == GLFW_KEY_F) {
			image_move(0, IMAGE_KEY_MOVE);

		} else if (key == GLFW_KEY_DOWN || key == GLFW_KEY_V) {
			image_move(0, -IMAGE_KEY_MOVE);

		} else if (key == GLFW_KEY_LEFT || key == GLFW_KEY_C) {
			image_move(IMAGE_KEY_MOVE, 0);

		} else if (key == GLFW_KEY_RIGHT || key == GLFW_KEY_B) {
			image_move(-IMAGE_KEY_MOVE, 0);

		} else if (key == GLFW_KEY_COMMA) {
			image_prev();

		} else if (key == GLFW_KEY_PERIOD) {
			image_next();

		}
	}
}

/**
 * マウスクリック
*/
void on_mouse_click(int button) {
	if (button == GLFW_MOUSE_BUTTON_LEFT) {
		mouse_left_click = true;
	}
}

/**
 * マウスクリック終わった
*/
void on_mouse_release(int button) {
	if (button == GLFW_MOUSE_BUTTON_LEFT) {
		mouse_left_click = false;
	}
}

/**
 * マウス移動
*/
void on_mouse_move(double x, double y) {
	double dx = x - mouse_x;
	double dy = y - mouse_y;
	mouse_x = x;
	mouse_y = y;;

	if (mouse_left_click && is_open_menu == false) {
		image_move(dx, dy);
	}
}

/**
 * スクロール
*/
void on_mouse_scroll(double delta_x, double delta_y) {
	if (is_open_menu == false) image_zoom(delta_y);
}

/**
 * ウィンドウリサイズ
*/
void on_window_resize(uint32_t width, uint32_t height) {
	if (fit_after_no_move) {
		image_fit_center();
	}

	menu_rect->w = get_screen_width();
	menu_rect->y = get_screen_height() - MENU_HEIGHT;
}

/**
 * ドラドロ
*/
void on_dd(int count, const char **pathlp) {
	pthread_mutex_lock(&shared_data->dd.lock);

	un_list_clear(shared_data->dd.path_list);

	for (int i = 0; i < count; i++) {
		if (pathlp[i] != NULL) un_list_add(shared_data->dd.path_list, pathlp[i]);
	}

	shared_data->dd.version += 1;

	pthread_mutex_unlock(&shared_data->dd.lock);
}

/**
 * メインループ
*/
void main_loop() {
	if (is_open_menu) {
		if (menu_oc_anim_active) {
			double t = (glfwGetTime() - menu_open_time) / 0.25;
			if (t < 0.0) t = 0.0;
			if (t >= 1.0) {
				t = 1.0;
				menu_oc_anim_active = false;
			}

			double e = 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t);
			uint8_t a = (uint8_t)(230 * e);
			if (a != menu_rect->color.a) {
				menu_rect->color.a = a;
				menu_rect->texture_version += 1;
			}
		}
	} else {
		if (menu_oc_anim_active) {
			double t = (glfwGetTime() - menu_close_time) / 0.25;
			if (t < 0.0) t = 0.0;
			if (t >= 1.0) {
				t = 1.0;
				menu_oc_anim_active = false;
			}

			double e = 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t);
			uint8_t a = (uint8_t)(230 * (1.0 - e));
			if (a != menu_rect->color.a) {
				menu_rect->color.a = a;
				menu_rect->texture_version += 1;
			}
		}
	}
}

/**
 * 初期化
*/
static void init() {
	//共有変数
	shared_data = calloc(1, sizeof(UISharedData));

	//ドラドロを初期化
	pthread_mutex_init(&shared_data->dd.lock, NULL);
	shared_data->dd.path_list = un_list_create();

	//タイトルバーを初期化
	pthread_mutex_init(&shared_data->title_bar.lock, NULL);
	snprintf(shared_data->title_bar.title, sizeof(shared_data->title_bar.title), "%s", "RSIV - んご");
	shared_data->title_bar.version = 0;

	//画像ロードスレッド用
	pthread_mutex_init(&shared_data->image_loder.lock, NULL);

	//UIアイテムを初期化
	pthread_mutex_init(&shared_data->uiitem_lock, NULL);
	for (size_t i = 0; i < UIITEM_LENGTH; i++) {
		shared_data->item_list[i].type = UIItem_None;
	}

	image_item = calloc(1, sizeof(UIItemImage));
	image_item->x = 0;
	image_item->y = 0;
	image_item->w = 1920;
	image_item->h = 1440;
	image_item->img = *load_image("");
	shared_data->item_list[0].type = UIItem_Image;
	shared_data->item_list[0].item = image_item;
	image_fit_center();

	menu_rect = calloc(1, sizeof(UIItemImage));
	menu_rect->x = 0;
	menu_rect->y = get_screen_height() - MENU_HEIGHT;
	menu_rect->w = get_screen_width();
	menu_rect->h = MENU_HEIGHT;
	menu_rect->color.r = 0xFF;
	menu_rect->color.g = 0xFF;
	menu_rect->color.b = 0xFF;
	menu_rect->color.a = 0x00;
	shared_data->item_list[1].type = UIItem_Rect;
	shared_data->item_list[1].item = menu_rect;
}

/**
 * メイン関数
*/
static int rsiv_main(int argc, char **argv) {
	//引数
	if (un_arg_count() >= 2) {
		un_list_add(shared_data->dd.path_list, un_arg_get(1));
		shared_data->dd.version += 1;
	}

	//別スレッドでちんこを開始
	pthread_t ui_thread;
	pthread_create(&ui_thread, NULL, chinko_main, shared_data);

	//メインスレッドでUIを軌道
	gpuui_main(shared_data);

	pthread_join(ui_thread, NULL);

	return 0;
}

#ifdef __APPLE__
#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	rsiv_main(0, NULL);
}

- (void)application:(NSApplication *)application openFiles:(NSArray<NSString *> *)filenames {
	for (NSString *filename in filenames) {
		const char *path = [filename UTF8String];

		pthread_mutex_lock(&shared_data->dd.lock);
		un_list_add(shared_data->dd.path_list, strdup(path));
		shared_data->dd.version += 1;
		pthread_mutex_unlock(&shared_data->dd.lock);
	}

	[application replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
}

@end
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

	init();

#ifdef __APPLE__
	@autoreleasepool {
		NSApplication *app = [NSApplication sharedApplication];
		AppDelegate *delegate = [[AppDelegate alloc] init];
		app.delegate = delegate;
		[app setActivationPolicy:NSApplicationActivationPolicyRegular];
		[app run];
		//macOSはここで終了
	}
#endif

	return rsiv_main(argc, argv);
}
