//UnFoundation の実装（Linux / macOS 以外用、純粋な C）
#import <stdlib.h>
#import <string.h>

#ifdef _WIN32
#import <windows.h>
#import <shellapi.h>
#endif

#import "UnFoundation.h"

int rsiv_argc = 0;
char **rsiv_argv = NULL;

static char *dup_text(const char *text) {
	size_t len = strlen(text) + 1;
	char *copy = malloc(len);
	memcpy(copy, text, len);
	return copy;
}

struct UnStringList {
	char **items;
	int count;
	int capacity;
};

UnStringList *un_list_create(void) {
	UnStringList *list = malloc(sizeof(UnStringList));
	list->items = NULL;
	list->count = 0;
	list->capacity = 0;
	return list;
}

void un_list_add(UnStringList *list, const char *text) {
	if (list->count >= list->capacity) {
		if (list->capacity == 0)
			list->capacity = 8;
		else
			list->capacity *= 2;
		list->items = realloc(list->items, sizeof(char *) * (size_t)list->capacity);
	}
	list->items[list->count] = dup_text(text);
	list->count++;
}

int un_list_count(UnStringList *list) {
	return list->count;
}

const char *un_list_get(UnStringList *list, int index) {
	if (index < 0 || index >= list->count)
		return "";
	return list->items[index];
}

void un_list_clear(UnStringList *list) {
	list->count = 0;
}

static int un_cmp_text(const void *a, const void *b) {
	return strcmp(*(const char **)a, *(const char **)b);
}

void un_list_sort(UnStringList *list) {
	if (list->count < 2)
		return;
	qsort(list->items, (size_t)list->count, sizeof(char *), un_cmp_text);
}


#ifdef _WIN32

static char **win_args = NULL;
static int win_argc = 0;

static void build_win_args(void) {
	if (win_args != NULL)
		return;

	//argv は ANSI コードページで来るので、ワイド文字経由で UTF-8 にして取り込む
	int argc = 0;
	wchar_t **argv = CommandLineToArgvW(GetCommandLineW(), &argc);

	win_args = malloc(sizeof(char *) * (size_t)argc);
	win_argc = argc;

	for (int i = 0; i < argc; i++) {
		int len = WideCharToMultiByte(CP_UTF8, 0, argv[i], -1, NULL, 0, NULL, NULL);
		char *buf = malloc((size_t)len);
		WideCharToMultiByte(CP_UTF8, 0, argv[i], -1, buf, len, NULL, NULL);
		win_args[i] = buf;
	}

	if (argv != NULL)
		LocalFree(argv);
}

#endif

int un_arg_count(void) {
#ifdef _WIN32
	build_win_args();
	return win_argc;
#else
	return rsiv_argc;
#endif
}

const char *un_arg_get(int index) {
#ifdef _WIN32
	build_win_args();
	if (index < 0 || index >= win_argc)
		return "";
	return win_args[index];
#else
	if (index < 0 || index >= rsiv_argc)
		return "";
	return rsiv_argv[index];
#endif
}
