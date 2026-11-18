//最小限の Foundation 互換ライブラリ（Linux / macOS 以外用）
//rsiv が使う NSString / NSArray / NSMutableArray / NSProcessInfo / NSAutoreleasePool だけを
//C 標準ライブラリで実装する。
//メモリ管理は割り切って「解放しない」方式にする（retain / release / autorelease は何もしない）。
//引数やドラッグ＆ドロップのパス程度しか扱わないので、これで足りる。
#import <objc/objc.h>
#import <stdint.h>

typedef uintptr_t NSUInteger;
typedef intptr_t NSInteger;

typedef struct {
	unsigned long state;
	id *itemsPtr;
	unsigned long *mutationsPtr;
	unsigned long extra[5];
} NSFastEnumerationState;

__attribute__((objc_root_class))
@interface NSObject {
	Class isa;
}
+ (id)alloc;
- (id)init;
- (id)retain;
- (void)release;
- (id)autorelease;
- (void)dealloc;
@end

@interface NSString : NSObject {
	char *_bytes;
	unsigned int _length;
}
+ (NSString *)stringWithUTF8String:(const char *)text;
- (NSString *)initWithUTF8String:(const char *)text;
- (const char *)UTF8String;
- (NSUInteger)length;
- (int)intValue;
- (BOOL)isEqualToString:(NSString *)other;
@end

//@"..." リテラル用のクラス。レイアウトは NSString の先頭（_bytes・_length）と一致させること
@interface NSConstantString : NSString
@end

@interface NSArray<__covariant ObjectType> : NSObject {
	id *_objects;
	NSUInteger _count;
	NSUInteger _capacity;
	unsigned long _mutations;
}
- (NSUInteger)count;
- (ObjectType)objectAtIndex:(NSUInteger)index;
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)buffer count:(NSUInteger)len;
@end

@interface NSMutableArray<__covariant ObjectType> : NSArray<ObjectType>
- (void)addObject:(ObjectType)object;
- (void)removeAllObjects;
@end

@interface NSProcessInfo : NSObject
+ (NSProcessInfo *)processInfo;
- (NSArray *)arguments;
@end

@interface NSAutoreleasePool : NSObject
- (void)drain;
@end

//main() の引数を NSProcessInfo へ渡すための受け口（Windows では GetCommandLineW を使うので未使用）
extern int rsiv_argc;
extern char **rsiv_argv;
