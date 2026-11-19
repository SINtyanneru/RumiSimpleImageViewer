//名前が思いつかんかった
#include <stdint.h>
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
static uint16_t version = 0;
static uint64_t last_image_select = 0;

static void shared_title_update(UISharedData *shared, const char *title) {
	pthread_mutex_lock(&shared->title_bar.lock);

	snprintf(shared->title_bar.title, sizeof(shared->title_bar.title), "RSIV - %s", title);

	__atomic_fetch_add(&shared->title_bar.version, 1, __ATOMIC_SEQ_CST);

	pthread_mutex_unlock(&shared->title_bar.lock);
}

static void switch_image(UISharedData *shared, uint64_t select) {
	const char *path = un_list_get(global_path_list, select);

	shared_title_update(shared, "読み込み中...");

	//画像をロード
	Image image = *load_image(path);

	//画像を入れ替え
	pthread_mutex_lock(&shared->uiitem_lock);

	shared_title_update(shared, "メモリにロード中...");

	UIItemImage *image_item = (UIItemImage *)shared->item_list[0].item;
	image_item->img = image;
	image_item->texture_version += 1;

	//画像サイズに合わせて変形
	image_item->w = image.width;
	image_item->h = image.height;

	image_fit_center();

	pthread_mutex_unlock(&shared->uiitem_lock);

	//タイトル
	shared_title_update(shared, path);
}

void check_event_dd(UISharedData *shared) {
	pthread_mutex_lock(&shared->dd.lock);

	if (shared->dd.version == version) {
		//何もアクションがなかったのでここで終了
		pthread_mutex_unlock(&shared->dd.lock);
		return;
	}

	//パス一覧
	UnStringList *path_list = shared->dd.path_list;
	uint32_t count = (uint32_t) un_list_count(path_list);

	//パスをこっちのスレッドにコピーする
	un_list_clear(global_path_list);
	for (size_t i = 0; i < count; i++) {
		const char *path = un_list_get(path_list, i);
		un_list_add(global_path_list, path);
	}
	un_list_clear(shared->dd.path_list);

	pthread_mutex_unlock(&shared->dd.lock);

	//1枚目の画像を突っ込む
	if (un_list_count(global_path_list) != 0) {
		//画像ローダー通信用に画像の枚数と、初期選択を設定する
		pthread_mutex_lock(&shared->image_loder.lock);

		shared->image_loder.image_select = 0;
		last_image_select = 0;
		shared->image_loder.image_count = count;

		pthread_mutex_unlock(&shared->image_loder.lock);

		switch_image(shared, 0);
	}

	version = shared->dd.version;
}

void check_image_select_switch(UISharedData *shared) {
	pthread_mutex_lock(&shared->image_loder.lock);

	if (last_image_select == shared->image_loder.image_select) {
		//変更はなかった
		pthread_mutex_unlock(&shared->image_loder.lock);
		return;
	}

	//一応こっちでもはみ出てないことを確認する
	if (shared->image_loder.image_select > shared->image_loder.image_count) {
		pthread_mutex_unlock(&shared->image_loder.lock);
		return;
	}

	switch_image(shared, shared->image_loder.image_select);
	last_image_select = shared->image_loder.image_select;

	pthread_mutex_unlock(&shared->image_loder.lock);
}

void *chinko_main(void *p) {
	UISharedData *shared = (UISharedData *)p;

	//初期化
	global_path_list = un_list_create();

	while (true) {
		check_event_dd(shared);
		check_image_select_switch(shared);
	}

	return NULL;
}
