//macOS 専用: Finder の関連付け（ダブルクリックや「このアプリケーションで開く」）で
//渡されるファイルを Apple Event（kAEOpenDocuments）で受け取り、
//ドラドロと同じ dd.path_list へ流す
#import "macopen.h"

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <pthread.h>
#import <stdio.h>

//Apple Event の定数（Carbon ヘッダーに依存しないよう FourCC を直接書く）
enum {
	kRsivCoreEventClass = 0x61657674, // 'aevt'
	kRsivAEOpenDocuments = 0x6F646F63, // 'odoc'
	kRsivKeyDirectObject = 0x2D2D2D2D, // '----'
	kRsivTypeFileURL = 0x6675726C, // 'furl'
	kRsivTypeAEList = 0x6C697374 // 'list'
};

static SharedImage *g_shared_image;
static id g_handler;

@interface RsivOpenHandler : NSObject
- (void)registerHandler;
- (void)appDidFinishLaunching:(NSNotification *)note;
- (void)handleOpenDocuments:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)reply;
@end

@implementation RsivOpenHandler
- (void)registerHandler {
	[[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(handleOpenDocuments:withReplyEvent:) forEventClass:kRsivCoreEventClass andEventID:kRsivAEOpenDocuments];
	fprintf(stderr, "[macopen] handler registered\n");
}

- (void)appDidFinishLaunching:(NSNotification *)note {
	//AppKit 自身のハンドラ登録が終わった後に登録し直す（先に登録すると上書きされる）
	[self registerHandler];
}

- (void)handleOpenDocuments:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)reply {
	NSAppleEventDescriptor *docs = [event paramDescriptorForKeyword:kRsivKeyDirectObject];
	fprintf(stderr, "[macopen] open documents event (type=%08x, items=%ld)\n", (unsigned int)[docs descriptorType], (long)[docs numberOfItems]);

	//複数ファイルのときはリスト、1ファイルのときは単体の記述子で来ることがある
	NSAppleEventDescriptor *items[64];
	NSInteger count = 0;
	if (docs != nil && [docs descriptorType] == kRsivTypeAEList) {
		NSInteger n = [docs numberOfItems];
		for (NSInteger i = 1; i <= n && count < 64; i++)
			items[count++] = [docs descriptorAtIndex:i];
	} else if (docs != nil) {
		items[count++] = docs;
	}

	pthread_mutex_lock(&g_shared_image->dd.lock);
	for (NSInteger i = 0; i < count; i++) {
		NSString *url_string = [[items[i] coerceToDescriptorType:kRsivTypeFileURL] stringValue];
		if (url_string == nil)
			continue;
		NSString *path = [[NSURL URLWithString:url_string] path];
		if (path == nil)
			continue;
		fprintf(stderr, "[macopen] open: %s\n", [path UTF8String]);
		un_list_add(g_shared_image->dd.path_list, [path UTF8String]);
	}
	pthread_mutex_unlock(&g_shared_image->dd.lock);
}
@end

void rsiv_mac_install_open_handler(SharedImage *shared_image) {
	g_shared_image = shared_image;
	g_handler = [[RsivOpenHandler alloc] init];
	[g_handler registerHandler];
	//起動完了の通知でも登録し直す（AppKit の登録タイミングが後でも上書きされないように）
	[[NSNotificationCenter defaultCenter] addObserver:g_handler selector:@selector(appDidFinishLaunching:) name:NSApplicationDidFinishLaunchingNotification object:nil];
}
