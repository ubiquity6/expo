/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <UIKit/UIKit.h>

@class ABI29_0_0RCTBridge;
@class ABI29_0_0RCTInputAccessoryViewContent;

@interface ABI29_0_0RCTInputAccessoryView : UIView

- (instancetype)initWithBridge:(ABI29_0_0RCTBridge *)bridge;

@property (nonatomic, readonly, strong) ABI29_0_0RCTInputAccessoryViewContent *content;

@end
