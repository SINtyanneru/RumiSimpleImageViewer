#import "UnFoundation.h"

#import <stdlib.h>
#import <string.h>
#import <objc/runtime.h>

#ifdef _WIN32
#import <windows.h>
#import <shellapi.h>
#endif

int rsiv_argc = 0;
char **rsiv_argv = NULL;

//@autoreleasepool はこの2関数を呼ぶ。GCCランタイムには無いので自前で用意する（何もしない）
void *objc_autoreleasePoolPush(void) {
	return NULL;
}

void objc_autoreleasePoolPop(void *pool) {
	(void)pool;
}

@implementation NSObject

+ (id)alloc {
	return class_createInstance(self, 0);
}

- (id)init {
	return self;
}

- (id)retain {
	return self;
}

- (void)release {
}

- (id)autorelease {
	return self;
}

- (void)dealloc {
	object_dispose(self);
}

@end

@implementation NSString

+ (NSString *)stringWithUTF8String:(const char *)text {
	return [[NSString alloc] initWithUTF8String:text];
}

- (NSString *)initWithUTF8String:(const char *)text {
	if (text == NULL)
		text = "";
	_length = (unsigned int)strlen(text);
	_bytes = malloc(_length + 1);
	memcpy(_bytes, text, _length + 1);
	return self;
}

- (const char *)UTF8String {
	return _bytes;
}

- (NSUInteger)length {
	return _length;
}

- (int)intValue {
	return atoi(_bytes);
}

- (BOOL)isEqualToString:(NSString *)other {
	if (other == nil)
		return NO;
	return strcmp(_bytes, [other UTF8String]) == 0;
}

@end

@implementation NSConstantString

//定数文字列はスタティック領域を指しているので、通常の文字列以上に触らない
- (id)retain {
	return self;
}

- (void)release {
}

- (id)autorelease {
	return self;
}

@end

@implementation NSArray

- (NSUInteger)count {
	return _count;
}

- (ObjectType)objectAtIndex:(NSUInteger)index {
	if (index >= _count)
		return nil;
	return _objects[index];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)buffer count:(NSUInteger)len {
	(void)buffer;
	(void)len;
	if (state->state != 0)
		return 0;
	state->state = 1;
	state->itemsPtr = _objects;
	state->mutationsPtr = &_mutations;
	return _count;
}

@end

@implementation NSMutableArray

- (void)addObject:(ObjectType)object {
	if (_count >= _capacity) {
		if (_capacity == 0)
			_capacity = 8;
		else
			_capacity *= 2;
		_objects = realloc(_objects, sizeof(id) * _capacity);
	}
	_objects[_count] = object;
	_count++;
	_mutations++;
}

- (void)removeAllObjects {
	_count = 0;
	_mutations++;
}

@end

@implementation NSProcessInfo

+ (NSProcessInfo *)processInfo {
	static NSProcessInfo *shared = nil;
	if (shared == nil)
		shared = [[NSProcessInfo alloc] init];
	return shared;
}

- (NSArray *)arguments {
	NSMutableArray *args = [[NSMutableArray alloc] init];
#ifdef _WIN32
	//argv は ANSI コードページで来るので、ワイド文字経由で UTF-8 にして取り込む
	int argc = 0;
	wchar_t **argv = CommandLineToArgvW(GetCommandLineW(), &argc);
	for (int i = 0; i < argc; i++) {
		int len = WideCharToMultiByte(CP_UTF8, 0, argv[i], -1, NULL, 0, NULL, NULL);
		char *buf = malloc((size_t)len);
		WideCharToMultiByte(CP_UTF8, 0, argv[i], -1, buf, len, NULL, NULL);
		[args addObject:[NSString stringWithUTF8String:buf]];
		free(buf);
	}
	if (argv != NULL)
		LocalFree(argv);
#else
	for (int i = 0; i < rsiv_argc; i++)
		[args addObject:[NSString stringWithUTF8String:rsiv_argv[i]]];
#endif
	return args;
}

@end

@implementation NSAutoreleasePool

- (void)drain {
}

@end
