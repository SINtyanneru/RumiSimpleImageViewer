//UnFoundation の実装（Linux / macOS 用）
//本物の Foundation を C の API で包むだけ
#import "UnFoundation.h"

#import <Foundation/Foundation.h>
#import <stdlib.h>
#import <pthread.h>

int rsiv_argc = 0;
char **rsiv_argv = NULL;

//GNUstep はプールが無いスレッドでの autorelease に警告を出すので、
//スレッドごとに1つ、終了まで drain しないプールを用意しておく
//（un_list_get が返す文字列の寿命もこれで保証される）
static pthread_key_t un_pool_key;
static pthread_once_t un_pool_once = PTHREAD_ONCE_INIT;

static void un_make_key(void) {
	pthread_key_create(&un_pool_key, NULL);
}

static void un_ensure_pool(void) {
	pthread_once(&un_pool_once, un_make_key);
	if (pthread_getspecific(un_pool_key) == NULL) {
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		pthread_setspecific(un_pool_key, pool);
	}
}

struct UnStringList {
	NSMutableArray *array;
};

UnStringList *un_list_create(void) {
	un_ensure_pool();
	UnStringList *list = malloc(sizeof(UnStringList));
	list->array = [[NSMutableArray alloc] init];
	return list;
}

void un_list_add(UnStringList *list, const char *text) {
	un_ensure_pool();
	[list->array addObject:[NSString stringWithUTF8String:text]];
}

int un_list_count(UnStringList *list) {
	un_ensure_pool();
	return (int)[list->array count];
}

const char *un_list_get(UnStringList *list, int index) {
	un_ensure_pool();
	return [[list->array objectAtIndex:(NSUInteger)index] UTF8String];
}

void un_list_clear(UnStringList *list) {
	un_ensure_pool();
	[list->array removeAllObjects];
}

int un_arg_count(void) {
	un_ensure_pool();
	return (int)[[[NSProcessInfo processInfo] arguments] count];
}

const char *un_arg_get(int index) {
	un_ensure_pool();
	return [[[[NSProcessInfo processInfo] arguments] objectAtIndex:(NSUInteger)index] UTF8String];
}
