/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <QuartzCore/QuartzCore.h>

#import "ABI29_0_0RCTPerformanceLogger.h"
#import "ABI29_0_0RCTRootView.h"
#import "ABI29_0_0RCTLog.h"
#import "ABI29_0_0RCTProfile.h"

@interface ABI29_0_0RCTPerformanceLogger ()
{
  int64_t _data[ABI29_0_0RCTPLSize][2];
  NSUInteger _cookies[ABI29_0_0RCTPLSize];
}

@property (nonatomic, copy) NSArray<NSString *> *labelsForTags;

@end

@implementation ABI29_0_0RCTPerformanceLogger

- (instancetype)init
{
  if (self = [super init]) {
    _labelsForTags = @[
      @"ScriptDownload",
      @"ScriptExecution",
      @"RAMBundleLoad",
      @"RAMStartupCodeSize",
      @"RAMStartupNativeRequires",
      @"RAMStartupNativeRequiresCount",
      @"RAMNativeRequires",
      @"RAMNativeRequiresCount",
      @"NativeModuleInit",
      @"NativeModuleMainThread",
      @"NativeModulePrepareConfig",
      @"NativeModuleInjectConfig",
      @"NativeModuleMainThreadUsesCount",
      @"JSCWrapperOpenLibrary",
      @"JSCExecutorSetup",
      @"BridgeStartup",
      @"RootViewTTI",
      @"BundleSize",
    ];
  }
  return self;
}

- (void)markStartForTag:(ABI29_0_0RCTPLTag)tag
{
#if ABI29_0_0RCT_PROFILE
  if (ABI29_0_0RCTProfileIsProfiling()) {
    NSString *label = _labelsForTags[tag];
    _cookies[tag] = ABI29_0_0RCTProfileBeginAsyncEvent(ABI29_0_0RCTProfileTagAlways, label, nil);
  }
#endif
  _data[tag][0] = CACurrentMediaTime() * 1000;
  _data[tag][1] = 0;
}


- (void)markStopForTag:(ABI29_0_0RCTPLTag)tag
{
#if ABI29_0_0RCT_PROFILE
  if (ABI29_0_0RCTProfileIsProfiling()) {
    NSString *label =_labelsForTags[tag];
    ABI29_0_0RCTProfileEndAsyncEvent(ABI29_0_0RCTProfileTagAlways, @"native", _cookies[tag], label, @"ABI29_0_0RCTPerformanceLogger");
  }
#endif
  if (_data[tag][0] != 0 && _data[tag][1] == 0) {
    _data[tag][1] = CACurrentMediaTime() * 1000;
  } else {
    ABI29_0_0RCTLogInfo(@"Unbalanced calls start/end for tag %li", (unsigned long)tag);
  }
}

- (void)setValue:(int64_t)value forTag:(ABI29_0_0RCTPLTag)tag
{
  _data[tag][0] = 0;
  _data[tag][1] = value;
}

- (void)addValue:(int64_t)value forTag:(ABI29_0_0RCTPLTag)tag
{
  _data[tag][0] = 0;
  _data[tag][1] += value;
}

- (void)appendStartForTag:(ABI29_0_0RCTPLTag)tag
{
  _data[tag][0] = CACurrentMediaTime() * 1000;
}

- (void)appendStopForTag:(ABI29_0_0RCTPLTag)tag
{
  if (_data[tag][0] != 0) {
    _data[tag][1] += CACurrentMediaTime() * 1000 - _data[tag][0];
    _data[tag][0] = 0;
  } else {
    ABI29_0_0RCTLogInfo(@"Unbalanced calls start/end for tag %li", (unsigned long)tag);
  }
}

- (NSArray<NSNumber *> *)valuesForTags
{
  NSMutableArray *result = [NSMutableArray array];
  for (NSUInteger index = 0; index < ABI29_0_0RCTPLSize; index++) {
    [result addObject:@(_data[index][0])];
    [result addObject:@(_data[index][1])];
  }
  return result;
}

- (int64_t)durationForTag:(ABI29_0_0RCTPLTag)tag
{
  return _data[tag][1] - _data[tag][0];
}

- (int64_t)valueForTag:(ABI29_0_0RCTPLTag)tag
{
  return _data[tag][1];
}

@end
