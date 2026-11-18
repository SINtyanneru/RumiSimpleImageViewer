//UnFoundation の実装（Linux / macOS 用）
//本物の Foundation を C の API で包むだけ
#import "UnFoundation.h"

#import <Foundation/Foundation.h>
#import <stdlib.h>

int rsiv_argc = 0;
char **rsiv_argv = NULL;

struct UnStringList {
	NSMutableArray *array;
};

UnStringList *un_list_create(void) {
	UnStringList *list = malloc(sizeof(UnStringList));
	list->array = [[NSMutableArray alloc] init];
	return list;
}

void un_list_add(UnStringList *list, const char *text) {
	[list->array addObject:[NSString stringWithUTF8String:text]];
}

int un_list_count(UnStringList *list) {
	return (int)[list->array count];
}

const char *un_list_get(UnStringList *list, int index) {
	return [[list->array objectAtIndex:(NSUInteger)index] UTF8String];
}

void un_list_clear(UnStringList *list) {
	[list->array removeAllObjects];
}

int un_arg_count(void) {
	return (int)[[[NSProcessInfo processInfo] arguments] count];
}

const char *un_arg_get(int index) {
	return [[[[NSProcessInfo processInfo] arguments] objectAtIndex:(NSUInteger)index] UTF8String];
}
