//名前が思いつかんかった
#include <stdint.h>
#import <stdlib.h>
#import <stdio.h>
#import <stdbool.h>
#import <pthread.h>
#import <stdatomic.h>
#import <string.h>
#import <dirent.h>
#import <GLFW/glfw3.h>

#import "rsiv.h"
#import "format/format.h"
#import "main.h"
#import "platform.h"

static UnStringList *global_path_list;
static uint16_t version = 0;
static uint64_t last_image_count = 0;
static uint64_t last_image_select = 0;
static char *current_path = NULL;

static void shared_title_update(UISharedData *shared, const char *title) {
	pthread_mutex_lock(&shared->title_bar.lock);

	snprintf(shared->title_bar.title, sizeof(shared->title_bar.title), "RSIV - %s", title);

	__atomic_fetch_add(&shared->title_bar.version, 1, __ATOMIC_SEQ_CST);

	pthread_mutex_unlock(&shared->title_bar.lock);
}

static void change_state(UISharedData *share, const char *state) {
	char buffer[4096];
	sprintf(buffer, "%s [%zu\\%zu](%s)", state, last_image_count, (last_image_select + 1), current_path);
	shared_title_update(share, buffer);
}

static void switch_image(UISharedData *shared, uint64_t select) {
	current_path = (char *)un_list_get(global_path_list, select);

	//タイトル
	change_state(shared, "画像を解析中...");

	//画像をロード
	Image image = *load_image(current_path);

	//画像を入れ替え
	pthread_mutex_lock(&shared->uiitem_lock);

	//タイトル
	change_state(shared, "メモリにロード中...");

	UIItemImage *image_item = (UIItemImage *)shared->item_list[0].item;
	image_item->img = image;
	image_item->texture_version += 1;

	//画像サイズに合わせて変形
	image_item->w = image.width;
	image_item->h = image.height;

	image_fit_center();

	pthread_mutex_unlock(&shared->uiitem_lock);

	//タイトル
	change_state(shared, "");
}

static void get_parent_dir(const char *path, char *out, size_t out_size) {
	snprintf(out, out_size, "%s", path);
	char *slash = strrchr(out, '/');
	if (slash == NULL) {
		snprintf(out, out_size, "%s", ".");
	} else if (slash == out) {
		slash[1] = '\0'; //"/file.png" → "/"
	} else {
		*slash = '\0';
	}
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
		last_image_count = 0;
		last_image_select = 0;
		shared->image_loder.image_count = count;

		pthread_mutex_unlock(&shared->image_loder.lock);

		switch_image(shared, 0);
	}

	//1枚だけ開かれた場合は、同じディレクトリに有る他の画像も漁る
	if (un_list_count(global_path_list) == 1) {
		change_state(shared, "同一ディレクトリ内を探索中...");

		char parent_dir_path[4096];
		get_parent_dir(current_path, parent_dir_path, sizeof(parent_dir_path));

		DIR *dir = opendir(parent_dir_path);
		struct dirent *entry;
		while ((entry = readdir(dir)) != NULL) {
			#ifndef _WIN32
				if (entry->d_type != DT_REG) continue;
			#endif

			char full[4096];
			snprintf(full, sizeof(full), "%s/%s", parent_dir_path, entry->d_name);

			FILE *f = rsiv_fopen(full, "rb");
			if (f == NULL) continue;
			ImageType type = get_type(f); //型名は format.m の定義に合わせて
			fclose(f);

			if (strcmp(full, current_path) == 0) continue;

			//画像みっけ
			if (type != Image_Unknown) {
				un_list_add(global_path_list, full);

				//画像数を増やす
				pthread_mutex_lock(&shared->image_loder.lock);
				shared->image_loder.image_count += 1;
				last_image_count += 1;
				pthread_mutex_unlock(&shared->image_loder.lock);
			}
		}

		//ソート
		change_state(shared, "ソート中...");
		un_list_sort(global_path_list);

		//今選んでる画像が何枚目かを登録
		pthread_mutex_lock(&shared->image_loder.lock);
		int count = un_list_count(global_path_list);
		for (int i = 0; i < count; i++) {
			if (strcmp(un_list_get(global_path_list, i), current_path) == 0) {
				shared->image_loder.image_select = i;
				last_image_select = i;
				break;
			}
		}
		pthread_mutex_unlock(&shared->image_loder.lock);

		//タイトル
		change_state(shared, "");
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
