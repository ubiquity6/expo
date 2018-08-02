// Copyright © 2018 650 Industries. All rights reserved.

#import "ABI29_0_0EXScopedModuleRegistry.h"

#import "ABI29_0_0EXScopedModuleRegistryAdapter.h"
#import "ABI29_0_0EXFileSystemBinding.h"
#import "ABI29_0_0EXSensorsManagerBinding.h"
#import "ABI29_0_0EXConstantsBinding.h"
#import "ABI29_0_0EXUnversioned.h"

#import "ABI29_0_0EXModuleRegistryBinding.h"

@implementation ABI29_0_0EXScopedModuleRegistryAdapter

- (NSArray<id<ABI29_0_0RCTBridgeModule>> *)extraModulesForParams:(NSDictionary *)params andExperience:(NSString *)experienceId withScopedModulesArray:(NSArray<id<ABI29_0_0RCTBridgeModule>> *)scopedModulesArray withKernelServices:(NSDictionary *)kernelServices
{
  ABI29_0_0EXModuleRegistry *moduleRegistry = [self.moduleRegistryProvider moduleRegistryForExperienceId:experienceId];
  NSDictionary<Class, id> *scopedModulesDictionary = [self dictionaryFromScopedModulesArray:scopedModulesArray];

  ABI29_0_0EXFileSystemBinding *fileSystemBinding = [[ABI29_0_0EXFileSystemBinding alloc] initWithScopedModuleDelegate:kernelServices[@"EXFileSystemManager"]];
  [moduleRegistry registerInternalModule:fileSystemBinding];

  ABI29_0_0EXSensorsManagerBinding *sensorsManagerBinding = [[ABI29_0_0EXSensorsManagerBinding alloc] initWithExperienceId:experienceId andKernelService:kernelServices[@"EXSensorManager"]];
  [moduleRegistry registerInternalModule:sensorsManagerBinding];
  
  ABI29_0_0EXConstantsBinding *constantsBinding = [[ABI29_0_0EXConstantsBinding alloc] initWithExperienceId:experienceId andParams:params];
  [moduleRegistry registerInternalModule:constantsBinding];

  NSArray<id<ABI29_0_0RCTBridgeModule>> *bridgeModules = [self extraModulesForModuleRegistry:moduleRegistry];
  return [bridgeModules arrayByAddingObject:[[ABI29_0_0EXModuleRegistryBinding alloc] initWithModuleRegistry:moduleRegistry]];
}

- (NSDictionary<Class, id> *)dictionaryFromScopedModulesArray:(NSArray<id<ABI29_0_0RCTBridgeModule>> *)scopedModulesArray
{
  NSMutableDictionary<Class, id> *scopedModulesDictionary = [NSMutableDictionary dictionaryWithCapacity:[scopedModulesArray count]];
  for (id<ABI29_0_0RCTBridgeModule> module in scopedModulesArray) {
    scopedModulesDictionary[(id<NSCopying>)[module class]] = module;
  }
  return scopedModulesDictionary;
}

@end
