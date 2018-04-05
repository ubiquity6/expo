// Copyright 2004-present Facebook. All Rights Reserved.

#import <Foundation/Foundation.h>
#import <ReactABI26_0_0/ABI26_0_0RCTDefines.h>

#if ABI26_0_0RCT_DEV

@interface ABI26_0_0RCTBundleStatus : NSObject
@property (atomic, assign) BOOL isLastBundleDownloadSuccess;
@property (atomic, assign) NSTimeInterval bundleUpdateTimestamp;
@end

typedef ABI26_0_0RCTBundleStatus *(^ABI26_0_0RCTBundleStatusProvider)(void);

@interface ABI26_0_0RCTInspectorPackagerConnection : NSObject
- (instancetype)initWithURL:(NSURL *)url;

- (void)connect;
- (void)closeQuietly;
- (void)sendEventToAllConnections:(NSString *)event;
- (void)setBundleStatusProvider:(ABI26_0_0RCTBundleStatusProvider)bundleStatusProvider;
@end

@interface ABI26_0_0RCTInspectorRemoteConnection : NSObject
- (void)onMessage:(NSString *)message;
- (void)onDisconnect;
@end

#endif
