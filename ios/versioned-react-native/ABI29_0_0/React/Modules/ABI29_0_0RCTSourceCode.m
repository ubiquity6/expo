/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "ABI29_0_0RCTSourceCode.h"

#import "ABI29_0_0RCTBridge.h"

@implementation ABI29_0_0RCTSourceCode

ABI29_0_0RCT_EXPORT_MODULE()

@synthesize bridge = _bridge;

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

- (NSDictionary<NSString *, id> *)constantsToExport
{
  return @{
    @"scriptURL": self.bridge.bundleURL.absoluteString ?: @"",
  };
}

@end
