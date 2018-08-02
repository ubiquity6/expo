/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <ReactABI29_0_0/ABI29_0_0RCTRootView.h>

@class ABI29_0_0RCTTVRemoteHandler;

/**
 * The interface provides a set of functions that allow other internal framework
 * classes to change the ABI29_0_0RCTRootViews's internal state.
 */
@interface ABI29_0_0RCTRootView ()

/**
 * This setter should be used only by ABI29_0_0RCTUIManager on ReactABI29_0_0 root view
 * intrinsic content size update.
 */
@property (readwrite, nonatomic, assign) CGSize intrinsicContentSize;

/**
 * TV remote gesture recognizers
 */
#if TARGET_OS_TV
@property (nonatomic, strong) ABI29_0_0RCTTVRemoteHandler *tvRemoteHandler;
@property (nonatomic, strong) UIView *ReactABI29_0_0PreferredFocusedView;
#endif

- (void)contentViewInvalidated;

@end
