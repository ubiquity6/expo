// Copyright © 2018 650 Industries. All rights reserved.

#import <Foundation/Foundation.h>
#import <ABI29_0_0EXCore/ABI29_0_0EXModuleRegistry.h>

@interface ABI29_0_0EXModuleRegistryProvider : NSObject

@property (nonatomic, weak) id<ABI29_0_0EXModuleRegistryDelegate> moduleRegistryDelegate;

- (instancetype)initWithSingletonModuleClasses:(NSSet *)moduleClasses;
- (ABI29_0_0EXModuleRegistry *)moduleRegistryForExperienceId:(NSString *)experienceId;

@end
