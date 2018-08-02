// Copyright 2015-present 650 Industries. All rights reserved.

#import "ABI29_0_0EXScopedBridgeModule.h"

@implementation ABI29_0_0EXScopedBridgeModule

+ (NSString *)moduleName
{
  NSAssert(NO, @"ABI29_0_0EXScopedBridgeModule is abstract, you should only export subclasses to the bridge.");
  return @"ExponentScopedBridgeModule";
}

- (instancetype)initWithExperienceId:(NSString *)experienceId kernelServiceDelegate:(id)kernelServiceInstance params:(NSDictionary *)params
{
  if (self = [super init]) {
    _experienceId = experienceId;
  }
  return self;
}

- (instancetype)initWithExperienceId:(NSString *)experienceId kernelServiceDelegates:(NSDictionary *)kernelServiceInstances params:(NSDictionary *)params
{
  if (self = [super init]) {
    _experienceId = experienceId;
  }
  return self;
}

@end
