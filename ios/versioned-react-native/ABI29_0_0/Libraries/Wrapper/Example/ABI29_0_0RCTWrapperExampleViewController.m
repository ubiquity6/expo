// Copyright (c) 2004-present, Facebook, Inc.
//
// This source code is licensed under the license found in the
// LICENSE-examples file in the root directory of this source tree.

#import "ABI29_0_0RCTWrapperExampleViewController.h"

#import <ABI29_0_0RCTWrapper/ABI29_0_0RCTWrapper.h>

#import "ABI29_0_0RCTWrapperExampleView.h"

@implementation ABI29_0_0RCTWrapperExampleViewController

- (void)loadView {
  self.view = [ABI29_0_0RCTWrapperExampleView new];
}

@end

ABI29_0_0RCT_WRAPPER_FOR_VIEW_CONTROLLER(ABI29_0_0RCTWrapperExampleViewController)
