// Copyright 2015-present 650 Industries. All rights reserved.

#import <ReactABI26_0_0/ABI26_0_0RCTEventEmitter.h>

@interface ABI26_0_0EXScopedEventEmitter : ABI26_0_0RCTEventEmitter

+ (NSString *)getExperienceIdFromEventEmitter:(id)eventEmitter;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithExperienceId:(NSString *)experienceId
               kernelServiceDelegate:(id)kernelServiceInstance
                              params:(NSDictionary *)params NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) NSString *experienceId;

@end
