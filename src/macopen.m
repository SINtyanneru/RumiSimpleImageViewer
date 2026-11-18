//macOS 専用: Finder の関連付け（ダブルクリックや「このアプリケーションで開く」）で
//渡されるファイルを Apple Event（kAEOpenDocuments）で受け取り、
//ドラドロと同じ dd.path_list へ流す
#import "macopen.h"

#import <Foundation/Foundation.h>
#import <pthread.h>

//Apple Event の定数（Carbon ヘッダーに依存しないよう FourCC を直接書く）
enum {
	kRsivCoreEventClass = 0x61657674, // 'aevt'
	kRsivAEOpenDocuments = 0x6F646F63, // 'odoc'
	kRsivKeyDirectObject = 0x2D2D2D2D, // '----'
	kRsivTypeFileURL = 0x6675726C // 'furl'
};

static SharedImage *g_shared_image;
static id g_handler;

@interface RsivOpenHandler : NSObject
- (void)handleOpenDocuments:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)reply;
@end

@implementation RsivOpenHandler
- (void)handleOpenDocuments:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)reply {
	NSAppleEventDescriptor *docs = [event paramDescriptorForKeyword:kRsivKeyDirectObject];
	NSInteger count = [docs numberOfItems];

	pthread_mutex_lock(&g_shared_image->dd.lock);
	for (NSInteger i = 1; i <= count; i++) {
		NSAppleEventDescriptor *item = [docs descriptorAtIndex:i];
		NSString *url_string = [[item coerceToDescriptorType:kRsivTypeFileURL] stringValue];
		if (url_string == nil)
			continue;
		NSString *path = [[NSURL URLWithString:url_string] path];
		if (path == nil)
			continue;
		un_list_add(g_shared_image->dd.path_list, [path UTF8String]);
	}
	pthread_mutex_unlock(&g_shared_image->dd.lock);
}
@end

void rsiv_mac_install_open_handler(SharedImage *shared_image) {
	g_shared_image = shared_image;
	g_handler = [[RsivOpenHandler alloc] init];
	[[NSAppleEventManager sharedAppleEventManager] setEventHandler:g_handler andSelector:@selector(handleOpenDocuments:withReplyEvent:) forEventClass:kRsivCoreEventClass andEventID:kRsivAEOpenDocuments];
}
