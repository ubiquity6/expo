/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <UIKit/UIKit.h>

#import "ABI29_0_0RCTAnimatedNode.h"

@class ABI29_0_0RCTValueAnimatedNode;

@protocol ABI29_0_0RCTValueAnimatedNodeObserver <NSObject>

- (void)animatedNode:(ABI29_0_0RCTValueAnimatedNode *)node didUpdateValue:(CGFloat)value;

@end

@interface ABI29_0_0RCTValueAnimatedNode : ABI29_0_0RCTAnimatedNode

- (void)setOffset:(CGFloat)offset;
- (void)flattenOffset;
- (void)extractOffset;

@property (nonatomic, assign) CGFloat value;
@property (nonatomic, weak) id<ABI29_0_0RCTValueAnimatedNodeObserver> valueObserver;

@end
