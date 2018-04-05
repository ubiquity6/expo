// Copyright 2015-present 650 Industries. All rights reserved.

#import <ReactABI25_0_0/ABI25_0_0RCTEventEmitter.h>

@interface ABI25_0_0EXScopedEventEmitter : ABI25_0_0RCTEventEmitter

+ (NSString *)getExperienceIdFromEventEmitter:(id)eventEmitter;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithExperienceId:(NSString *)experienceId
               kernelServiceDelegate:(id)kernelServiceInstance
                              params:(NSDictionary *)params NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) NSString *experienceId;

@end
