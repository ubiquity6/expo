// Copyright © 2018 650 Industries. All rights reserved.

#import <Foundation/Foundation.h>
#import <ABI29_0_0EXCore/ABI29_0_0EXInternalModule.h>
#import <ABI29_0_0EXSensorsInterface/ABI29_0_0EXAccelerometerInterface.h>
#import <ABI29_0_0EXSensorsInterface/ABI29_0_0EXDeviceMotionInterface.h>
#import <ABI29_0_0EXSensorsInterface/ABI29_0_0EXGyroscopeInterface.h>
#import <ABI29_0_0EXSensorsInterface/ABI29_0_0EXMagnetometerInterface.h>
#import <ABI29_0_0EXSensorsInterface/ABI29_0_0EXMagnetometerUncalibratedInterface.h>

@protocol ABI29_0_0EXSensorsManagerBindingDelegate

- (void)sensorModuleDidSubscribeForAccelerometerUpdatesOfExperience:(NSString *)experienceId withHandler:(void (^)(NSDictionary *event))handlerBlock;
- (void)sensorModuleDidUnsubscribeForAccelerometerUpdatesOfExperience:(NSString *)experienceId;
- (void)setAccelerometerUpdateInterval:(NSTimeInterval)intervalMs;

- (float)getGravity;
- (void)sensorModuleDidSubscribeForDeviceMotionUpdatesOfExperience:(NSString *)experienceId withHandler:(void (^)(NSDictionary *event))handlerBlock;
- (void)sensorModuleDidUnsubscribeForDeviceMotionUpdatesOfExperience:(NSString *)experienceId;
- (void)setDeviceMotionUpdateInterval:(NSTimeInterval)intervalMs;

- (void)sensorModuleDidSubscribeForGyroscopeUpdatesOfExperience:(NSString *)experienceId withHandler:(void (^)(NSDictionary *event))handlerBlock;
- (void)sensorModuleDidUnsubscribeForGyroscopeUpdatesOfExperience:(NSString *)experienceId;
- (void)setGyroscopeUpdateInterval:(NSTimeInterval)intervalMs;

- (void)sensorModuleDidSubscribeForMagnetometerUpdatesOfExperience:(NSString *)experienceId withHandler:(void (^)(NSDictionary *event))handlerBlock;
- (void)sensorModuleDidUnsubscribeForMagnetometerUpdatesOfExperience:(NSString *)experienceId;
- (void)setMagnetometerUpdateInterval:(NSTimeInterval)intervalMs;

- (void)sensorModuleDidSubscribeForMagnetometerUncalibratedUpdatesOfExperience:(NSString *)experienceId
                                                       withHandler:(void (^)(NSDictionary *event))handlerBlock;
- (void)sensorModuleDidUnsubscribeForMagnetometerUncalibratedUpdatesOfExperience:(NSString *)experienceId;
- (void)setMagnetometerUncalibratedUpdateInterval:(NSTimeInterval)intervalMs;

@end

@interface ABI29_0_0EXSensorsManagerBinding : NSObject <ABI29_0_0EXInternalModule, ABI29_0_0EXAccelerometerInterface, ABI29_0_0EXDeviceMotionInterface, ABI29_0_0EXGyroscopeInterface, ABI29_0_0EXMagnetometerInterface, ABI29_0_0EXMagnetometerUncalibratedInterface>

- (instancetype)initWithExperienceId:(NSString *)experienceId andKernelService:(id<ABI29_0_0EXSensorsManagerBindingDelegate>)kernelService;

- (void)sensorModuleDidSubscribeForAccelerometerUpdates:(id)scopedSensorModule withHandler:(void (^)(NSDictionary *))handlerBlock;
- (void)sensorModuleDidSubscribeForDeviceMotionUpdates:(id)scopedSensorModule withHandler:(void (^)(NSDictionary *))handlerBlock;
- (void)sensorModuleDidSubscribeForGyroscopeUpdates:(id)scopedSensorModule withHandler:(void (^)(NSDictionary *))handlerBlock;
- (void)sensorModuleDidSubscribeForMagnetometerUncalibratedUpdates:(id)scopedSensorModule withHandler:(void (^)(NSDictionary *))handlerBlock;
- (void)sensorModuleDidSubscribeForMagnetometerUpdates:(id)scopedSensorModule withHandler:(void (^)(NSDictionary *))handlerBlock;
- (void)sensorModuleDidUnsubscribeForAccelerometerUpdates:(id)scopedSensorModule;
- (void)sensorModuleDidUnsubscribeForDeviceMotionUpdates:(id)scopedSensorModule;
- (void)sensorModuleDidUnsubscribeForGyroscopeUpdates:(id)scopedSensorModule;
- (void)sensorModuleDidUnsubscribeForMagnetometerUncalibratedUpdates:(id)scopedSensorModule;
- (void)sensorModuleDidUnsubscribeForMagnetometerUpdates:(id)scopedSensorModule;
- (void)setAccelerometerUpdateInterval:(NSTimeInterval)intervalMs;
- (void)setDeviceMotionUpdateInterval:(NSTimeInterval)intervalMs;
- (void)setGyroscopeUpdateInterval:(NSTimeInterval)intervalMs;
- (void)setMagnetometerUncalibratedUpdateInterval:(NSTimeInterval)intervalMs;
- (void)setMagnetometerUpdateInterval:(NSTimeInterval)intervalMs;

@end
