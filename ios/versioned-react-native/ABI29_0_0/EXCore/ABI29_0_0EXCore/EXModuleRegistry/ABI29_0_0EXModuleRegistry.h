// Copyright © 2018 650 Industries. All rights reserved.

#import <Foundation/Foundation.h>
#import <ABI29_0_0EXCore/ABI29_0_0EXInternalModule.h>
#import <ABI29_0_0EXCore/ABI29_0_0EXExportedModule.h>
#import <ABI29_0_0EXCore/ABI29_0_0EXViewManager.h>
#import <ABI29_0_0EXCore/ABI29_0_0EXSingletonModule.h>
#import <ABI29_0_0EXCore/ABI29_0_0EXModuleRegistryDelegate.h>

@interface ABI29_0_0EXModuleRegistry : NSObject

@property (nonatomic, readonly) NSString *experienceId;

- (instancetype)initWithInternalModules:(NSSet<id<ABI29_0_0EXInternalModule>> *)internalModules
                        exportedModules:(NSSet<ABI29_0_0EXExportedModule *> *)exportedModules
                           viewManagers:(NSSet<ABI29_0_0EXViewManager *> *)viewManagers
                       singletonModules:(NSSet<ABI29_0_0EXSingletonModule *> *)singletonModules;

- (void)registerInternalModule:(id<ABI29_0_0EXInternalModule>)internalModule;
- (void)registerExportedModule:(ABI29_0_0EXExportedModule *)exportedModule;
- (void)registerViewManager:(ABI29_0_0EXViewManager *)viewManager;

- (void)setDelegate:(id<ABI29_0_0EXModuleRegistryDelegate>)delegate;

- (id<ABI29_0_0EXInternalModule>)unregisterInternalModuleForProtocol:(Protocol *)protocol;

// Call this method once all the modules are set up and registered in the registry.
- (void)initialize;

- (ABI29_0_0EXExportedModule *)getExportedModuleForName:(NSString *)name;
- (ABI29_0_0EXExportedModule *)getExportedModuleOfClass:(Class)moduleClass;
- (id)getModuleImplementingProtocol:(Protocol *)protocol;
- (ABI29_0_0EXSingletonModule *)getSingletonModuleForName:(NSString *)singletonModuleName;

- (NSArray<id<ABI29_0_0EXInternalModule>> *)getAllInternalModules;
- (NSArray<ABI29_0_0EXExportedModule *> *)getAllExportedModules;
- (NSArray<ABI29_0_0EXViewManager *> *)getAllViewManagers;
- (NSArray<ABI29_0_0EXSingletonModule *> *)getAllSingletonModules;

@end
