// Copyright 2015-present 650 Industries. All rights reserved.

#import <ReactABI29_0_0/ABI29_0_0RCTEventEmitter.h>

@interface ABI29_0_0EXScopedEventEmitter : ABI29_0_0RCTEventEmitter

+ (NSString *)getExperienceIdFromEventEmitter:(id)eventEmitter;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithExperienceId:(NSString *)experienceId
               kernelServiceDelegate:(id)kernelServiceInstance
                              params:(NSDictionary *)params NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithExperienceId:(NSString *)experienceId
              kernelServiceDelegates:(NSDictionary *)kernelServiceInstances
                              params:(NSDictionary *)params NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) NSString *experienceId;

@end
