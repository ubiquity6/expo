// Copyright 2015-present 650 Industries. All rights reserved.

#import "ABI26_0_0EXAppState.h"
#import "ABI26_0_0EXDevSettings.h"
#import "ABI26_0_0EXDisabledDevLoadingView.h"
#import "ABI26_0_0EXDisabledDevMenu.h"
#import "ABI26_0_0EXDisabledRedBox.h"
#import "ABI26_0_0EXFileSystem.h"
#import "ABI26_0_0EXVersionManager.h"
#import "ABI26_0_0EXStatusBarManager.h"
#import "ABI26_0_0EXUnversioned.h"
#import "ABI26_0_0EXTest.h"

#import <ReactABI26_0_0/ABI26_0_0RCTAssert.h>
#import <ReactABI26_0_0/ABI26_0_0RCTBridge.h>
#import <ReactABI26_0_0/ABI26_0_0RCTBridge+Private.h>
#import <ReactABI26_0_0/ABI26_0_0RCTDevMenu.h>
#import <ReactABI26_0_0/ABI26_0_0RCTDevSettings.h>
#import <ReactABI26_0_0/ABI26_0_0RCTExceptionsManager.h>
#import <ReactABI26_0_0/ABI26_0_0RCTLog.h>
#import <ReactABI26_0_0/ABI26_0_0RCTModuleData.h>
#import <ReactABI26_0_0/ABI26_0_0RCTUtils.h>

#import <ReactABI26_0_0/ABI26_0_0RCTAsyncLocalStorage.h>

#import <objc/message.h>

static NSNumber *ABI26_0_0EXVersionManagerIsFirstLoad;

// used for initializing scoped modules which don't tie in to any kernel service.
#define ABI26_0_0EX_KERNEL_SERVICE_NONE @"ABI26_0_0EXKernelServiceNone"

// this is needed because ABI26_0_0RCTPerfMonitor does not declare a public interface
// anywhere that we can import.
@interface ABI26_0_0RCTPerfMonitorDevSettingsHack <NSObject>

- (void)hide;
- (void)show;

@end

static NSMutableDictionary<NSString *, NSString *> *ABI26_0_0EXScopedModuleClasses;
void ABI26_0_0EXRegisterScopedModule(Class, NSString *);
void ABI26_0_0EXRegisterScopedModule(Class moduleClass, NSString *kernelServiceClassName)
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    ABI26_0_0EXScopedModuleClasses = [NSMutableDictionary dictionary];
  });
  
  NSString *unversionedKernelServiceClassName;
  if ([kernelServiceClassName isEqualToString:@"nil"]) {
    unversionedKernelServiceClassName = ABI26_0_0EX_KERNEL_SERVICE_NONE;
  } else {
    unversionedKernelServiceClassName = [@"EX" stringByAppendingString:kernelServiceClassName];
  }
  NSString *moduleClassName = NSStringFromClass(moduleClass);
  if (moduleClassName) {
    ABI26_0_0EXScopedModuleClasses[moduleClassName] = unversionedKernelServiceClassName;
  }
}

@interface ABI26_0_0EXVersionManager ()

// is this the first time this ABI has been touched at runtime?
@property (nonatomic, assign) BOOL isFirstLoad;

@end

@implementation ABI26_0_0EXVersionManager

- (instancetype)initWithFatalHandler:(void (^)(NSError *))fatalHandler
                         logFunction:(void (^)(NSInteger, NSInteger, NSString *, NSNumber *, NSString *))logFunction
                        logThreshold:(NSInteger)threshold
{
  if (self = [super init]) {
    [self configureABIWithFatalHandler:fatalHandler logFunction:logFunction logThreshold:threshold];
  }
  return self;
}

- (void)bridgeWillStartLoading:(id)bridge
{
  // manually send a "start loading" notif, since the real one happened uselessly inside the ABI26_0_0RCTBatchedBridge constructor
  [[NSNotificationCenter defaultCenter]
   postNotificationName:ABI26_0_0RCTJavaScriptWillStartLoadingNotification object:bridge];
}

- (void)bridgeFinishedLoading
{

}

- (void)bridgeDidForeground
{
  if (_isFirstLoad) {
    _isFirstLoad = NO; // in case the same VersionManager instance is used between multiple bridge loads
  } else {
    // some state is shared between bridges, for example status bar
    [self resetSharedState];
  }
}

- (void)bridgeDidBackground
{
  [self saveSharedState];
}

- (void)saveSharedState
{

}

- (void)resetSharedState
{

}

- (void)invalidate
{

}

- (NSDictionary<NSString *, NSString *> *)devMenuItemsForBridge:(id)bridge
{
  ABI26_0_0RCTDevSettings *devSettings = [self _moduleInstanceForBridge:bridge named:@"DevSettings"];
  BOOL isDevModeEnabled = [self _isDevModeEnabledForBridge:bridge];
  NSMutableDictionary *items = [@{
    @"dev-reload": @{ @"label": @"Reload JS Bundle", @"isEnabled": @YES },
    @"dev-inspector": @{ @"label": @"Toggle Element Inspector", @"isEnabled": @YES },
  } mutableCopy];
  if (devSettings.isRemoteDebuggingAvailable && isDevModeEnabled) {
    items[@"dev-remote-debug"] = @{
      @"label": (devSettings.isDebuggingRemotely) ? @"Stop Remote Debugging" : @"Debug Remote JS",
      @"isEnabled": @YES
    };
  } else {
    items[@"dev-remote-debug"] =  @{ @"label": @"Remote Debugger Unavailable", @"isEnabled": @NO };
  }
  if (devSettings.isLiveReloadAvailable && !devSettings.isHotLoadingEnabled && isDevModeEnabled) {
    items[@"dev-live-reload"] = @{
      @"label": (devSettings.isLiveReloadEnabled) ? @"Disable Live Reload" : @"Enable Live Reload",
      @"isEnabled": @YES,
    };
#ifdef ABI26_0_0EX_ENABLE_UNSAFE_SYSTRACE
    items[@"dev-profiler"] = @{
      @"label": (devSettings.isProfilingEnabled) ? @"Stop Systrace" : @"Start Systrace",
      @"isEnabled": @YES,
    };
#endif
  } else {
    NSMutableDictionary *liveReloadItem = [@{ @"label": @"Live Reload Unavailable", @"isEnabled": @NO } mutableCopy];
    if (devSettings.isHotLoadingEnabled) {
      liveReloadItem[@"detail"] = @"You can't use Live Reload and Hot Reloading at the same time. Disable Hot Reloading to use Live Reload.";
    }
    items[@"dev-live-reload"] =  liveReloadItem;
  }
  if (devSettings.isHotLoadingAvailable && !devSettings.isLiveReloadEnabled && isDevModeEnabled) {
    items[@"dev-hmr"] = @{
      @"label": (devSettings.isHotLoadingEnabled) ? @"Disable Hot Reloading" : @"Enable Hot Reloading",
      @"isEnabled": @YES,
    };
  } else {
    NSMutableDictionary *hmrItem = [@{ @"label": @"Hot Reloading Unavailable", @"isEnabled": @NO } mutableCopy];
    if (devSettings.isLiveReloadEnabled) {
      hmrItem[@"detail"] = @"You can't use Live Reload and Hot Reloading at the same time. Disable Live Reload to use Hot Reloading.";
    }
    items[@"dev-hmr"] =  hmrItem;
  }
  if (devSettings.isJSCSamplingProfilerAvailable && isDevModeEnabled) {
    items[@"dev-jsc-profiler"] = @{ @"label": @"Start / Stop JS Sampling Profiler", @"isEnabled": @YES };
  }
  id perfMonitor = [self _moduleInstanceForBridge:bridge named:@"PerfMonitor"];
  if (perfMonitor) {
    items[@"dev-perf-monitor"] = @{
      @"label": devSettings.isPerfMonitorShown ? @"Hide Perf Monitor" : @"Show Perf Monitor",
      @"isEnabled": @YES,
    };
  }

  return items;
}

- (void)selectDevMenuItemWithKey:(NSString *)key onBridge:(id)bridge
{
  ABI26_0_0RCTAssertMainQueue();
  ABI26_0_0RCTDevSettings *devSettings = [self _moduleInstanceForBridge:bridge named:@"DevSettings"];
  if ([key isEqualToString:@"dev-reload"]) {
    [bridge reload];
  } else if ([key isEqualToString:@"dev-remote-debug"]) {
    devSettings.isDebuggingRemotely = !devSettings.isDebuggingRemotely;
  } else if ([key isEqualToString:@"dev-live-reload"]) {
    devSettings.isLiveReloadEnabled = !devSettings.isLiveReloadEnabled;
  } else if ([key isEqualToString:@"dev-profiler"]) {
    devSettings.isProfilingEnabled = !devSettings.isProfilingEnabled;
  } else if ([key isEqualToString:@"dev-hmr"]) {
    devSettings.isHotLoadingEnabled = !devSettings.isHotLoadingEnabled;
  } else if ([key isEqualToString:@"dev-jsc-profiler"]) {
    [devSettings toggleJSCSamplingProfiler];
  } else if ([key isEqualToString:@"dev-inspector"]) {
    [devSettings toggleElementInspector];
  } else if ([key isEqualToString:@"dev-perf-monitor"]) {
    id perfMonitor = [self _moduleInstanceForBridge:bridge named:@"PerfMonitor"];
    if (perfMonitor) {
      if (devSettings.isPerfMonitorShown) {
        [perfMonitor hide];
        devSettings.isPerfMonitorShown = NO;
      } else {
        [perfMonitor show];
        devSettings.isPerfMonitorShown = YES;
      }
    }
  }
}

- (void)showDevMenuForBridge:(id)bridge
{
  ABI26_0_0RCTAssertMainQueue();
  id devMenu = [self _moduleInstanceForBridge:bridge named:@"DevMenu"];
  // respondsToSelector: check is required because it's possible this bridge
  // was instantiated with a `disabledDevMenu` instance and the gesture preference was recently updated.
  if ([devMenu respondsToSelector:@selector(show)]) {
    [((ABI26_0_0RCTDevMenu *)devMenu) show];
  }
}

- (void)disableRemoteDebuggingForBridge:(id)bridge
{
  ABI26_0_0RCTDevSettings *devSettings = [self _moduleInstanceForBridge:bridge named:@"DevSettings"];
  devSettings.isDebuggingRemotely = NO;
}

- (void)toggleElementInspectorForBridge:(id)bridge
{
  ABI26_0_0RCTDevSettings *devSettings = [self _moduleInstanceForBridge:bridge named:@"DevSettings"];
  [devSettings toggleElementInspector];
}


#pragma mark - internal

- (BOOL)_isDevModeEnabledForBridge:(id)bridge
{
  return ([ABI26_0_0RCTGetURLQueryParam([bridge bundleURL], @"dev") boolValue]);
}

- (id<ABI26_0_0RCTBridgeModule>)_moduleInstanceForBridge:(id)bridge named:(NSString *)name
{
  if ([bridge respondsToSelector:@selector(batchedBridge)]) {
    bridge = [bridge batchedBridge];
  }
  ABI26_0_0RCTModuleData *data = [bridge moduleDataForName:name];
  if (data) {
    return [data instance];
  }
  return nil;
}

- (void)configureABIWithFatalHandler:(void (^)(NSError *))fatalHandler
                         logFunction:(void (^)(NSInteger, NSInteger, NSString *, NSNumber *, NSString *))logFunction
                        logThreshold:(NSInteger)threshold
{
  if (ABI26_0_0EXVersionManagerIsFirstLoad == nil) {
    // first time initializing this RN version at runtime
    _isFirstLoad = YES;
  }
  ABI26_0_0EXVersionManagerIsFirstLoad = @(NO);
  ABI26_0_0RCTSetFatalHandler(fatalHandler);
  ABI26_0_0RCTSetLogThreshold(threshold);
  ABI26_0_0RCTSetLogFunction(logFunction);
}

/**
 *  Expected params:
 *    NSDictionary *manifest
 *    NSDictionary *constants
 *    NSURL *initialUri
 *    @BOOL isDeveloper
 *    @BOOL isStandardDevMenuAllowed
 *    @ABI26_0_0EXTestEnvironment testEnvironment
 *    NSDictionary *services
 *
 * Kernel-only:
 *    ABI26_0_0EXKernel *kernel
 *    NSArray *supportedSdkVersions
 *    id exceptionsManagerDelegate
 */
- (NSArray *)extraModulesWithParams:(NSDictionary *)params
{
  BOOL isDeveloper = [params[@"isDeveloper"] boolValue];
  NSDictionary *manifest = params[@"manifest"];
  NSString *experienceId = manifest[@"id"];
  NSDictionary *services = params[@"services"];
  NSString *localStorageDirectory = [[ABI26_0_0EXFileSystem documentDirectoryForExperienceId:experienceId] stringByAppendingPathComponent:@"RCTAsyncLocalStorage"];

  NSMutableArray *extraModules = [NSMutableArray arrayWithArray:
                                  @[
                                    [[ABI26_0_0EXAppState alloc] init],
                                    [[ABI26_0_0EXDevSettings alloc] initWithExperienceId:experienceId isDevelopment:isDeveloper],
                                    [[ABI26_0_0EXDisabledDevLoadingView alloc] init],
                                    [[ABI26_0_0EXStatusBarManager alloc] init],
                                    [[ABI26_0_0RCTAsyncLocalStorage alloc] initWithStorageDirectory:localStorageDirectory],
                                    ]];
  
  // add scoped modules
  [extraModules addObjectsFromArray:[self _newScopedModulesWithExperienceId:experienceId services:services params:params]];

  id exceptionsManagerDelegate = params[@"exceptionsManagerDelegate"];
  if (exceptionsManagerDelegate) {
    ABI26_0_0RCTExceptionsManager *exceptionsManager = [[ABI26_0_0RCTExceptionsManager alloc] initWithDelegate:exceptionsManagerDelegate];
    [extraModules addObject:exceptionsManager];
  } else {
    ABI26_0_0RCTLogWarn(@"No exceptions manager provided when building extra modules for bridge.");
  }
  
  if (params[@"testEnvironment"]) {
    ABI26_0_0EXTestEnvironment testEnvironment = (ABI26_0_0EXTestEnvironment)[params[@"testEnvironment"] unsignedIntegerValue];
    if (testEnvironment != ABI26_0_0EXTestEnvironmentNone) {
      ABI26_0_0EXTest *testModule = [[ABI26_0_0EXTest alloc] initWithEnvironment:testEnvironment];
      [extraModules addObject:testModule];
    }
  }
  
  /** todo: ben
  if (params[@"kernel"]) {
    ABI26_0_0EXHomeModule *homeModule = [[ABI26_0_0EXHomeModule alloc] initWithExperienceId:experienceId
                                                    kernelServiceDelegate:services[@"EXHomeModuleManager"]
                                                                   params:params];
    [extraModules addObject:homeModule];
  } */

  if ([params[@"isStandardDevMenuAllowed"] boolValue] && isDeveloper) {
    [extraModules addObject:[[ABI26_0_0RCTDevMenu alloc] init]];
  } else {
    // non-kernel, or non-development kernel, uses expo menu instead of ABI26_0_0RCTDevMenu
    [extraModules addObject:[[ABI26_0_0EXDisabledDevMenu alloc] init]];
  }
  if (!isDeveloper) {
    // user-facing (not debugging).
    // additionally disable ABI26_0_0RCTRedBox
    [extraModules addObject:[[ABI26_0_0EXDisabledRedBox alloc] init]];
  }
  return extraModules;
}

- (NSArray *)_newScopedModulesWithExperienceId: (NSString *)experienceId services:(NSDictionary *)services params:(NSDictionary *)params
{
  NSMutableArray *result = [NSMutableArray array];
  if (ABI26_0_0EXScopedModuleClasses) {
    [ABI26_0_0EXScopedModuleClasses enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull scopedModuleClassName, NSString * _Nonnull kernelServiceClassName, BOOL * _Nonnull stop) {
      id service = ([kernelServiceClassName isEqualToString:ABI26_0_0EX_KERNEL_SERVICE_NONE]) ? nil : services[kernelServiceClassName];
      Class scopedModuleClass = NSClassFromString(scopedModuleClassName);
      id scopedModule = [[scopedModuleClass alloc] initWithExperienceId:experienceId kernelServiceDelegate:service params:params];
      if (scopedModule) {
        [result addObject:scopedModule];
      }
    }];
  }
  return result;
}

@end
