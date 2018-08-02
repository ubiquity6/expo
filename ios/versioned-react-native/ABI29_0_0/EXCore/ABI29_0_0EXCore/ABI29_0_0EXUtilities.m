// Copyright © 2018 650 Industries. All rights reserved.

#import <ABI29_0_0EXCore/ABI29_0_0EXDefines.h>
#import <ABI29_0_0EXCore/ABI29_0_0EXUtilities.h>

@interface ABI29_0_0EXUtilities ()

@property (nonatomic, nullable, weak) ABI29_0_0EXModuleRegistry *moduleRegistry;

@end

@protocol ABI29_0_0EXUtilService

- (UIViewController *)currentViewController;

@end

@implementation ABI29_0_0EXUtilities

ABI29_0_0EX_REGISTER_MODULE();

+ (const NSArray<Protocol *> *)exportedInterfaces
{
  return @[@protocol(ABI29_0_0EXUtilitiesInterface)];
}

- (void)setModuleRegistry:(ABI29_0_0EXModuleRegistry *)moduleRegistry
{
  _moduleRegistry = moduleRegistry;
}

- (UIViewController *)currentViewController
{
  id<ABI29_0_0EXUtilService> utilService = [_moduleRegistry getSingletonModuleForName:@"Util"];

  if (utilService != nil) {
    // Uses currentViewController from ABI29_0_0EXUtilService that is a part of ExpoKit
    return [utilService currentViewController];
  }
  
  // If the app doesn't have ExpoKit - then do the same as ABI29_0_0RCTPresentedViewController() does
  UIViewController *controller = [[[UIApplication sharedApplication] keyWindow] rootViewController];
  UIViewController *presentedController = controller.presentedViewController;
  
  while (presentedController && ![presentedController isBeingDismissed]) {
    controller = presentedController;
    presentedController = controller.presentedViewController;
  }
  return controller;
}

+ (void)performSynchronouslyOnMainThread:(void (^)(void))block
{
  if ([NSThread isMainThread]) {
    block();
  } else {
    dispatch_sync(dispatch_get_main_queue(), block);
  }
}

// Copied from RN
+ (BOOL)isMainQueue
{
  static void *mainQueueKey = &mainQueueKey;
  static dispatch_once_t onceToken;
  
  dispatch_once(&onceToken, ^{
    dispatch_queue_set_specific(dispatch_get_main_queue(),
                                mainQueueKey, mainQueueKey, NULL);
  });
  
  return dispatch_get_specific(mainQueueKey) == mainQueueKey;
}

// Copied from RN
+ (void)unsafeExecuteOnMainQueueOnceSync:(dispatch_once_t *)onceToken block:(dispatch_block_t)block
{
  // The solution was borrowed from a post by Ben Alpert:
  // https://benalpert.com/2014/04/02/dispatch-once-initialization-on-the-main-thread.html
  // See also: https://www.mikeash.com/pyblog/friday-qa-2014-06-06-secrets-of-dispatch_once.html
  if ([self isMainQueue]) {
    dispatch_once(onceToken, block);
  } else {
    if (DISPATCH_EXPECT(*onceToken == 0L, NO)) {
      dispatch_sync(dispatch_get_main_queue(), ^{
        dispatch_once(onceToken, block);
      });
    }
  }
}

// Copied from RN
+ (CGFloat)screenScale
{
  static dispatch_once_t onceToken;
  static CGFloat scale;
  
  [self unsafeExecuteOnMainQueueOnceSync:&onceToken block:^{
      scale = [UIScreen mainScreen].scale;
  }];
  
  return scale;
}

@end
