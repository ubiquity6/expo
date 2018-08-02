/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "ABI29_0_0RCTUIManager.h"

#import <AVFoundation/AVFoundation.h>

#import "ABI29_0_0RCTAccessibilityManager.h"
#import "ABI29_0_0RCTAssert.h"
#import "ABI29_0_0RCTBridge+Private.h"
#import "ABI29_0_0RCTBridge.h"
#import "ABI29_0_0RCTComponent.h"
#import "ABI29_0_0RCTComponentData.h"
#import "ABI29_0_0RCTConvert.h"
#import "ABI29_0_0RCTDefines.h"
#import "ABI29_0_0RCTEventDispatcher.h"
#import "ABI29_0_0RCTLayoutAnimation.h"
#import "ABI29_0_0RCTLayoutAnimationGroup.h"
#import "ABI29_0_0RCTLog.h"
#import "ABI29_0_0RCTModuleData.h"
#import "ABI29_0_0RCTModuleMethod.h"
#import "ABI29_0_0RCTProfile.h"
#import "ABI29_0_0RCTRootContentView.h"
#import "ABI29_0_0RCTRootShadowView.h"
#import "ABI29_0_0RCTRootViewInternal.h"
#import "ABI29_0_0RCTScrollableProtocol.h"
#import "ABI29_0_0RCTShadowView+Internal.h"
#import "ABI29_0_0RCTShadowView.h"
#import "ABI29_0_0RCTSurfaceRootShadowView.h"
#import "ABI29_0_0RCTSurfaceRootView.h"
#import "ABI29_0_0RCTUIManagerObserverCoordinator.h"
#import "ABI29_0_0RCTUIManagerUtils.h"
#import "ABI29_0_0RCTUtils.h"
#import "ABI29_0_0RCTView.h"
#import "ABI29_0_0RCTViewManager.h"
#import "UIView+ReactABI29_0_0.h"

static void ABI29_0_0RCTTraverseViewNodes(id<ABI29_0_0RCTComponent> view, void (^block)(id<ABI29_0_0RCTComponent>))
{
  if (view.ReactABI29_0_0Tag) {
    block(view);

    for (id<ABI29_0_0RCTComponent> subview in view.ReactABI29_0_0Subviews) {
      ABI29_0_0RCTTraverseViewNodes(subview, block);
    }
  }
}

NSString *const ABI29_0_0RCTUIManagerWillUpdateViewsDueToContentSizeMultiplierChangeNotification = @"ABI29_0_0RCTUIManagerWillUpdateViewsDueToContentSizeMultiplierChangeNotification";

@implementation ABI29_0_0RCTUIManager
{
  // Root views are only mutated on the shadow queue
  NSMutableSet<NSNumber *> *_rootViewTags;
  NSMutableArray<ABI29_0_0RCTViewManagerUIBlock> *_pendingUIBlocks;

  // Animation
  ABI29_0_0RCTLayoutAnimationGroup *_layoutAnimationGroup; // Main thread only

  NSMutableDictionary<NSNumber *, ABI29_0_0RCTShadowView *> *_shadowViewRegistry; // ABI29_0_0RCT thread only
  NSMutableDictionary<NSNumber *, UIView *> *_viewRegistry; // Main thread only

  NSMapTable<ABI29_0_0RCTShadowView *, NSArray<NSString *> *> *_shadowViewsWithUpdatedProps; // UIManager queue only.
  NSHashTable<ABI29_0_0RCTShadowView *> *_shadowViewsWithUpdatedChildren; // UIManager queue only.

  // Keyed by viewName
  NSDictionary *_componentDataByName;
}

@synthesize bridge = _bridge;

ABI29_0_0RCT_EXPORT_MODULE()

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

- (void)dealloc
{
  [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)invalidate
{
  /**
   * Called on the JS Thread since all modules are invalidated on the JS thread
   */

  // This only accessed from the shadow queue
  _pendingUIBlocks = nil;

  ABI29_0_0RCTExecuteOnMainQueue(^{
    ABI29_0_0RCT_PROFILE_BEGIN_EVENT(ABI29_0_0RCTProfileTagAlways, @"UIManager invalidate", nil);
    for (NSNumber *rootViewTag in self->_rootViewTags) {
      UIView *rootView = self->_viewRegistry[rootViewTag];
      if ([rootView conformsToProtocol:@protocol(ABI29_0_0RCTInvalidating)]) {
        [(id<ABI29_0_0RCTInvalidating>)rootView invalidate];
      }
    }

    self->_rootViewTags = nil;
    self->_shadowViewRegistry = nil;
    self->_viewRegistry = nil;
    self->_bridge = nil;

    [[NSNotificationCenter defaultCenter] removeObserver:self];
    ABI29_0_0RCT_PROFILE_END_EVENT(ABI29_0_0RCTProfileTagAlways, @"");
  });
}

- (NSMutableDictionary<NSNumber *, ABI29_0_0RCTShadowView *> *)shadowViewRegistry
{
  // NOTE: this method only exists so that it can be accessed by unit tests
  if (!_shadowViewRegistry) {
    _shadowViewRegistry = [NSMutableDictionary new];
  }
  return _shadowViewRegistry;
}

- (NSMutableDictionary<NSNumber *, UIView *> *)viewRegistry
{
  // NOTE: this method only exists so that it can be accessed by unit tests
  if (!_viewRegistry) {
    _viewRegistry = [NSMutableDictionary new];
  }
  return _viewRegistry;
}

- (void)setBridge:(ABI29_0_0RCTBridge *)bridge
{
  ABI29_0_0RCTAssert(_bridge == nil, @"Should not re-use same UIIManager instance");
  _bridge = bridge;

  _shadowViewRegistry = [NSMutableDictionary new];
  _viewRegistry = [NSMutableDictionary new];

  _shadowViewsWithUpdatedProps = [NSMapTable weakToStrongObjectsMapTable];
  _shadowViewsWithUpdatedChildren = [NSHashTable weakObjectsHashTable];

  // Internal resources
  _pendingUIBlocks = [NSMutableArray new];
  _rootViewTags = [NSMutableSet new];

  _observerCoordinator = [ABI29_0_0RCTUIManagerObserverCoordinator new];

  // Get view managers from bridge
  NSMutableDictionary *componentDataByName = [NSMutableDictionary new];
  for (Class moduleClass in _bridge.moduleClasses) {
    if ([moduleClass isSubclassOfClass:[ABI29_0_0RCTViewManager class]]) {
      ABI29_0_0RCTComponentData *componentData = [[ABI29_0_0RCTComponentData alloc] initWithManagerClass:moduleClass
                                                                                bridge:_bridge];
      componentDataByName[componentData.name] = componentData;
    }
  }

  _componentDataByName = [componentDataByName copy];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(didReceiveNewContentSizeMultiplier)
                                               name:ABI29_0_0RCTAccessibilityManagerDidUpdateMultiplierNotification
                                             object:_bridge.accessibilityManager];
#if !TARGET_OS_TV
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(namedOrientationDidChange)
                                               name:UIDeviceOrientationDidChangeNotification
                                             object:nil];
#endif
  [ABI29_0_0RCTLayoutAnimation initializeStatics];
}

#pragma mark - Event emitting

- (void)didReceiveNewContentSizeMultiplier
{
  // Report the event across the bridge.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  [_bridge.eventDispatcher sendDeviceEventWithName:@"didUpdateContentSizeMultiplier"
                                              body:@([_bridge.accessibilityManager multiplier])];
#pragma clang diagnostic pop

  ABI29_0_0RCTExecuteOnUIManagerQueue(^{
    [[NSNotificationCenter defaultCenter] postNotificationName:ABI29_0_0RCTUIManagerWillUpdateViewsDueToContentSizeMultiplierChangeNotification
                                                        object:self];
    [self setNeedsLayout];
  });
}

#if !TARGET_OS_TV
// Names and coordinate system from html5 spec:
// https://developer.mozilla.org/en-US/docs/Web/API/Screen.orientation
// https://developer.mozilla.org/en-US/docs/Web/API/Screen.lockOrientation
static NSDictionary *deviceOrientationEventBody(UIDeviceOrientation orientation)
{
  NSString *name;
  NSNumber *degrees = @0;
  BOOL isLandscape = NO;
  switch(orientation) {
    case UIDeviceOrientationPortrait:
      name = @"portrait-primary";
      break;
    case UIDeviceOrientationPortraitUpsideDown:
      name = @"portrait-secondary";
      degrees = @180;
      break;
    case UIDeviceOrientationLandscapeRight:
      name = @"landscape-primary";
      degrees = @-90;
      isLandscape = YES;
      break;
    case UIDeviceOrientationLandscapeLeft:
      name = @"landscape-secondary";
      degrees = @90;
      isLandscape = YES;
      break;
    case UIDeviceOrientationFaceDown:
    case UIDeviceOrientationFaceUp:
    case UIDeviceOrientationUnknown:
      // Unsupported
      return nil;
  }
  return @{
    @"name": name,
    @"rotationDegrees": degrees,
    @"isLandscape": @(isLandscape),
  };
}

- (void)namedOrientationDidChange
{
  NSDictionary *orientationEvent = deviceOrientationEventBody([UIDevice currentDevice].orientation);
  if (!orientationEvent) {
    return;
  }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  [_bridge.eventDispatcher sendDeviceEventWithName:@"namedOrientationDidChange"
                                              body:orientationEvent];
#pragma clang diagnostic pop
}
#endif

- (dispatch_queue_t)methodQueue
{
  return ABI29_0_0RCTGetUIManagerQueue();
}

- (void)registerRootViewTag:(NSNumber *)rootTag
{
  ABI29_0_0RCTAssertUIManagerQueue();

  ABI29_0_0RCTAssert(ABI29_0_0RCTIsReactABI29_0_0RootView(rootTag),
    @"Attempt to register rootTag (%@) which is not actually root tag.", rootTag);

  ABI29_0_0RCTAssert(![_rootViewTags containsObject:rootTag],
    @"Attempt to register rootTag (%@) which was already registred.", rootTag);

  [_rootViewTags addObject:rootTag];

  // Registering root shadow view
  ABI29_0_0RCTSurfaceRootShadowView *shadowView = [ABI29_0_0RCTSurfaceRootShadowView new];
  shadowView.ReactABI29_0_0Tag = rootTag;
  _shadowViewRegistry[rootTag] = shadowView;

  // Registering root view
  ABI29_0_0RCTExecuteOnMainQueue(^{
    ABI29_0_0RCTSurfaceRootView *rootView = [ABI29_0_0RCTSurfaceRootView new];
    rootView.ReactABI29_0_0Tag = rootTag;
    self->_viewRegistry[rootTag] = rootView;
  });
}

- (void)registerRootView:(ABI29_0_0RCTRootContentView *)rootView
{
  ABI29_0_0RCTAssertMainQueue();

  NSNumber *ReactABI29_0_0Tag = rootView.ReactABI29_0_0Tag;
  ABI29_0_0RCTAssert(ABI29_0_0RCTIsReactABI29_0_0RootView(ReactABI29_0_0Tag),
            @"View %@ with tag #%@ is not a root view", rootView, ReactABI29_0_0Tag);

  UIView *existingView = _viewRegistry[ReactABI29_0_0Tag];
  ABI29_0_0RCTAssert(existingView == nil || existingView == rootView,
            @"Expect all root views to have unique tag. Added %@ twice", ReactABI29_0_0Tag);

  CGSize availableSize = rootView.availableSize;

  // Register view
  _viewRegistry[ReactABI29_0_0Tag] = rootView;

  // Register shadow view
  ABI29_0_0RCTExecuteOnUIManagerQueue(^{
    if (!self->_viewRegistry) {
      return;
    }

    ABI29_0_0RCTRootShadowView *shadowView = [ABI29_0_0RCTRootShadowView new];
    shadowView.availableSize = availableSize;
    shadowView.ReactABI29_0_0Tag = ReactABI29_0_0Tag;
    shadowView.viewName = NSStringFromClass([rootView class]);
    self->_shadowViewRegistry[shadowView.ReactABI29_0_0Tag] = shadowView;
    [self->_rootViewTags addObject:ReactABI29_0_0Tag];
  });
}

- (NSString *)viewNameForReactABI29_0_0Tag:(NSNumber *)ReactABI29_0_0Tag
{
  ABI29_0_0RCTAssertUIManagerQueue();
  return _shadowViewRegistry[ReactABI29_0_0Tag].viewName;
}

- (UIView *)viewForReactABI29_0_0Tag:(NSNumber *)ReactABI29_0_0Tag
{
  ABI29_0_0RCTAssertMainQueue();
  return _viewRegistry[ReactABI29_0_0Tag];
}

- (ABI29_0_0RCTShadowView *)shadowViewForReactABI29_0_0Tag:(NSNumber *)ReactABI29_0_0Tag
{
  ABI29_0_0RCTAssertUIManagerQueue();
  return _shadowViewRegistry[ReactABI29_0_0Tag];
}

- (void)_executeBlockWithShadowView:(void (^)(ABI29_0_0RCTShadowView *shadowView))block forTag:(NSNumber *)tag
{
  ABI29_0_0RCTAssertMainQueue();

  ABI29_0_0RCTExecuteOnUIManagerQueue(^{
    ABI29_0_0RCTShadowView *shadowView = self->_shadowViewRegistry[tag];

    if (shadowView == nil) {
      ABI29_0_0RCTLogInfo(@"Could not locate shadow view with tag #%@, this is probably caused by a temporary inconsistency between native views and shadow views.", tag);
      return;
    }

    block(shadowView);
  });
}

- (void)setAvailableSize:(CGSize)availableSize forRootView:(UIView *)rootView
{
  ABI29_0_0RCTAssertMainQueue();
  [self _executeBlockWithShadowView:^(ABI29_0_0RCTShadowView *shadowView) {
    ABI29_0_0RCTAssert([shadowView isKindOfClass:[ABI29_0_0RCTRootShadowView class]], @"Located shadow view is actually not root view.");

    ABI29_0_0RCTRootShadowView *rootShadowView = (ABI29_0_0RCTRootShadowView *)shadowView;

    if (CGSizeEqualToSize(availableSize, rootShadowView.availableSize)) {
      return;
    }

    rootShadowView.availableSize = availableSize;
    [self setNeedsLayout];
  } forTag:rootView.ReactABI29_0_0Tag];
}

- (void)setLocalData:(NSObject *)localData forView:(UIView *)view
{
  ABI29_0_0RCTAssertMainQueue();
  [self _executeBlockWithShadowView:^(ABI29_0_0RCTShadowView *shadowView) {
    shadowView.localData = localData;
    [self setNeedsLayout];
  } forTag:view.ReactABI29_0_0Tag];
}

/**
 * TODO(yuwang): implement the nativeID functionality in a more efficient way
 *               instead of searching the whole view tree
 */
- (UIView *)viewForNativeID:(NSString *)nativeID withRootTag:(NSNumber *)rootTag
{
  ABI29_0_0RCTAssertMainQueue();
  UIView *view = [self viewForReactABI29_0_0Tag:rootTag];
  return [self _lookupViewForNativeID:nativeID inView:view];
}

- (UIView *)_lookupViewForNativeID:(NSString *)nativeID inView:(UIView *)view
{
  ABI29_0_0RCTAssertMainQueue();
  if (view != nil && [nativeID isEqualToString:view.nativeID]) {
    return view;
  }

  for (UIView *subview in view.subviews) {
    UIView *targetView = [self _lookupViewForNativeID:nativeID inView:subview];
    if (targetView != nil) {
      return targetView;
    }
  }
  return nil;
}

- (void)setSize:(CGSize)size forView:(UIView *)view
{
  ABI29_0_0RCTAssertMainQueue();
  [self _executeBlockWithShadowView:^(ABI29_0_0RCTShadowView *shadowView) {
    if (CGSizeEqualToSize(size, shadowView.size)) {
      return;
    }

    shadowView.size = size;
    [self setNeedsLayout];
  } forTag:view.ReactABI29_0_0Tag];
}

- (void)setIntrinsicContentSize:(CGSize)intrinsicContentSize forView:(UIView *)view
{
  ABI29_0_0RCTAssertMainQueue();
  [self _executeBlockWithShadowView:^(ABI29_0_0RCTShadowView *shadowView) {
    if (CGSizeEqualToSize(shadowView.intrinsicContentSize, intrinsicContentSize)) {
      return;
    }

    shadowView.intrinsicContentSize = intrinsicContentSize;
    [self setNeedsLayout];
  } forTag:view.ReactABI29_0_0Tag];
}

/**
 * Unregisters views from registries
 */
- (void)_purgeChildren:(NSArray<id<ABI29_0_0RCTComponent>> *)children
          fromRegistry:(NSMutableDictionary<NSNumber *, id<ABI29_0_0RCTComponent>> *)registry
{
  for (id<ABI29_0_0RCTComponent> child in children) {
    ABI29_0_0RCTTraverseViewNodes(registry[child.ReactABI29_0_0Tag], ^(id<ABI29_0_0RCTComponent> subview) {
      ABI29_0_0RCTAssert(![subview isReactABI29_0_0RootView], @"Root views should not be unregistered");
      if ([subview conformsToProtocol:@protocol(ABI29_0_0RCTInvalidating)]) {
        [(id<ABI29_0_0RCTInvalidating>)subview invalidate];
      }
      [registry removeObjectForKey:subview.ReactABI29_0_0Tag];
    });
  }
}

- (void)addUIBlock:(ABI29_0_0RCTViewManagerUIBlock)block
{
  ABI29_0_0RCTAssertUIManagerQueue();

  if (!block || !_viewRegistry) {
    return;
  }

  [_pendingUIBlocks addObject:block];
}

- (void)prependUIBlock:(ABI29_0_0RCTViewManagerUIBlock)block
{
  ABI29_0_0RCTAssertUIManagerQueue();

  if (!block || !_viewRegistry) {
    return;
  }

  [_pendingUIBlocks insertObject:block atIndex:0];
}

- (void)setNextLayoutAnimationGroup:(ABI29_0_0RCTLayoutAnimationGroup *)layoutAnimationGroup
{
  ABI29_0_0RCTAssertMainQueue();

  if (_layoutAnimationGroup && ![_layoutAnimationGroup isEqual:layoutAnimationGroup]) {
    ABI29_0_0RCTLogWarn(@"Warning: Overriding previous layout animation with new one before the first began:\n%@ -> %@.",
      [_layoutAnimationGroup description],
      [layoutAnimationGroup description]);
  }

  _layoutAnimationGroup = layoutAnimationGroup;
}

- (ABI29_0_0RCTViewManagerUIBlock)uiBlockWithLayoutUpdateForRootView:(ABI29_0_0RCTRootShadowView *)rootShadowView
{
  ABI29_0_0RCTAssertUIManagerQueue();

  NSHashTable<ABI29_0_0RCTShadowView *> *affectedShadowViews = [NSHashTable weakObjectsHashTable];
  [rootShadowView layoutWithAffectedShadowViews:affectedShadowViews];

  if (!affectedShadowViews.count) {
    // no frame change results in no UI update block
    return nil;
  }

  typedef struct {
    CGRect frame;
    UIUserInterfaceLayoutDirection layoutDirection;
    BOOL isNew;
    BOOL parentIsNew;
  } ABI29_0_0RCTFrameData;

  // Construct arrays then hand off to main thread
  NSUInteger count = affectedShadowViews.count;
  NSMutableArray *ReactABI29_0_0Tags = [[NSMutableArray alloc] initWithCapacity:count];
  NSMutableData *framesData = [[NSMutableData alloc] initWithLength:sizeof(ABI29_0_0RCTFrameData) * count];
  {
    NSUInteger index = 0;
    ABI29_0_0RCTFrameData *frameDataArray = (ABI29_0_0RCTFrameData *)framesData.mutableBytes;
    for (ABI29_0_0RCTShadowView *shadowView in affectedShadowViews) {
      ReactABI29_0_0Tags[index] = shadowView.ReactABI29_0_0Tag;
      ABI29_0_0RCTLayoutMetrics layoutMetrics = shadowView.layoutMetrics;
      frameDataArray[index++] = (ABI29_0_0RCTFrameData){
        layoutMetrics.frame,
        layoutMetrics.layoutDirection,
        shadowView.isNewView,
        shadowView.superview.isNewView,
      };
    }
  }

  for (ABI29_0_0RCTShadowView *shadowView in affectedShadowViews) {

    // We have to do this after we build the parentsAreNew array.
    shadowView.newView = NO;

    NSNumber *ReactABI29_0_0Tag = shadowView.ReactABI29_0_0Tag;

    if (shadowView.onLayout) {
      CGRect frame = shadowView.layoutMetrics.frame;
      shadowView.onLayout(@{
        @"layout": @{
          @"x": @(frame.origin.x),
          @"y": @(frame.origin.y),
          @"width": @(frame.size.width),
          @"height": @(frame.size.height),
        },
      });
    }

    if (
        ABI29_0_0RCTIsReactABI29_0_0RootView(ReactABI29_0_0Tag) &&
        [shadowView isKindOfClass:[ABI29_0_0RCTRootShadowView class]]
    ) {
      CGSize contentSize = shadowView.layoutMetrics.frame.size;

      ABI29_0_0RCTExecuteOnMainQueue(^{
        UIView *view = self->_viewRegistry[ReactABI29_0_0Tag];
        ABI29_0_0RCTAssert(view != nil, @"view (for ID %@) not found", ReactABI29_0_0Tag);

        ABI29_0_0RCTRootView *rootView = (ABI29_0_0RCTRootView *)[view superview];
        if ([rootView isKindOfClass:[ABI29_0_0RCTRootView class]]) {
          rootView.intrinsicContentSize = contentSize;
        }
      });
    }
  }

  // Perform layout (possibly animated)
  return ^(__unused ABI29_0_0RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {

    const ABI29_0_0RCTFrameData *frameDataArray = (const ABI29_0_0RCTFrameData *)framesData.bytes;
    ABI29_0_0RCTLayoutAnimationGroup *layoutAnimationGroup = uiManager->_layoutAnimationGroup;

    __block NSUInteger completionsCalled = 0;

    NSInteger index = 0;
    for (NSNumber *ReactABI29_0_0Tag in ReactABI29_0_0Tags) {
      ABI29_0_0RCTFrameData frameData = frameDataArray[index++];

      UIView *view = viewRegistry[ReactABI29_0_0Tag];
      CGRect frame = frameData.frame;

      UIUserInterfaceLayoutDirection layoutDirection = frameData.layoutDirection;
      BOOL isNew = frameData.isNew;
      ABI29_0_0RCTLayoutAnimation *updatingLayoutAnimation = isNew ? nil : layoutAnimationGroup.updatingLayoutAnimation;
      BOOL shouldAnimateCreation = isNew && !frameData.parentIsNew;
      ABI29_0_0RCTLayoutAnimation *creatingLayoutAnimation = shouldAnimateCreation ? layoutAnimationGroup.creatingLayoutAnimation : nil;

      void (^completion)(BOOL) = ^(BOOL finished) {
        completionsCalled++;
        if (layoutAnimationGroup.callback && completionsCalled == count) {
          layoutAnimationGroup.callback(@[@(finished)]);

          // It's unsafe to call this callback more than once, so we nil it out here
          // to make sure that doesn't happen.
          layoutAnimationGroup.callback = nil;
        }
      };

      if (view.ReactABI29_0_0LayoutDirection != layoutDirection) {
        view.ReactABI29_0_0LayoutDirection = layoutDirection;
      }

      if (creatingLayoutAnimation) {

        // Animate view creation
        [view ReactABI29_0_0SetFrame:frame];

        CATransform3D finalTransform = view.layer.transform;
        CGFloat finalOpacity = view.layer.opacity;

        NSString *property = creatingLayoutAnimation.property;
        if ([property isEqualToString:@"scaleXY"]) {
          view.layer.transform = CATransform3DMakeScale(0, 0, 0);
        } else if ([property isEqualToString:@"opacity"]) {
          view.layer.opacity = 0.0;
        } else {
          ABI29_0_0RCTLogError(@"Unsupported layout animation createConfig property %@",
                      creatingLayoutAnimation.property);
        }

        [creatingLayoutAnimation performAnimations:^{
          if ([property isEqualToString:@"scaleXY"]) {
            view.layer.transform = finalTransform;
          } else if ([property isEqualToString:@"opacity"]) {
            view.layer.opacity = finalOpacity;
          }
        } withCompletionBlock:completion];

      } else if (updatingLayoutAnimation) {

        // Animate view update
        [updatingLayoutAnimation performAnimations:^{
          [view ReactABI29_0_0SetFrame:frame];
        } withCompletionBlock:completion];

      } else {

        // Update without animation
        [view ReactABI29_0_0SetFrame:frame];
        completion(YES);
      }
    }

    // Clean up
    uiManager->_layoutAnimationGroup = nil;
  };
}

/**
 * A method to be called from JS, which takes a container ID and then releases
 * all subviews for that container upon receipt.
 */
ABI29_0_0RCT_EXPORT_METHOD(removeSubviewsFromContainerWithID:(nonnull NSNumber *)containerID)
{
  id<ABI29_0_0RCTComponent> container = _shadowViewRegistry[containerID];
  ABI29_0_0RCTAssert(container != nil, @"container view (for ID %@) not found", containerID);

  NSUInteger subviewsCount = [container ReactABI29_0_0Subviews].count;
  NSMutableArray<NSNumber *> *indices = [[NSMutableArray alloc] initWithCapacity:subviewsCount];
  for (NSUInteger childIndex = 0; childIndex < subviewsCount; childIndex++) {
    [indices addObject:@(childIndex)];
  }

  [self manageChildren:containerID
       moveFromIndices:nil
         moveToIndices:nil
     addChildReactABI29_0_0Tags:nil
          addAtIndices:nil
       removeAtIndices:indices];
}

/**
 * Disassociates children from container. Doesn't remove from registries.
 * TODO: use [NSArray getObjects:buffer] to reuse same fast buffer each time.
 *
 * @returns Array of removed items.
 */
- (NSArray<id<ABI29_0_0RCTComponent>> *)_childrenToRemoveFromContainer:(id<ABI29_0_0RCTComponent>)container
                                                    atIndices:(NSArray<NSNumber *> *)atIndices
{
  // If there are no indices to move or the container has no subviews don't bother
  // We support parents with nil subviews so long as they're all nil so this allows for this behavior
  if (atIndices.count == 0 || [container ReactABI29_0_0Subviews].count == 0) {
    return nil;
  }
  // Construction of removed children must be done "up front", before indices are disturbed by removals.
  NSMutableArray<id<ABI29_0_0RCTComponent>> *removedChildren = [NSMutableArray arrayWithCapacity:atIndices.count];
  ABI29_0_0RCTAssert(container != nil, @"container view (for ID %@) not found", container);
  for (NSNumber *indexNumber in atIndices) {
    NSUInteger index = indexNumber.unsignedIntegerValue;
    if (index < [container ReactABI29_0_0Subviews].count) {
      [removedChildren addObject:[container ReactABI29_0_0Subviews][index]];
    }
  }
  if (removedChildren.count != atIndices.count) {
    NSString *message = [NSString stringWithFormat:@"removedChildren count (%tu) was not what we expected (%tu)",
                         removedChildren.count, atIndices.count];
    ABI29_0_0RCTFatal(ABI29_0_0RCTErrorWithMessage(message));
  }
  return removedChildren;
}

- (void)_removeChildren:(NSArray<id<ABI29_0_0RCTComponent>> *)children
          fromContainer:(id<ABI29_0_0RCTComponent>)container
{
  for (id<ABI29_0_0RCTComponent> removedChild in children) {
    [container removeReactABI29_0_0Subview:removedChild];
  }
}

/**
 * Remove subviews from their parent with an animation.
 */
- (void)_removeChildren:(NSArray<UIView *> *)children
          fromContainer:(UIView *)container
          withAnimation:(ABI29_0_0RCTLayoutAnimationGroup *)animation
{
  ABI29_0_0RCTAssertMainQueue();
  ABI29_0_0RCTLayoutAnimation *deletingLayoutAnimation = animation.deletingLayoutAnimation;

  __block NSUInteger completionsCalled = 0;
  for (UIView *removedChild in children) {

    void (^completion)(BOOL) = ^(BOOL finished) {
      completionsCalled++;

      [removedChild removeFromSuperview];

      if (animation.callback && completionsCalled == children.count) {
        animation.callback(@[@(finished)]);

        // It's unsafe to call this callback more than once, so we nil it out here
        // to make sure that doesn't happen.
        animation.callback = nil;
      }
    };

    // Hack: At this moment we have two contradict intents.
    // First one: We want to delete the view from view hierarchy.
    // Second one: We want to animate this view, which implies the existence of this view in the hierarchy.
    // So, we have to remove this view from ReactABI29_0_0's view hierarchy but postpone removing from UIKit's hierarchy.
    // Here the problem: the default implementation of `-[UIView removeReactABI29_0_0Subview:]` also removes the view from UIKit's hierarchy.
    // So, let's temporary restore the view back after removing.
    // To do so, we have to memorize original `superview` (which can differ from `container`) and an index of removed view.
    UIView *originalSuperview = removedChild.superview;
    NSUInteger originalIndex = [originalSuperview.subviews indexOfObjectIdenticalTo:removedChild];
    [container removeReactABI29_0_0Subview:removedChild];
    // Disable user interaction while the view is animating
    // since the view is (conceptually) deleted and not supposed to be interactive.
    removedChild.userInteractionEnabled = NO;
    [originalSuperview insertSubview:removedChild atIndex:originalIndex];

    NSString *property = deletingLayoutAnimation.property;
    [deletingLayoutAnimation performAnimations:^{
      if ([property isEqualToString:@"scaleXY"]) {
        removedChild.layer.transform = CATransform3DMakeScale(0.001, 0.001, 0.001);
      } else if ([property isEqualToString:@"opacity"]) {
        removedChild.layer.opacity = 0.0;
      } else {
        ABI29_0_0RCTLogError(@"Unsupported layout animation createConfig property %@",
                    deletingLayoutAnimation.property);
      }
    } withCompletionBlock:completion];
  }
}


ABI29_0_0RCT_EXPORT_METHOD(removeRootView:(nonnull NSNumber *)rootReactABI29_0_0Tag)
{
  ABI29_0_0RCTShadowView *rootShadowView = _shadowViewRegistry[rootReactABI29_0_0Tag];
  ABI29_0_0RCTAssert(rootShadowView.superview == nil, @"root view cannot have superview (ID %@)", rootReactABI29_0_0Tag);
  [self _purgeChildren:(NSArray<id<ABI29_0_0RCTComponent>> *)rootShadowView.ReactABI29_0_0Subviews
          fromRegistry:(NSMutableDictionary<NSNumber *, id<ABI29_0_0RCTComponent>> *)_shadowViewRegistry];
  [_shadowViewRegistry removeObjectForKey:rootReactABI29_0_0Tag];
  [_rootViewTags removeObject:rootReactABI29_0_0Tag];

  [self addUIBlock:^(ABI29_0_0RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry){
    ABI29_0_0RCTAssertMainQueue();
    UIView *rootView = viewRegistry[rootReactABI29_0_0Tag];
    [uiManager _purgeChildren:(NSArray<id<ABI29_0_0RCTComponent>> *)rootView.ReactABI29_0_0Subviews
                 fromRegistry:(NSMutableDictionary<NSNumber *, id<ABI29_0_0RCTComponent>> *)viewRegistry];
    [(NSMutableDictionary *)viewRegistry removeObjectForKey:rootReactABI29_0_0Tag];
  }];
}

ABI29_0_0RCT_EXPORT_METHOD(replaceExistingNonRootView:(nonnull NSNumber *)ReactABI29_0_0Tag
                  withView:(nonnull NSNumber *)newReactABI29_0_0Tag)
{
  ABI29_0_0RCTShadowView *shadowView = _shadowViewRegistry[ReactABI29_0_0Tag];
  ABI29_0_0RCTAssert(shadowView != nil, @"shadowView (for ID %@) not found", ReactABI29_0_0Tag);

  ABI29_0_0RCTShadowView *superShadowView = shadowView.superview;
  if (!superShadowView) {
    ABI29_0_0RCTAssert(NO, @"shadowView super (of ID %@) not found", ReactABI29_0_0Tag);
    return;
  }

  NSUInteger indexOfView = [superShadowView.ReactABI29_0_0Subviews indexOfObjectIdenticalTo:shadowView];
  ABI29_0_0RCTAssert(indexOfView != NSNotFound, @"View's superview doesn't claim it as subview (id %@)", ReactABI29_0_0Tag);
  NSArray<NSNumber *> *removeAtIndices = @[@(indexOfView)];
  NSArray<NSNumber *> *addTags = @[newReactABI29_0_0Tag];
  [self manageChildren:superShadowView.ReactABI29_0_0Tag
       moveFromIndices:nil
         moveToIndices:nil
     addChildReactABI29_0_0Tags:addTags
          addAtIndices:removeAtIndices
       removeAtIndices:removeAtIndices];
}

ABI29_0_0RCT_EXPORT_METHOD(setChildren:(nonnull NSNumber *)containerTag
                  ReactABI29_0_0Tags:(NSArray<NSNumber *> *)ReactABI29_0_0Tags)
{
  ABI29_0_0RCTSetChildren(containerTag, ReactABI29_0_0Tags,
                 (NSDictionary<NSNumber *, id<ABI29_0_0RCTComponent>> *)_shadowViewRegistry);

  [self addUIBlock:^(__unused ABI29_0_0RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry){

    ABI29_0_0RCTSetChildren(containerTag, ReactABI29_0_0Tags,
                   (NSDictionary<NSNumber *, id<ABI29_0_0RCTComponent>> *)viewRegistry);
  }];

  [self _shadowViewDidReceiveUpdatedChildren:_shadowViewRegistry[containerTag]];
}

static void ABI29_0_0RCTSetChildren(NSNumber *containerTag,
                           NSArray<NSNumber *> *ReactABI29_0_0Tags,
                           NSDictionary<NSNumber *, id<ABI29_0_0RCTComponent>> *registry)
{
  id<ABI29_0_0RCTComponent> container = registry[containerTag];
  NSInteger index = 0;
  for (NSNumber *ReactABI29_0_0Tag in ReactABI29_0_0Tags) {
    id<ABI29_0_0RCTComponent> view = registry[ReactABI29_0_0Tag];
    if (view) {
      [container insertReactABI29_0_0Subview:view atIndex:index++];
    }
  }
}

ABI29_0_0RCT_EXPORT_METHOD(manageChildren:(nonnull NSNumber *)containerTag
                  moveFromIndices:(NSArray<NSNumber *> *)moveFromIndices
                  moveToIndices:(NSArray<NSNumber *> *)moveToIndices
                  addChildReactABI29_0_0Tags:(NSArray<NSNumber *> *)addChildReactABI29_0_0Tags
                  addAtIndices:(NSArray<NSNumber *> *)addAtIndices
                  removeAtIndices:(NSArray<NSNumber *> *)removeAtIndices)
{
  [self _manageChildren:containerTag
        moveFromIndices:moveFromIndices
          moveToIndices:moveToIndices
      addChildReactABI29_0_0Tags:addChildReactABI29_0_0Tags
           addAtIndices:addAtIndices
        removeAtIndices:removeAtIndices
               registry:(NSMutableDictionary<NSNumber *, id<ABI29_0_0RCTComponent>> *)_shadowViewRegistry];

  [self addUIBlock:^(ABI29_0_0RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry){
    [uiManager _manageChildren:containerTag
               moveFromIndices:moveFromIndices
                 moveToIndices:moveToIndices
             addChildReactABI29_0_0Tags:addChildReactABI29_0_0Tags
                  addAtIndices:addAtIndices
               removeAtIndices:removeAtIndices
                      registry:(NSMutableDictionary<NSNumber *, id<ABI29_0_0RCTComponent>> *)viewRegistry];
  }];

  [self _shadowViewDidReceiveUpdatedChildren:_shadowViewRegistry[containerTag]];
}

- (void)_manageChildren:(NSNumber *)containerTag
        moveFromIndices:(NSArray<NSNumber *> *)moveFromIndices
          moveToIndices:(NSArray<NSNumber *> *)moveToIndices
      addChildReactABI29_0_0Tags:(NSArray<NSNumber *> *)addChildReactABI29_0_0Tags
           addAtIndices:(NSArray<NSNumber *> *)addAtIndices
        removeAtIndices:(NSArray<NSNumber *> *)removeAtIndices
               registry:(NSMutableDictionary<NSNumber *, id<ABI29_0_0RCTComponent>> *)registry
{
  id<ABI29_0_0RCTComponent> container = registry[containerTag];
  ABI29_0_0RCTAssert(moveFromIndices.count == moveToIndices.count, @"moveFromIndices had size %tu, moveToIndices had size %tu", moveFromIndices.count, moveToIndices.count);
  ABI29_0_0RCTAssert(addChildReactABI29_0_0Tags.count == addAtIndices.count, @"there should be at least one ReactABI29_0_0 child to add");

  // Removes (both permanent and temporary moves) are using "before" indices
  NSArray<id<ABI29_0_0RCTComponent>> *permanentlyRemovedChildren =
    [self _childrenToRemoveFromContainer:container atIndices:removeAtIndices];
  NSArray<id<ABI29_0_0RCTComponent>> *temporarilyRemovedChildren =
    [self _childrenToRemoveFromContainer:container atIndices:moveFromIndices];

  BOOL isUIViewRegistry = ((id)registry == (id)_viewRegistry);
  if (isUIViewRegistry && _layoutAnimationGroup.deletingLayoutAnimation) {
    [self _removeChildren:(NSArray<UIView *> *)permanentlyRemovedChildren
            fromContainer:(UIView *)container
            withAnimation:_layoutAnimationGroup];
  } else {
    [self _removeChildren:permanentlyRemovedChildren fromContainer:container];
  }

  [self _removeChildren:temporarilyRemovedChildren fromContainer:container];
  [self _purgeChildren:permanentlyRemovedChildren fromRegistry:registry];

  // Figure out what to insert - merge temporary inserts and adds
  NSMutableDictionary *destinationsToChildrenToAdd = [NSMutableDictionary dictionary];
  for (NSInteger index = 0, length = temporarilyRemovedChildren.count; index < length; index++) {
    destinationsToChildrenToAdd[moveToIndices[index]] = temporarilyRemovedChildren[index];
  }

  for (NSInteger index = 0, length = addAtIndices.count; index < length; index++) {
    id<ABI29_0_0RCTComponent> view = registry[addChildReactABI29_0_0Tags[index]];
    if (view) {
      destinationsToChildrenToAdd[addAtIndices[index]] = view;
    }
  }

  NSArray<NSNumber *> *sortedIndices =
    [destinationsToChildrenToAdd.allKeys sortedArrayUsingSelector:@selector(compare:)];
  for (NSNumber *ReactABI29_0_0Index in sortedIndices) {
    [container insertReactABI29_0_0Subview:destinationsToChildrenToAdd[ReactABI29_0_0Index]
                          atIndex:ReactABI29_0_0Index.integerValue];
  }
}

ABI29_0_0RCT_EXPORT_METHOD(createView:(nonnull NSNumber *)ReactABI29_0_0Tag
                  viewName:(NSString *)viewName
                  rootTag:(nonnull NSNumber *)rootTag
                  props:(NSDictionary *)props)
{
  ABI29_0_0RCTComponentData *componentData = _componentDataByName[viewName];
  if (componentData == nil) {
    ABI29_0_0RCTLogError(@"No component found for view with name \"%@\"", viewName);
  }

  // Register shadow view
  ABI29_0_0RCTShadowView *shadowView = [componentData createShadowViewWithTag:ReactABI29_0_0Tag];
  if (shadowView) {
    [componentData setProps:props forShadowView:shadowView];
    _shadowViewRegistry[ReactABI29_0_0Tag] = shadowView;
    ABI29_0_0RCTShadowView *rootView = _shadowViewRegistry[rootTag];
    ABI29_0_0RCTAssert([rootView isKindOfClass:[ABI29_0_0RCTRootShadowView class]] ||
              [rootView isKindOfClass:[ABI29_0_0RCTSurfaceRootShadowView class]],
      @"Given `rootTag` (%@) does not correspond to a valid root shadow view instance.", rootTag);
    shadowView.rootView = (ABI29_0_0RCTRootShadowView *)rootView;
  }

  // Dispatch view creation directly to the main thread instead of adding to
  // UIBlocks array. This way, it doesn't get deferred until after layout.
  __block UIView *preliminaryCreatedView = nil;

  void (^createViewBlock)(void) = ^{
    // Do nothing on the second run.
    if (preliminaryCreatedView) {
      return;
    }

    preliminaryCreatedView = [componentData createViewWithTag:ReactABI29_0_0Tag];

    if (preliminaryCreatedView) {
      self->_viewRegistry[ReactABI29_0_0Tag] = preliminaryCreatedView;
    }
  };

  // We cannot guarantee that asynchronously scheduled block will be executed
  // *before* a block is added to the regular mounting process (simply because
  // mounting process can be managed externally while the main queue is
  // locked).
  // So, we positively dispatch it asynchronously and double check inside
  // the regular mounting block.

  ABI29_0_0RCTExecuteOnMainQueue(createViewBlock);

  [self addUIBlock:^(__unused ABI29_0_0RCTUIManager *uiManager, __unused NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    createViewBlock();

    if (preliminaryCreatedView) {
      [componentData setProps:props forView:preliminaryCreatedView];
    }
  }];

  [self _shadowView:shadowView didReceiveUpdatedProps:[props allKeys]];
}

ABI29_0_0RCT_EXPORT_METHOD(updateView:(nonnull NSNumber *)ReactABI29_0_0Tag
                  viewName:(NSString *)viewName // not always reliable, use shadowView.viewName if available
                  props:(NSDictionary *)props)
{
  ABI29_0_0RCTShadowView *shadowView = _shadowViewRegistry[ReactABI29_0_0Tag];
  ABI29_0_0RCTComponentData *componentData = _componentDataByName[shadowView.viewName ?: viewName];
  [componentData setProps:props forShadowView:shadowView];

  [self addUIBlock:^(__unused ABI29_0_0RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    UIView *view = viewRegistry[ReactABI29_0_0Tag];
    [componentData setProps:props forView:view];
  }];

  [self _shadowView:shadowView didReceiveUpdatedProps:[props allKeys]];
}

- (void)synchronouslyUpdateViewOnUIThread:(NSNumber *)ReactABI29_0_0Tag
                                 viewName:(NSString *)viewName
                                    props:(NSDictionary *)props
{
  ABI29_0_0RCTAssertMainQueue();
  ABI29_0_0RCTComponentData *componentData = _componentDataByName[viewName];
  UIView *view = _viewRegistry[ReactABI29_0_0Tag];
  [componentData setProps:props forView:view];
}

ABI29_0_0RCT_EXPORT_METHOD(focus:(nonnull NSNumber *)ReactABI29_0_0Tag)
{
  [self addUIBlock:^(__unused ABI29_0_0RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    UIView *newResponder = viewRegistry[ReactABI29_0_0Tag];
    [newResponder ReactABI29_0_0Focus];
  }];
}

ABI29_0_0RCT_EXPORT_METHOD(blur:(nonnull NSNumber *)ReactABI29_0_0Tag)
{
  [self addUIBlock:^(__unused ABI29_0_0RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry){
    UIView *currentResponder = viewRegistry[ReactABI29_0_0Tag];
    [currentResponder ReactABI29_0_0Blur];
  }];
}

ABI29_0_0RCT_EXPORT_METHOD(findSubviewIn:(nonnull NSNumber *)ReactABI29_0_0Tag atPoint:(CGPoint)point callback:(ABI29_0_0RCTResponseSenderBlock)callback)
{
  [self addUIBlock:^(__unused ABI29_0_0RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    UIView *view = viewRegistry[ReactABI29_0_0Tag];
    UIView *target = [view hitTest:point withEvent:nil];
    CGRect frame = [target convertRect:target.bounds toView:view];

    while (target.ReactABI29_0_0Tag == nil && target.superview != nil) {
      target = target.superview;
    }

    callback(@[
      ABI29_0_0RCTNullIfNil(target.ReactABI29_0_0Tag),
      @(frame.origin.x),
      @(frame.origin.y),
      @(frame.size.width),
      @(frame.size.height),
    ]);
  }];
}

ABI29_0_0RCT_EXPORT_METHOD(dispatchViewManagerCommand:(nonnull NSNumber *)ReactABI29_0_0Tag
                  commandID:(NSInteger)commandID
                  commandArgs:(NSArray<id> *)commandArgs)
{
  ABI29_0_0RCTShadowView *shadowView = _shadowViewRegistry[ReactABI29_0_0Tag];
  ABI29_0_0RCTComponentData *componentData = _componentDataByName[shadowView.viewName];
  Class managerClass = componentData.managerClass;
  ABI29_0_0RCTModuleData *moduleData = [_bridge moduleDataForName:ABI29_0_0RCTBridgeModuleNameForClass(managerClass)];
  id<ABI29_0_0RCTBridgeMethod> method = moduleData.methods[commandID];

  NSArray *args = [@[ReactABI29_0_0Tag] arrayByAddingObjectsFromArray:commandArgs];
  [method invokeWithBridge:_bridge module:componentData.manager arguments:args];
}

- (void)batchDidComplete
{
  [self _layoutAndMount];
}

/**
 * Sets up animations, computes layout, creates UI mounting blocks for computed layout,
 * runs these blocks and all other already existing blocks.
 */
- (void)_layoutAndMount
{
  [self _dispatchPropsDidChangeEvents];
  [self _dispatchChildrenDidChangeEvents];

  [_observerCoordinator uiManagerWillPerformLayout:self];

  // Perform layout
  for (NSNumber *ReactABI29_0_0Tag in _rootViewTags) {
    ABI29_0_0RCTRootShadowView *rootView = (ABI29_0_0RCTRootShadowView *)_shadowViewRegistry[ReactABI29_0_0Tag];
    [self addUIBlock:[self uiBlockWithLayoutUpdateForRootView:rootView]];
  }

  [_observerCoordinator uiManagerDidPerformLayout:self];

  [_observerCoordinator uiManagerWillPerformMounting:self];

  [self flushUIBlocksWithCompletion:^{
    [self->_observerCoordinator uiManagerDidPerformMounting:self];
  }];
}

- (void)flushUIBlocksWithCompletion:(void (^)(void))completion;
{
  ABI29_0_0RCTAssertUIManagerQueue();

  // First copy the previous blocks into a temporary variable, then reset the
  // pending blocks to a new array. This guards against mutation while
  // processing the pending blocks in another thread.
  NSArray<ABI29_0_0RCTViewManagerUIBlock> *previousPendingUIBlocks = _pendingUIBlocks;
  _pendingUIBlocks = [NSMutableArray new];

  if (previousPendingUIBlocks.count == 0) {
    completion();
    return;
  }

  __weak typeof(self) weakSelf = self;

   void (^mountingBlock)(void) = ^{
    typeof(self) strongSelf = weakSelf;

    @try {
      for (ABI29_0_0RCTViewManagerUIBlock block in previousPendingUIBlocks) {
        block(strongSelf, strongSelf->_viewRegistry);
      }
    }
    @catch (NSException *exception) {
      ABI29_0_0RCTLogError(@"Exception thrown while executing UI block: %@", exception);
    }
  };

  if ([self.observerCoordinator uiManager:self performMountingWithBlock:mountingBlock]) {
    completion();
    return;
  }

  // Execute the previously queued UI blocks
  ABI29_0_0RCTProfileBeginFlowEvent();
  ABI29_0_0RCTExecuteOnMainQueue(^{
    ABI29_0_0RCTProfileEndFlowEvent();
    ABI29_0_0RCT_PROFILE_BEGIN_EVENT(ABI29_0_0RCTProfileTagAlways, @"-[UIManager flushUIBlocks]", (@{
      @"count": [@(previousPendingUIBlocks.count) stringValue],
    }));

    mountingBlock();

    ABI29_0_0RCT_PROFILE_END_EVENT(ABI29_0_0RCTProfileTagAlways, @"");

    ABI29_0_0RCTExecuteOnUIManagerQueue(completion);
  });
}

- (void)setNeedsLayout
{
  // If there is an active batch layout will happen when batch finished, so we will wait for that.
  // Otherwise we immediately trigger layout.
  if (![_bridge isBatchActive] && ![_bridge isLoading]) {
    [self _layoutAndMount];
  }
}

- (void)_shadowView:(ABI29_0_0RCTShadowView *)shadowView didReceiveUpdatedProps:(NSArray<NSString *> *)props
{
  // We collect a set with changed `shadowViews` and its changed props,
  // so we have to maintain this collection properly.
  NSArray<NSString *> *previousProps;
  if ((previousProps = [_shadowViewsWithUpdatedProps objectForKey:shadowView])) {
    // Merging already registred changed props and new ones.
    NSMutableSet *set = [NSMutableSet setWithArray:previousProps];
    [set addObjectsFromArray:props];
    props = [set allObjects];
  }

  [_shadowViewsWithUpdatedProps setObject:props forKey:shadowView];
}

- (void)_shadowViewDidReceiveUpdatedChildren:(ABI29_0_0RCTShadowView *)shadowView
{
  [_shadowViewsWithUpdatedChildren addObject:shadowView];
}

- (void)_dispatchChildrenDidChangeEvents
{
  if (_shadowViewsWithUpdatedChildren.count == 0) {
    return;
  }

  NSHashTable<ABI29_0_0RCTShadowView *> *shadowViews = _shadowViewsWithUpdatedChildren;
  _shadowViewsWithUpdatedChildren = [NSHashTable weakObjectsHashTable];

  NSMutableArray *tags = [NSMutableArray arrayWithCapacity:shadowViews.count];

  for (ABI29_0_0RCTShadowView *shadowView in shadowViews) {
    [shadowView didUpdateReactABI29_0_0Subviews];
    [tags addObject:shadowView.ReactABI29_0_0Tag];
  }

  [self addUIBlock:^(ABI29_0_0RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    for (NSNumber *tag in tags) {
      UIView<ABI29_0_0RCTComponent> *view = viewRegistry[tag];
      [view didUpdateReactABI29_0_0Subviews];
    }
  }];
}

- (void)_dispatchPropsDidChangeEvents
{
  if (_shadowViewsWithUpdatedProps.count == 0) {
    return;
  }

  NSMapTable<ABI29_0_0RCTShadowView *, NSArray<NSString *> *> *shadowViews = _shadowViewsWithUpdatedProps;
  _shadowViewsWithUpdatedProps = [NSMapTable weakToStrongObjectsMapTable];

  NSMapTable<NSNumber *, NSArray<NSString *> *> *tags = [NSMapTable strongToStrongObjectsMapTable];

  for (ABI29_0_0RCTShadowView *shadowView in shadowViews) {
    NSArray<NSString *> *props = [shadowViews objectForKey:shadowView];
    [shadowView didSetProps:props];
    [tags setObject:props forKey:shadowView.ReactABI29_0_0Tag];
  }

  [self addUIBlock:^(ABI29_0_0RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    for (NSNumber *tag in tags) {
      UIView<ABI29_0_0RCTComponent> *view = viewRegistry[tag];
      [view didSetProps:[tags objectForKey:tag]];
    }
  }];
}

ABI29_0_0RCT_EXPORT_METHOD(measure:(nonnull NSNumber *)ReactABI29_0_0Tag
                  callback:(ABI29_0_0RCTResponseSenderBlock)callback)
{
  [self addUIBlock:^(__unused ABI29_0_0RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    UIView *view = viewRegistry[ReactABI29_0_0Tag];
    if (!view) {
      // this view was probably collapsed out
      ABI29_0_0RCTLogWarn(@"measure cannot find view with tag #%@", ReactABI29_0_0Tag);
      callback(@[]);
      return;
    }

    // If in a <Modal>, rootView will be the root of the modal container.
    UIView *rootView = view;
    while (rootView.superview && ![rootView isReactABI29_0_0RootView]) {
      rootView = rootView.superview;
    }

    // By convention, all coordinates, whether they be touch coordinates, or
    // measurement coordinates are with respect to the root view.
    CGRect frame = view.frame;
    CGRect globalBounds = [view convertRect:view.bounds toView:rootView];

    callback(@[
      @(frame.origin.x),
      @(frame.origin.y),
      @(globalBounds.size.width),
      @(globalBounds.size.height),
      @(globalBounds.origin.x),
      @(globalBounds.origin.y),
    ]);
  }];
}

ABI29_0_0RCT_EXPORT_METHOD(measureInWindow:(nonnull NSNumber *)ReactABI29_0_0Tag
                  callback:(ABI29_0_0RCTResponseSenderBlock)callback)
{
  [self addUIBlock:^(__unused ABI29_0_0RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    UIView *view = viewRegistry[ReactABI29_0_0Tag];
    if (!view) {
      // this view was probably collapsed out
      ABI29_0_0RCTLogWarn(@"measure cannot find view with tag #%@", ReactABI29_0_0Tag);
      callback(@[]);
      return;
    }

    // Return frame coordinates in window
    CGRect windowFrame = [view.window convertRect:view.frame fromView:view.superview];
    callback(@[
      @(windowFrame.origin.x),
      @(windowFrame.origin.y),
      @(windowFrame.size.width),
      @(windowFrame.size.height),
    ]);
  }];
}

/**
 * Returs if the shadow view provided has the `ancestor` shadow view as
 * an actual ancestor.
 */
ABI29_0_0RCT_EXPORT_METHOD(viewIsDescendantOf:(nonnull NSNumber *)ReactABI29_0_0Tag
                  ancestor:(nonnull NSNumber *)ancestorReactABI29_0_0Tag
                  callback:(ABI29_0_0RCTResponseSenderBlock)callback)
{
  ABI29_0_0RCTShadowView *shadowView = _shadowViewRegistry[ReactABI29_0_0Tag];
  ABI29_0_0RCTShadowView *ancestorShadowView = _shadowViewRegistry[ancestorReactABI29_0_0Tag];
  if (!shadowView) {
    return;
  }
  if (!ancestorShadowView) {
    return;
  }
  BOOL viewIsAncestor = [shadowView viewIsDescendantOf:ancestorShadowView];
  callback(@[@(viewIsAncestor)]);
}

static void ABI29_0_0RCTMeasureLayout(ABI29_0_0RCTShadowView *view,
                             ABI29_0_0RCTShadowView *ancestor,
                             ABI29_0_0RCTResponseSenderBlock callback)
{
  if (!view) {
    return;
  }
  if (!ancestor) {
    return;
  }
  CGRect result = [view measureLayoutRelativeToAncestor:ancestor];
  if (CGRectIsNull(result)) {
    ABI29_0_0RCTLogError(@"view %@ (tag #%@) is not a descendant of %@ (tag #%@)",
                view, view.ReactABI29_0_0Tag, ancestor, ancestor.ReactABI29_0_0Tag);
    return;
  }
  CGFloat leftOffset = result.origin.x;
  CGFloat topOffset = result.origin.y;
  CGFloat width = result.size.width;
  CGFloat height = result.size.height;
  if (isnan(leftOffset) || isnan(topOffset) || isnan(width) || isnan(height)) {
    ABI29_0_0RCTLogError(@"Attempted to measure layout but offset or dimensions were NaN");
    return;
  }
  callback(@[@(leftOffset), @(topOffset), @(width), @(height)]);
}

/**
 * Returns the computed recursive offset layout in a dictionary form. The
 * returned values are relative to the `ancestor` shadow view. Returns `nil`, if
 * the `ancestor` shadow view is not actually an `ancestor`. Does not touch
 * anything on the main UI thread. Invokes supplied callback with (x, y, width,
 * height).
 */
ABI29_0_0RCT_EXPORT_METHOD(measureLayout:(nonnull NSNumber *)ReactABI29_0_0Tag
                  relativeTo:(nonnull NSNumber *)ancestorReactABI29_0_0Tag
                  errorCallback:(__unused ABI29_0_0RCTResponseSenderBlock)errorCallback
                  callback:(ABI29_0_0RCTResponseSenderBlock)callback)
{
  ABI29_0_0RCTShadowView *shadowView = _shadowViewRegistry[ReactABI29_0_0Tag];
  ABI29_0_0RCTShadowView *ancestorShadowView = _shadowViewRegistry[ancestorReactABI29_0_0Tag];
  ABI29_0_0RCTMeasureLayout(shadowView, ancestorShadowView, callback);
}

/**
 * Returns the computed recursive offset layout in a dictionary form. The
 * returned values are relative to the `ancestor` shadow view. Returns `nil`, if
 * the `ancestor` shadow view is not actually an `ancestor`. Does not touch
 * anything on the main UI thread. Invokes supplied callback with (x, y, width,
 * height).
 */
ABI29_0_0RCT_EXPORT_METHOD(measureLayoutRelativeToParent:(nonnull NSNumber *)ReactABI29_0_0Tag
                  errorCallback:(__unused ABI29_0_0RCTResponseSenderBlock)errorCallback
                  callback:(ABI29_0_0RCTResponseSenderBlock)callback)
{
  ABI29_0_0RCTShadowView *shadowView = _shadowViewRegistry[ReactABI29_0_0Tag];
  ABI29_0_0RCTMeasureLayout(shadowView, shadowView.ReactABI29_0_0Superview, callback);
}

/**
 * Returns an array of computed offset layouts in a dictionary form. The layouts are of any ReactABI29_0_0 subviews
 * that are immediate descendants to the parent view found within a specified rect. The dictionary result
 * contains left, top, width, height and an index. The index specifies the position among the other subviews.
 * Only layouts for views that are within the rect passed in are returned. Invokes the error callback if the
 * passed in parent view does not exist. Invokes the supplied callback with the array of computed layouts.
 */
ABI29_0_0RCT_EXPORT_METHOD(measureViewsInRect:(CGRect)rect
                  parentView:(nonnull NSNumber *)ReactABI29_0_0Tag
                  errorCallback:(__unused ABI29_0_0RCTResponseSenderBlock)errorCallback
                  callback:(ABI29_0_0RCTResponseSenderBlock)callback)
{
  ABI29_0_0RCTShadowView *shadowView = _shadowViewRegistry[ReactABI29_0_0Tag];
  if (!shadowView) {
    ABI29_0_0RCTLogError(@"Attempting to measure view that does not exist (tag #%@)", ReactABI29_0_0Tag);
    return;
  }
  NSArray<ABI29_0_0RCTShadowView *> *childShadowViews = [shadowView ReactABI29_0_0Subviews];
  NSMutableArray<NSDictionary *> *results =
    [[NSMutableArray alloc] initWithCapacity:childShadowViews.count];

  [childShadowViews enumerateObjectsUsingBlock:
   ^(ABI29_0_0RCTShadowView *childShadowView, NSUInteger idx, __unused BOOL *stop) {
    CGRect childLayout = [childShadowView measureLayoutRelativeToAncestor:shadowView];
    if (CGRectIsNull(childLayout)) {
      ABI29_0_0RCTLogError(@"View %@ (tag #%@) is not a descendant of %@ (tag #%@)",
                  childShadowView, childShadowView.ReactABI29_0_0Tag, shadowView, shadowView.ReactABI29_0_0Tag);
      return;
    }

    CGFloat leftOffset = childLayout.origin.x;
    CGFloat topOffset = childLayout.origin.y;
    CGFloat width = childLayout.size.width;
    CGFloat height = childLayout.size.height;

    if (leftOffset <= rect.origin.x + rect.size.width &&
        leftOffset + width >= rect.origin.x &&
        topOffset <= rect.origin.y + rect.size.height &&
        topOffset + height >= rect.origin.y) {

      // This view is within the layout rect
      NSDictionary *result = @{@"index": @(idx),
                               @"left": @(leftOffset),
                               @"top": @(topOffset),
                               @"width": @(width),
                               @"height": @(height)};

      [results addObject:result];
    }
  }];
  callback(@[results]);
}

ABI29_0_0RCT_EXPORT_METHOD(takeSnapshot:(id /* NSString or NSNumber */)target
                  withOptions:(NSDictionary *)options
                  resolve:(ABI29_0_0RCTPromiseResolveBlock)resolve
                  reject:(ABI29_0_0RCTPromiseRejectBlock)reject)
{
  [self addUIBlock:^(__unused ABI29_0_0RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {

    // Get view
    UIView *view;
    if (target == nil || [target isEqual:@"window"]) {
      view = ABI29_0_0RCTKeyWindow();
    } else if ([target isKindOfClass:[NSNumber class]]) {
      view = viewRegistry[target];
      if (!view) {
        ABI29_0_0RCTLogError(@"No view found with ReactABI29_0_0Tag: %@", target);
        return;
      }
    }

    // Get options
    CGSize size = [ABI29_0_0RCTConvert CGSize:options];
    NSString *format = [ABI29_0_0RCTConvert NSString:options[@"format"] ?: @"png"];

    // Capture image
    if (size.width < 0.1 || size.height < 0.1) {
      size = view.bounds.size;
    }
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    BOOL success = [view drawViewHierarchyInRect:(CGRect){CGPointZero, size} afterScreenUpdates:YES];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if (!success || !image) {
      reject(ABI29_0_0RCTErrorUnspecified, @"Failed to capture view snapshot.", nil);
      return;
    }

    // Convert image to data (on a background thread)
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

      NSData *data;
      if ([format isEqualToString:@"png"]) {
        data = UIImagePNGRepresentation(image);
      } else if ([format isEqualToString:@"jpeg"]) {
        CGFloat quality = [ABI29_0_0RCTConvert CGFloat:options[@"quality"] ?: @1];
        data = UIImageJPEGRepresentation(image, quality);
      } else {
        ABI29_0_0RCTLogError(@"Unsupported image format: %@", format);
        return;
      }

      // Save to a temp file
      NSError *error = nil;
      NSString *tempFilePath = ABI29_0_0RCTTempFilePath(format, &error);
      if (tempFilePath) {
        if ([data writeToFile:tempFilePath options:(NSDataWritingOptions)0 error:&error]) {
          resolve(tempFilePath);
          return;
        }
      }

      // If we reached here, something went wrong
      reject(ABI29_0_0RCTErrorUnspecified, error.localizedDescription, error);
    });
  }];
}

/**
 * JS sets what *it* considers to be the responder. Later, scroll views can use
 * this in order to determine if scrolling is appropriate.
 */
ABI29_0_0RCT_EXPORT_METHOD(setJSResponder:(nonnull NSNumber *)ReactABI29_0_0Tag
                  blockNativeResponder:(__unused BOOL)blockNativeResponder)
{
  [self addUIBlock:^(__unused ABI29_0_0RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    _jsResponder = viewRegistry[ReactABI29_0_0Tag];
    if (!_jsResponder) {
      ABI29_0_0RCTLogError(@"Invalid view set to be the JS responder - tag %@", ReactABI29_0_0Tag);
    }
  }];
}

ABI29_0_0RCT_EXPORT_METHOD(clearJSResponder)
{
  [self addUIBlock:^(__unused ABI29_0_0RCTUIManager *uiManager, __unused NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    _jsResponder = nil;
  }];
}

- (NSDictionary<NSString *, id> *)constantsToExport
{
  NSMutableDictionary<NSString *, NSDictionary *> *constants = [NSMutableDictionary new];
  NSMutableDictionary<NSString *, NSDictionary *> *directEvents = [NSMutableDictionary new];
  NSMutableDictionary<NSString *, NSDictionary *> *bubblingEvents = [NSMutableDictionary new];

  [_componentDataByName enumerateKeysAndObjectsUsingBlock:^(NSString *name, ABI29_0_0RCTComponentData *componentData, __unused BOOL *stop) {
     NSMutableDictionary<NSString *, id> *moduleConstants = [NSMutableDictionary new];

     // Register which event-types this view dispatches.
     // ReactABI29_0_0 needs this for the event plugin.
     NSMutableDictionary<NSString *, NSDictionary *> *bubblingEventTypes = [NSMutableDictionary new];
     NSMutableDictionary<NSString *, NSDictionary *> *directEventTypes = [NSMutableDictionary new];

     // Add manager class
     moduleConstants[@"Manager"] = ABI29_0_0RCTBridgeModuleNameForClass(componentData.managerClass);

     // Add native props
     NSDictionary<NSString *, id> *viewConfig = [componentData viewConfig];
     moduleConstants[@"NativeProps"] = viewConfig[@"propTypes"];
     moduleConstants[@"baseModuleName"] = viewConfig[@"baseModuleName"];
     moduleConstants[@"bubblingEventTypes"] = bubblingEventTypes;
     moduleConstants[@"directEventTypes"] = directEventTypes;

     // Add direct events
     for (NSString *eventName in viewConfig[@"directEvents"]) {
       if (!directEvents[eventName]) {
         directEvents[eventName] = @{
           @"registrationName": [eventName stringByReplacingCharactersInRange:(NSRange){0, 3} withString:@"on"],
         };
       }
       directEventTypes[eventName] = directEvents[eventName];
       if (ABI29_0_0RCT_DEBUG && bubblingEvents[eventName]) {
         ABI29_0_0RCTLogError(@"Component '%@' re-registered bubbling event '%@' as a "
                     "direct event", componentData.name, eventName);
       }
     }

     // Add bubbling events
     for (NSString *eventName in viewConfig[@"bubblingEvents"]) {
       if (!bubblingEvents[eventName]) {
         NSString *bubbleName = [eventName stringByReplacingCharactersInRange:(NSRange){0, 3} withString:@"on"];
         bubblingEvents[eventName] = @{
           @"phasedRegistrationNames": @{
             @"bubbled": bubbleName,
             @"captured": [bubbleName stringByAppendingString:@"Capture"],
           }
         };
       }
       bubblingEventTypes[eventName] = bubblingEvents[eventName];
       if (ABI29_0_0RCT_DEBUG && directEvents[eventName]) {
         ABI29_0_0RCTLogError(@"Component '%@' re-registered direct event '%@' as a "
                     "bubbling event", componentData.name, eventName);
       }
     }

     ABI29_0_0RCTAssert(!constants[name], @"UIManager already has constants for %@", componentData.name);
     constants[name] = moduleConstants;
  }];

  return constants;
}

ABI29_0_0RCT_EXPORT_METHOD(configureNextLayoutAnimation:(NSDictionary *)config
                  withCallback:(ABI29_0_0RCTResponseSenderBlock)callback
                  errorCallback:(__unused ABI29_0_0RCTResponseSenderBlock)errorCallback)
{
  ABI29_0_0RCTLayoutAnimationGroup *layoutAnimationGroup =
    [[ABI29_0_0RCTLayoutAnimationGroup alloc] initWithConfig:config
                                           callback:callback];

  [self addUIBlock:^(ABI29_0_0RCTUIManager *uiManager, __unused NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    [uiManager setNextLayoutAnimationGroup:layoutAnimationGroup];
  }];
}

- (void)rootViewForReactABI29_0_0Tag:(NSNumber *)ReactABI29_0_0Tag withCompletion:(void (^)(UIView *view))completion
{
  ABI29_0_0RCTAssertMainQueue();
  ABI29_0_0RCTAssert(completion != nil, @"Attempted to resolve rootView for tag %@ without a completion block", ReactABI29_0_0Tag);

  if (ReactABI29_0_0Tag == nil) {
    completion(nil);
    return;
  }

  ABI29_0_0RCTExecuteOnUIManagerQueue(^{
    NSNumber *rootTag = [self shadowViewForReactABI29_0_0Tag:ReactABI29_0_0Tag].rootView.ReactABI29_0_0Tag;
    ABI29_0_0RCTExecuteOnMainQueue(^{
      UIView *rootView = nil;
      if (rootTag != nil) {
        rootView = [self viewForReactABI29_0_0Tag:rootTag];
      }
      completion(rootView);
    });
  });
}

static UIView *_jsResponder;

+ (UIView *)JSResponder
{
  return _jsResponder;
}

@end

@implementation ABI29_0_0RCTBridge (ABI29_0_0RCTUIManager)

- (ABI29_0_0RCTUIManager *)uiManager
{
  return [self moduleForClass:[ABI29_0_0RCTUIManager class]];
}

@end
