/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ABI26_0_0RCTVirtualTextShadowView.h"

#import <ReactABI26_0_0/ABI26_0_0RCTShadowView+Layout.h>
#import <YogaABI26_0_0/ABI26_0_0Yoga.h>

#import "ABI26_0_0RCTRawTextShadowView.h"

@implementation ABI26_0_0RCTVirtualTextShadowView {
  BOOL _isLayoutDirty;
}

#pragma mark - Life Cycle

- (void)insertReactABI26_0_0Subview:(ABI26_0_0RCTShadowView *)subview atIndex:(NSInteger)index
{
  [super insertReactABI26_0_0Subview:subview atIndex:index];

  [self dirtyLayout];

  if (![subview isKindOfClass:[ABI26_0_0RCTVirtualTextShadowView class]]) {
    ABI26_0_0YGNodeSetDirtiedFunc(subview.yogaNode, ABI26_0_0RCTVirtualTextShadowViewYogaNodeDirtied);
  }

}

- (void)removeReactABI26_0_0Subview:(ABI26_0_0RCTShadowView *)subview
{
  if (![subview isKindOfClass:[ABI26_0_0RCTVirtualTextShadowView class]]) {
    ABI26_0_0YGNodeSetDirtiedFunc(subview.yogaNode, NULL);
  }

  [self dirtyLayout];

  [super removeReactABI26_0_0Subview:subview];
}

#pragma mark - Layout

- (void)dirtyLayout
{
  [super dirtyLayout];

  if (_isLayoutDirty) {
    return;
  }
  _isLayoutDirty = YES;

  [self.superview dirtyLayout];
}

- (void)clearLayout
{
  _isLayoutDirty = NO;
}

static void ABI26_0_0RCTVirtualTextShadowViewYogaNodeDirtied(ABI26_0_0YGNodeRef node)
{
  ABI26_0_0RCTShadowView *shadowView = (__bridge ABI26_0_0RCTShadowView *)ABI26_0_0YGNodeGetContext(node);

  ABI26_0_0RCTVirtualTextShadowView *virtualTextShadowView =
    (ABI26_0_0RCTVirtualTextShadowView *)shadowView.ReactABI26_0_0Superview;

  [virtualTextShadowView dirtyLayout];
}

@end
