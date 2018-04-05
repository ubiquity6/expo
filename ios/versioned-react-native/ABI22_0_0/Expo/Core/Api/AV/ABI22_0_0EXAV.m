// Copyright 2017-present 650 Industries. All rights reserved.

#import <AVFoundation/AVFoundation.h>

#import <ReactABI22_0_0/ABI22_0_0RCTUIManager.h>
#import <ReactABI22_0_0/ABI22_0_0RCTUtils.h>

#import "ABI22_0_0EXAV.h"
#import "ABI22_0_0EXAVPlayerData.h"
#import "ABI22_0_0EXFileSystem.h"
#import "ABI22_0_0EXVideoView.h"
#import "ABI22_0_0EXUnversioned.h"

NSString *const ABI22_0_0EXAudioRecordingOptionsKey = @"ios";
NSString *const ABI22_0_0EXAudioRecordingOptionExtensionKey = @"extension";
NSString *const ABI22_0_0EXAudioRecordingOptionOutputFormatKey = @"outputFormat";
NSString *const ABI22_0_0EXAudioRecordingOptionAudioQualityKey = @"audioQuality";
NSString *const ABI22_0_0EXAudioRecordingOptionSampleRateKey = @"sampleRate";
NSString *const ABI22_0_0EXAudioRecordingOptionNumberOfChannelsKey = @"numberOfChannels";
NSString *const ABI22_0_0EXAudioRecordingOptionBitRateKey = @"bitRate";
NSString *const ABI22_0_0EXAudioRecordingOptionBitRateStrategyKey = @"bitRateStrategy";
NSString *const ABI22_0_0EXAudioRecordingOptionBitDepthHintKey = @"bitDepthHint";
NSString *const ABI22_0_0EXAudioRecordingOptionLinearPCMBitDepthKey = @"linearPCMBitDepth";
NSString *const ABI22_0_0EXAudioRecordingOptionLinearPCMIsBigEndianKey = @"linearPCMIsBigEndian";
NSString *const ABI22_0_0EXAudioRecordingOptionLinearPCMIsFloatKey = @"linearPCMIsFloat";

@interface ABI22_0_0EXAV ()

@property (nonatomic, weak) id kernelAudioSessionManagerDelegate;

@property (nonatomic, assign) BOOL audioIsEnabled;
@property (nonatomic, assign) ABI22_0_0EXAVAudioSessionMode currentAudioSessionMode;
@property (nonatomic, assign) BOOL isBackgrounded;

@property (nonatomic, assign) ABI22_0_0EXAudioInterruptionMode audioInterruptionMode;
@property (nonatomic, assign) BOOL playsInSilentMode;
@property (nonatomic, assign) BOOL allowsAudioRecording;

@property (nonatomic, assign) int soundDictionaryKeyCount;
@property (nonatomic, strong) NSMutableDictionary <NSNumber *, ABI22_0_0EXAVPlayerData *> *soundDictionary;
@property (nonatomic, strong) NSMutableSet <NSObject<ABI22_0_0EXAVObject> *> *videoSet;

@property (nonatomic, strong) NSString *audioRecorderFilename;
@property (nonatomic, strong) NSDictionary *audioRecorderSettings;
@property (nonatomic, strong) AVAudioRecorder *audioRecorder;
@property (nonatomic, assign) BOOL audioRecorderIsPreparing;
@property (nonatomic, assign) BOOL audioRecorderShouldBeginRecording;
@property (nonatomic, assign) int audioRecorderDurationMillis;

@end

@implementation ABI22_0_0EXAV

@synthesize methodQueue = _methodQueue;

- (instancetype)initWithExperienceId:(NSString *)experienceId kernelServiceDelegate:(id)kernelServiceInstance params:(NSDictionary *)params
{
  if ((self = [super initWithExperienceId:experienceId kernelServiceDelegate:kernelServiceInstance params:params])) {
    _audioIsEnabled = YES;
    _currentAudioSessionMode = ABI22_0_0EXAVAudioSessionModeInactive;
    _isBackgrounded = NO;
    
    _audioInterruptionMode = ABI22_0_0EXAudioInterruptionModeMixWithOthers;
    _playsInSilentMode = false;
    _allowsAudioRecording = false;
    
    _soundDictionaryKeyCount = 0;
    _soundDictionary = [NSMutableDictionary new];
    _videoSet = [NSMutableSet new];
    
    _audioRecorderFilename = nil;
    _audioRecorderSettings = nil;
    _audioRecorder = nil;
    _audioRecorderIsPreparing = false;
    _audioRecorderShouldBeginRecording = false;
    _audioRecorderDurationMillis = 0;
    
    _kernelAudioSessionManagerDelegate = kernelServiceInstance;
    [_kernelAudioSessionManagerDelegate scopedModuleDidForeground:self];
  }
  
  return self;
}

#pragma mark - Expo experience lifecycle

- (void)setBridge:(ABI22_0_0RCTBridge *)bridge
{
  [super setBridge:bridge];
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(_bridgeDidForeground:)
                                               name:@"EXKernelBridgeDidForegroundNotification"
                                             object:self.bridge];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(_bridgeDidBackground:)
                                               name:@"EXKernelBridgeDidBackgroundNotification"
                                             object:self.bridge];
}

- (void)_bridgeDidForeground:(NSNotification *)notification
{
  [_kernelAudioSessionManagerDelegate scopedModuleDidForeground:self];
  _isBackgrounded = NO;
  
  [self _runBlockForAllAVObjects:^(NSObject<ABI22_0_0EXAVObject> *exAVObject) {
    [exAVObject bridgeDidForeground:notification];
  }];
}

- (void)_bridgeDidBackground:(NSNotification *)notification
{
  _isBackgrounded = YES;
  [self _deactivateAudioSession]; // This will pause all players and stop all recordings
  
  [self _runBlockForAllAVObjects:^(NSObject<ABI22_0_0EXAVObject> *exAVObject) {
    [exAVObject bridgeDidBackground:notification];
  }];
  [_kernelAudioSessionManagerDelegate scopedModuleDidBackground:self];
}

#pragma mark - Global audio state control API

- (void)registerVideoForAudioLifecycle:(NSObject<ABI22_0_0EXAVObject> *)video
{
  [_videoSet addObject:video];
}

- (void)unregisterVideoForAudioLifecycle:(NSObject<ABI22_0_0EXAVObject> *)video
{
  [_videoSet removeObject:video];
}

- (void)_runBlockForAllAVObjects:(void (^)(NSObject<ABI22_0_0EXAVObject> *exAVObject))block
{
  for (ABI22_0_0EXAVPlayerData *data in [_soundDictionary allValues]) {
    block(data);
  }
  for (NSObject<ABI22_0_0EXAVObject> *video in [_videoSet allObjects]) {
    block(video);
  }
}

// This method is placed here so that it is easily referrable from _setAudioSessionCategoryForAudioMode.
- (NSError *)_setAudioMode:(NSDictionary *)mode
{
  BOOL playsInSilentMode = ((NSNumber *)mode[@"playsInSilentModeIOS"]).boolValue;
  ABI22_0_0EXAudioInterruptionMode interruptionMode = ((NSNumber *)mode[@"interruptionModeIOS"]).intValue;
  BOOL allowsRecording = ((NSNumber *)mode[@"allowsRecordingIOS"]).boolValue;
  
  if (!playsInSilentMode && interruptionMode == ABI22_0_0EXAudioInterruptionModeDuckOthers) {
    return ABI22_0_0RCTErrorWithMessage(@"Impossible audio mode: playsInSilentMode and duckOthers cannot both be set on iOS.");
  } else if (!playsInSilentMode && allowsRecording) {
    return ABI22_0_0RCTErrorWithMessage(@"Impossible audio mode: playsInSilentMode and allowsRecording cannot both be set on iOS.");
  } else {
    if (!allowsRecording) {
      if (_audioRecorder && [_audioRecorder isRecording]) {
        [_audioRecorder pause];
      }
    }
    
    _playsInSilentMode = playsInSilentMode;
    _audioInterruptionMode = interruptionMode;
    _allowsAudioRecording = allowsRecording;
    
    if (_currentAudioSessionMode != ABI22_0_0EXAVAudioSessionModeInactive) {
      return [self _updateAudioSessionCategoryForAudioSessionMode:[self _getAudioSessionModeRequired]];
    }
    return nil;
  }
}

- (NSError *)_updateAudioSessionCategoryForAudioSessionMode:(ABI22_0_0EXAVAudioSessionMode)audioSessionMode
{
  NSError *error;
  ABI22_0_0EXAudioInterruptionMode activeInterruptionMode = audioSessionMode == ABI22_0_0EXAVAudioSessionModeActiveMuted
    ? ABI22_0_0EXAudioInterruptionModeMixWithOthers : _audioInterruptionMode;
  
  if (!_playsInSilentMode) {
    // _allowsRecording is guaranteed to be false, and _interruptionMode is guaranteed to not be ABI22_0_0EXAudioInterruptionModeDuckOthers (see above)
    if (_audioInterruptionMode == ABI22_0_0EXAudioInterruptionModeDoNotMix) {
      error = [_kernelAudioSessionManagerDelegate setCategory:AVAudioSessionCategorySoloAmbient withOptions:0 forScopedModule:self];
    } else {
      error = [_kernelAudioSessionManagerDelegate setCategory:AVAudioSessionCategoryAmbient withOptions:0 forScopedModule:self];
    }
  } else {
    NSString *category = _allowsAudioRecording ? AVAudioSessionCategoryPlayAndRecord : AVAudioSessionCategoryPlayback;
    switch (activeInterruptionMode) {
      case ABI22_0_0EXAudioInterruptionModeDoNotMix:
        error = [_kernelAudioSessionManagerDelegate setCategory:category withOptions:0 forScopedModule:self];
        break;
      case ABI22_0_0EXAudioInterruptionModeDuckOthers:
        error = [_kernelAudioSessionManagerDelegate setCategory:category withOptions:AVAudioSessionCategoryOptionDuckOthers forScopedModule:self];
        break;
      case ABI22_0_0EXAudioInterruptionModeMixWithOthers:
      default:
        error = [_kernelAudioSessionManagerDelegate setCategory:category withOptions:AVAudioSessionCategoryOptionMixWithOthers forScopedModule:self];
        break;
    }
  }
  return error;
}

- (ABI22_0_0EXAVAudioSessionMode)_getAudioSessionModeRequired
{
  __block ABI22_0_0EXAVAudioSessionMode audioSessionModeRequired = ABI22_0_0EXAVAudioSessionModeInactive;
  
  [self _runBlockForAllAVObjects:^(NSObject<ABI22_0_0EXAVObject> *exAVObject) {
    ABI22_0_0EXAVAudioSessionMode audioSessionModeRequiredByThisObject = [exAVObject getAudioSessionModeRequired];
    if (audioSessionModeRequiredByThisObject > audioSessionModeRequired) {
      audioSessionModeRequired = audioSessionModeRequiredByThisObject;
    }
  }];
  
  if (_audioRecorder) {
    if (_audioRecorderShouldBeginRecording || [_audioRecorder isRecording]) {
      audioSessionModeRequired = ABI22_0_0EXAVAudioSessionModeActive;
    } else if (_audioRecorderIsPreparing && audioSessionModeRequired == ABI22_0_0EXAVAudioSessionModeInactive) {
      audioSessionModeRequired = ABI22_0_0EXAVAudioSessionModeActiveMuted;
    }
  }
  
  return audioSessionModeRequired;
}

- (NSError *)promoteAudioSessionIfNecessary
{
  if (!_audioIsEnabled) {
    return ABI22_0_0RCTErrorWithMessage(@"Expo Audio is disabled, so the audio session could not be activated.");
  }
  if (_isBackgrounded) {
    return ABI22_0_0RCTErrorWithMessage(@"This experience is currently in the background, so the audio session could not be activated.");
  }
  
  ABI22_0_0EXAVAudioSessionMode audioSessionModeRequired = [self _getAudioSessionModeRequired];
  
  if (audioSessionModeRequired == ABI22_0_0EXAVAudioSessionModeInactive) {
    return nil;
  }
  
  NSError *error;
  
  error = [self _updateAudioSessionCategoryForAudioSessionMode:audioSessionModeRequired];
  if (error) {
    return error;
  }
  
  error = [_kernelAudioSessionManagerDelegate setActive:YES forScopedModule:self];
  if (error) {
    return error;
  }
  
  _currentAudioSessionMode = audioSessionModeRequired;
  return nil;
}

- (NSError *)_deactivateAudioSession
{
  if (_currentAudioSessionMode == ABI22_0_0EXAVAudioSessionModeInactive) {
    return nil;
  }
  
  // We must have all players, recorders, and videos paused in order to effectively deactivate the session.
  [self _runBlockForAllAVObjects:^(NSObject<ABI22_0_0EXAVObject> *exAVObject) {
    [exAVObject pauseImmediately];
  }];
  if (_audioRecorder && [_audioRecorder isRecording]) {
    [_audioRecorder pause];
  }
  
  NSError *error = [_kernelAudioSessionManagerDelegate setActive:NO forScopedModule:self];
  if (!error) {
    _currentAudioSessionMode = ABI22_0_0EXAVAudioSessionModeInactive;
  }
  return error;
}

- (NSError *)demoteAudioSessionIfPossible
{
  ABI22_0_0EXAVAudioSessionMode audioSessionModeRequired = [self _getAudioSessionModeRequired];
  
  // Current audio session mode is lower than the required one
  // (we should rather promote the session than demote it).
  if (_currentAudioSessionMode <= audioSessionModeRequired) {
    return nil;
  }
  
  // We require the session to be muted and it is active.
  // Let's only update the category.
  if (audioSessionModeRequired == ABI22_0_0EXAVAudioSessionModeActiveMuted) {
    NSError *error = [self _updateAudioSessionCategoryForAudioSessionMode:audioSessionModeRequired];
    if (!error) {
      _currentAudioSessionMode = ABI22_0_0EXAVAudioSessionModeActiveMuted;
    }
    return error;
  }
  
  // We require the session to be inactive and it is active, let's deactivate it!
  return [self _deactivateAudioSession];
}

- (void)handleAudioSessionInterruption:(NSNotification*)notification
{
  NSNumber *interruptionType = [[notification userInfo] objectForKey:AVAudioSessionInterruptionTypeKey];
  if (interruptionType.unsignedIntegerValue == AVAudioSessionInterruptionTypeBegan) {
    _currentAudioSessionMode = ABI22_0_0EXAVAudioSessionModeInactive;
  }
  
  [self _runBlockForAllAVObjects:^(NSObject<ABI22_0_0EXAVObject> *exAVObject) {
    [exAVObject handleAudioSessionInterruption:notification];
  }];
}

- (void)handleMediaServicesReset:(NSNotification *)notification
{
  // See here: https://developer.apple.com/library/content/qa/qa1749/_index.html
  // (this is an unlikely notification to receive, but best practices suggests that we catch it just in case)
  
  _currentAudioSessionMode = ABI22_0_0EXAVAudioSessionModeInactive;
  
  [self _runBlockForAllAVObjects:^(NSObject<ABI22_0_0EXAVObject> *exAVObject) {
    [exAVObject handleMediaServicesReset:nil];
  }];
  
  if (_audioRecorder) {
    [self _removeAudioRecorder:NO];
    [self _createNewAudioRecorder];
    [_audioRecorder prepareToRecord];
  }
}

#pragma mark - Internal sound playback helper methods

- (void)_runBlock:(void (^)(ABI22_0_0EXAVPlayerData *data))block
  withSoundForKey:(nonnull NSNumber *)key
     withRejecter:(ABI22_0_0RCTPromiseRejectBlock)reject
{
  ABI22_0_0EXAVPlayerData *data = _soundDictionary[key];
  if (data) {
    block(data);
  } else {
    reject(@"E_AUDIO_NOPLAYER", nil, ABI22_0_0RCTErrorWithMessage(@"Player does not exist."));
  }
}

- (void)_removeSoundForKey:(NSNumber *)key
{
  ABI22_0_0EXAVPlayerData *data = _soundDictionary[key];
  if (data) {
    [data pauseImmediately];
    [self demoteAudioSessionIfPossible];
  }
  _soundDictionary[key] = nil;
}

#pragma mark - Internal video playback helper method

- (void)_runBlock:(void (^)(ABI22_0_0EXVideoView *view))block
withEXVideoViewForTag:(nonnull NSNumber *)ReactABI22_0_0Tag
     withRejecter:(ABI22_0_0RCTPromiseRejectBlock)reject
{
  __weak ABI22_0_0EXAV *weakSelf = self;
  dispatch_async(dispatch_get_main_queue(), ^{
    __strong ABI22_0_0EXAV *strongSelf = weakSelf;
    if (strongSelf) {
      UIView *view = [strongSelf.bridge.uiManager viewForReactABI22_0_0Tag:ReactABI22_0_0Tag];
      if ([view isKindOfClass:[ABI22_0_0EXVideoView class]]) {
        dispatch_async(ABI22_0_0RCTGetUIManagerQueue(), ^{
          block((ABI22_0_0EXVideoView *)view);
        });
      } else {
        NSString *errorMessage = [NSString stringWithFormat:@"Invalid view returned from registry, expecting ABI22_0_0EXVideo, got: %@", view];
        reject(@"E_VIDEO_TAGINCORRECT", nil, ABI22_0_0RCTErrorWithMessage(errorMessage));
      }
    }
  });
}

#pragma mark - Internal audio recording helper methods

- (NSString *)_getBitRateStrategyFromEnum:(NSNumber *)bitRateEnumSelected
{
  if (bitRateEnumSelected) {
    switch ([bitRateEnumSelected integerValue]) {
      case ABI22_0_0EXAudioRecordingOptionBitRateStrategyConstant:
        return AVAudioBitRateStrategy_Constant;
      case ABI22_0_0EXAudioRecordingOptionBitRateStrategyLongTermAverage:
        return AVAudioBitRateStrategy_LongTermAverage;
      case ABI22_0_0EXAudioRecordingOptionBitRateStrategyVariableConstrained:
        return AVAudioBitRateStrategy_VariableConstrained;
        break;
      case ABI22_0_0EXAudioRecordingOptionBitRateStrategyVariable:
        return AVAudioBitRateStrategy_Variable;
      default:
        return nil;
    }
  }
  return nil;
}

- (NSDictionary<NSString *, NSString *> *)_getAVKeysForRecordingOptionsKeys:(NSString *)bitRateStrategy
{
  return @{ABI22_0_0EXAudioRecordingOptionOutputFormatKey: AVFormatIDKey,
           ABI22_0_0EXAudioRecordingOptionAudioQualityKey:
             bitRateStrategy == AVAudioBitRateStrategy_Variable
           ? AVEncoderAudioQualityForVBRKey : AVEncoderAudioQualityKey,
           ABI22_0_0EXAudioRecordingOptionSampleRateKey: AVSampleRateKey,
           ABI22_0_0EXAudioRecordingOptionNumberOfChannelsKey: AVNumberOfChannelsKey,
           ABI22_0_0EXAudioRecordingOptionBitRateKey: AVEncoderBitRateKey,
           ABI22_0_0EXAudioRecordingOptionBitDepthHintKey: AVEncoderBitDepthHintKey,
           ABI22_0_0EXAudioRecordingOptionLinearPCMBitDepthKey: AVLinearPCMBitDepthKey,
           ABI22_0_0EXAudioRecordingOptionLinearPCMIsBigEndianKey: AVLinearPCMIsBigEndianKey,
           ABI22_0_0EXAudioRecordingOptionLinearPCMIsFloatKey: AVLinearPCMIsFloatKey};
}

- (void)_setNewAudioRecorderFilenameAndSettings:(NSDictionary *)optionsFromJS
{
  NSDictionary *iosOptionsFromJS = optionsFromJS[ABI22_0_0EXAudioRecordingOptionsKey];
  
  NSString *extension = iosOptionsFromJS[ABI22_0_0EXAudioRecordingOptionExtensionKey];
  _audioRecorderFilename = [NSString stringWithFormat:@"recording-%@%@", [[NSUUID UUID] UUIDString], extension];
  
  NSString *bitRateStrategy = [self _getBitRateStrategyFromEnum:iosOptionsFromJS[ABI22_0_0EXAudioRecordingOptionBitRateStrategyKey]];
  NSDictionary<NSString *, NSString *> *avKeysForRecordingOptionsKeys = [self _getAVKeysForRecordingOptionsKeys:bitRateStrategy];
  
  NSMutableDictionary *recorderSettings = [NSMutableDictionary new];
  for (NSString *recordingOptionsKey in avKeysForRecordingOptionsKeys) {
    if (iosOptionsFromJS[recordingOptionsKey]) {
      recorderSettings[avKeysForRecordingOptionsKeys[recordingOptionsKey]] = iosOptionsFromJS[recordingOptionsKey];
    }
  }
  recorderSettings[AVEncoderBitRateStrategyKey] = bitRateStrategy;
  
  _audioRecorderSettings = recorderSettings;
}

- (NSError *)_createNewAudioRecorder
{
  if (_audioRecorder) {
    return ABI22_0_0RCTErrorWithMessage(@"Recorder already exists.");
  }
  
  NSString *directory = [self.bridge.scopedModules.fileSystem.cachesDirectory stringByAppendingPathComponent:@"AV"];
  [ABI22_0_0EXFileSystem ensureDirExistsWithPath:directory];
  NSString *soundFilePath = [directory stringByAppendingPathComponent:_audioRecorderFilename];
  NSURL *soundFileURL = [NSURL fileURLWithPath:soundFilePath];
  
  NSError *error;
  AVAudioRecorder *recorder = [[AVAudioRecorder alloc] initWithURL:soundFileURL
                                                          settings:_audioRecorderSettings
                                                             error:&error];
  if (error == nil) {
    _audioRecorder = recorder;
  }
  return error;
}

- (int)_getDurationMillisOfRecordingAudioRecorder
{
  return _audioRecorder ? (int) (_audioRecorder.currentTime * 1000) : 0;
}

- (NSDictionary *)_getAudioRecorderStatus
{
  if (_audioRecorder) {
    int durationMillisFromRecorder = [self _getDurationMillisOfRecordingAudioRecorder];
    // After stop, the recorder's duration goes to zero, so we replace it with the correct duration in this case.
    int durationMillis = durationMillisFromRecorder == 0 ? _audioRecorderDurationMillis : durationMillisFromRecorder;
    return @{@"canRecord": @(YES),
             @"isRecording": @([_audioRecorder isRecording]),
             @"durationMillis": @(durationMillis)};
  } else {
    return nil;
  }
}

- (BOOL)_checkAudioRecorderExistsOrReject:(ABI22_0_0RCTPromiseRejectBlock)reject
{
  if (_audioRecorder == nil) {
    reject(@"E_AUDIO_NORECORDER", nil, ABI22_0_0RCTErrorWithMessage(@"Recorder does not exist."));
  }
  return _audioRecorder != nil;
}

- (void)_removeAudioRecorder:(BOOL)removeFilenameAndSettings
{
  if (_audioRecorder) {
    [_audioRecorder stop];
    [self demoteAudioSessionIfPossible];
    _audioRecorder = nil;
  }
  if (removeFilenameAndSettings) {
    _audioRecorderFilename = nil;
    _audioRecorderSettings = nil;
  }
}

ABI22_0_0EX_EXPORT_SCOPED_MODULE(ExponentAV, AudioSessionManager);

- (NSArray<NSString *> *)supportedEvents
{
  return @[];
}

#pragma mark - Audio API: Global settings

ABI22_0_0RCT_EXPORT_METHOD(setAudioIsEnabled:(BOOL)value
                           resolver:(ABI22_0_0RCTPromiseResolveBlock)resolve
                           rejecter:(ABI22_0_0RCTPromiseRejectBlock)reject)
{
  _audioIsEnabled = value;
  
  if (!value) {
    [self _deactivateAudioSession];
  }
  resolve(nil);
}

ABI22_0_0RCT_EXPORT_METHOD(setAudioMode:(nonnull NSDictionary *)mode
                      resolver:(ABI22_0_0RCTPromiseResolveBlock)resolve
                      rejecter:(ABI22_0_0RCTPromiseRejectBlock)reject)
{
  NSError *error = [self _setAudioMode:mode];
  
  if (error) {
    reject(@"E_AUDIO_AUDIOMODE", nil, error);
  } else {
    resolve(nil);
  }
}

#pragma mark - Unified playback API - Audio

ABI22_0_0RCT_EXPORT_METHOD(loadForSound:(nonnull NSString *)uriString
                    withStatus:(nonnull NSDictionary *)status
                   withSuccess:(ABI22_0_0RCTResponseSenderBlock)loadSuccess
                     withError:(ABI22_0_0RCTResponseSenderBlock)loadError)
{
  NSNumber *key = @(_soundDictionaryKeyCount++);
  __weak __typeof__(self) weakSelf = self;
  ABI22_0_0EXAVPlayerData *data = [[ABI22_0_0EXAVPlayerData alloc] initWithEXAV:self
                                                      withURL:[NSURL URLWithString:uriString]
                                                   withStatus:status
                                         withLoadFinishBlock:^(BOOL success, NSDictionary *successStatus, NSString *error) {
                                           if (success) {
                                             loadSuccess(@[key, successStatus]);
                                           } else {
                                             [weakSelf _removeSoundForKey:key];
                                             loadError(@[error]);
                                           }
                                         }];
  data.errorCallback = ^(NSString *error) {
    __strong __typeof__(self) strongSelf = weakSelf;
    
    if (strongSelf) {
      [strongSelf _removeSoundForKey:key];
    }
  };
  _soundDictionary[key] = data;
}

ABI22_0_0RCT_EXPORT_METHOD(unloadForSound:(nonnull NSNumber *)key
                        resolver:(ABI22_0_0RCTPromiseResolveBlock)resolve
                        rejecter:(ABI22_0_0RCTPromiseRejectBlock)reject)
{
  [self _runBlock:^(ABI22_0_0EXAVPlayerData *data) {
    [self _removeSoundForKey:key];
    resolve([ABI22_0_0EXAVPlayerData getUnloadedStatus]);
  } withSoundForKey:key withRejecter:reject];
}

ABI22_0_0RCT_EXPORT_METHOD(setStatusForSound:(nonnull NSNumber *)key
                         withStatus:(nonnull NSDictionary *)status
                           resolver:(ABI22_0_0RCTPromiseResolveBlock)resolve
                           rejecter:(ABI22_0_0RCTPromiseRejectBlock)reject)
{
  [self _runBlock:^(ABI22_0_0EXAVPlayerData *data) {
    [data setStatus:status
           resolver:resolve
           rejecter:reject];
  } withSoundForKey:key withRejecter:reject];
}

ABI22_0_0RCT_EXPORT_METHOD(getStatusForSound:(nonnull NSNumber *)key
                           resolver:(ABI22_0_0RCTPromiseResolveBlock)resolve
                           rejecter:(ABI22_0_0RCTPromiseRejectBlock)reject)
{
  [self _runBlock:^(ABI22_0_0EXAVPlayerData *data) {
    NSDictionary *status = [data getStatus];
    resolve(status);
  } withSoundForKey:key withRejecter:reject];
}

ABI22_0_0RCT_EXPORT_METHOD(setStatusUpdateCallbackForSound:(nonnull NSNumber *)key
                                     withCallback:(ABI22_0_0RCTResponseSenderBlock)callback)
{
  ABI22_0_0EXAVPlayerData *data = _soundDictionary[key];
  if (data) {
    __block BOOL used = NO; // ABI22_0_0RCTResponseSenderBlock can only be used once
    data.statusUpdateCallback = ^(NSDictionary *status) {
      if (!used) {
        used = YES;
        callback(@[status]);
      }
    };
  }
}

ABI22_0_0RCT_EXPORT_METHOD(setErrorCallbackForSound:(nonnull NSNumber *)key
                              withCallback:(ABI22_0_0RCTResponseSenderBlock)callback)
{
  ABI22_0_0EXAVPlayerData *data = _soundDictionary[key];
  if (data) {
    __block BOOL used = NO; // ABI22_0_0RCTResponseSenderBlock can only be used once
    __weak __typeof__(self) weakSelf = self;
    data.errorCallback = ^(NSString *error) {
      __strong __typeof__(self) strongSelf = weakSelf;
      
      if (strongSelf && !used) {
        used = YES;
        [strongSelf _removeSoundForKey:key];
        callback(@[error]);
      }
    };
  }
}

#pragma mark - Unified playback API - Video

ABI22_0_0RCT_EXPORT_METHOD(loadForVideo:(nonnull NSNumber *)ReactABI22_0_0Tag
                           uri:(nonnull NSString *)uriString
                    withStatus:(nonnull NSDictionary *)status
                      resolver:(ABI22_0_0RCTPromiseResolveBlock)resolve
                      rejecter:(ABI22_0_0RCTPromiseRejectBlock)reject)
{
  [self _runBlock:^(ABI22_0_0EXVideoView *view) {
    [view setUri:uriString withStatus:status resolver:resolve rejecter:reject];
  } withEXVideoViewForTag:ReactABI22_0_0Tag withRejecter:reject];
}

ABI22_0_0RCT_EXPORT_METHOD(unloadForVideo:(nonnull NSNumber *)ReactABI22_0_0Tag
                        resolver:(ABI22_0_0RCTPromiseResolveBlock)resolve
                        rejecter:(ABI22_0_0RCTPromiseRejectBlock)reject)
{
  [self _runBlock:^(ABI22_0_0EXVideoView *view) {
    [view setUri:nil withStatus:nil resolver:resolve rejecter:reject];
  } withEXVideoViewForTag:ReactABI22_0_0Tag withRejecter:reject];
}

ABI22_0_0RCT_EXPORT_METHOD(setStatusForVideo:(nonnull NSNumber *)ReactABI22_0_0Tag
                         withStatus:(nonnull NSDictionary *)status
                           resolver:(ABI22_0_0RCTPromiseResolveBlock)resolve
                           rejecter:(ABI22_0_0RCTPromiseRejectBlock)reject)
{
  [self _runBlock:^(ABI22_0_0EXVideoView *view) {
    [view setStatus:status resolver:resolve rejecter:reject];
  } withEXVideoViewForTag:ReactABI22_0_0Tag withRejecter:reject];
}

ABI22_0_0RCT_EXPORT_METHOD(getStatusForVideo:(nonnull NSNumber *)ReactABI22_0_0Tag
                           resolver:(ABI22_0_0RCTPromiseResolveBlock)resolve
                           rejecter:(ABI22_0_0RCTPromiseRejectBlock)reject)
{
  [self _runBlock:^(ABI22_0_0EXVideoView *view) {
    resolve(view.status);
  } withEXVideoViewForTag:ReactABI22_0_0Tag withRejecter:reject];
}

// Note that setStatusUpdateCallback happens in the JS for video via onStatusUpdate

#pragma mark - Audio API: Recording

ABI22_0_0RCT_EXPORT_METHOD(prepareAudioRecorder:(nonnull NSDictionary *)options
                              resolver:(ABI22_0_0RCTPromiseResolveBlock)resolve
                              rejecter:(ABI22_0_0RCTPromiseRejectBlock)reject)
{
  [self _setNewAudioRecorderFilenameAndSettings:options];
  NSError *error = [self _createNewAudioRecorder];
  
  if (_audioRecorder && !error) {
    _audioRecorderIsPreparing = true;
    error = [self promoteAudioSessionIfNecessary];
    if (error) {
      reject(@"E_AUDIO_RECORDERNOTCREATED", @"Prepare encountered an error: audio session not activated!", error);
    } else if ([_audioRecorder prepareToRecord]) {
      resolve(@{@"uri": [[_audioRecorder url] absoluteString],
                @"status": [self _getAudioRecorderStatus]});
    } else {
      reject(@"E_AUDIO_RECORDERNOTCREATED", nil, ABI22_0_0RCTErrorWithMessage(@"Prepare encountered an error: recorder not prepared."));
    }
    _audioRecorderIsPreparing = false;
    [self demoteAudioSessionIfPossible];
  } else {
    reject(@"E_AUDIO_RECORDERNOTCREATED", @"Prepare encountered an error: recorder not created.", error);
  }
}

ABI22_0_0RCT_EXPORT_METHOD(startAudioRecording:(ABI22_0_0RCTPromiseResolveBlock)resolve
                             rejecter:(ABI22_0_0RCTPromiseRejectBlock)reject)
{
  if ([self _checkAudioRecorderExistsOrReject:reject]) {
    if (!_allowsAudioRecording) {
      reject(@"E_AUDIO_AUDIOMODE", nil, ABI22_0_0RCTErrorWithMessage(@"Recording not allowed on iOS."));
    } else if (!_audioRecorder.recording) {
      _audioRecorderShouldBeginRecording = true;
      NSError *error = [self promoteAudioSessionIfNecessary];
      if (!error) {
        if ([_audioRecorder record]) {
          resolve([self _getAudioRecorderStatus]);
        } else {
          reject(@"E_AUDIO_RECORDING", nil, ABI22_0_0RCTErrorWithMessage(@"Start encountered an error: recording not started."));
        }
      } else {
        reject(@"E_AUDIO_RECORDING", @"Start encountered an error: audio session not activated.", error);
      }
    } else {
      resolve([self _getAudioRecorderStatus]);
    }
  }
  _audioRecorderShouldBeginRecording = false;
}

ABI22_0_0RCT_EXPORT_METHOD(pauseAudioRecording:(ABI22_0_0RCTPromiseResolveBlock)resolve
                             rejecter:(ABI22_0_0RCTPromiseRejectBlock)reject)
{
  if ([self _checkAudioRecorderExistsOrReject:reject]) {
    if (_audioRecorder.recording) {
      [_audioRecorder pause];
      [self demoteAudioSessionIfPossible];
    }
    resolve([self _getAudioRecorderStatus]);
  }
}

ABI22_0_0RCT_EXPORT_METHOD(stopAudioRecording:(ABI22_0_0RCTPromiseResolveBlock)resolve
                            rejecter:(ABI22_0_0RCTPromiseRejectBlock)reject)
{
  if ([self _checkAudioRecorderExistsOrReject:reject]) {
    if (_audioRecorder.recording) {
      _audioRecorderDurationMillis = [self _getDurationMillisOfRecordingAudioRecorder];
      [_audioRecorder stop];
      [self demoteAudioSessionIfPossible];
    }
    resolve([self _getAudioRecorderStatus]);
  }
}

ABI22_0_0RCT_EXPORT_METHOD(getAudioRecordingStatus:(ABI22_0_0RCTPromiseResolveBlock)resolve
                                 rejecter:(ABI22_0_0RCTPromiseRejectBlock)reject)
{
  if ([self _checkAudioRecorderExistsOrReject:reject]) {
    resolve([self _getAudioRecorderStatus]);
  }
}

ABI22_0_0RCT_EXPORT_METHOD(unloadAudioRecorder:(ABI22_0_0RCTPromiseResolveBlock)resolve
                             rejecter:(ABI22_0_0RCTPromiseRejectBlock)reject)
{
  if ([self _checkAudioRecorderExistsOrReject:reject]) {
    [self _removeAudioRecorder:YES];
    resolve(nil);
  }
}

#pragma mark - Lifecycle

- (void)dealloc
{
  [_kernelAudioSessionManagerDelegate scopedModuleWillDeallocate:self];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  
  // This will clear all @properties and deactivate the audio session:
  
  for (NSObject<ABI22_0_0EXAVObject> *video in [_videoSet allObjects]) {
    [video pauseImmediately];
    [_videoSet removeObject:video];
  }
  [self _removeAudioRecorder:YES];
  for (NSNumber *key in [_soundDictionary allKeys]) {
    [self _removeSoundForKey:key];
  }
}


@end
