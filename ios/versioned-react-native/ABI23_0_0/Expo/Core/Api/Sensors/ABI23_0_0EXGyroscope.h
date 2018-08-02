#import <CoreMotion/CoreMotion.h>
#import <ReactABI23_0_0/ABI23_0_0RCTBridge.h>
#import "ABI23_0_0EXScopedEventEmitter.h"

@protocol ABI23_0_0EXGyroscopeScopedModuleDelegate

- (void)sensorModuleDidSubscribeForGyroscopeUpdatesOfExperience:(NSString *)experienceId withHandler:(void (^)(NSDictionary *event))handlerBlock;
- (void)sensorModuleDidUnsubscribeForGyroscopeUpdatesOfExperience:(NSString *)experienceId;
- (void)setGyroscopeUpdateInterval:(NSTimeInterval)intervalMs;

@end

@interface ABI23_0_0EXGyroscope : ABI23_0_0EXScopedEventEmitter

@end
