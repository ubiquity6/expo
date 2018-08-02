// Copyright 2015-present 650 Industries. All rights reserved.

#import "ABI29_0_0EXDevSettingsDataSource.h"

#import <ReactABI29_0_0/ABI29_0_0RCTLog.h>
#import <ReactABI29_0_0/ABI29_0_0RCTUtils.h>

// redefined from ABI29_0_0RCTDevMenu.mm
NSString *const ABI29_0_0EXDevSettingsUserDefaultsKey = @"ABI29_0_0RCTDevMenu";
NSString *const ABI29_0_0EXDevSettingShakeToShowDevMenu = @"shakeToShow";
NSString *const ABI29_0_0EXDevSettingProfilingEnabled = @"profilingEnabled";
NSString *const ABI29_0_0EXDevSettingHotLoadingEnabled = @"hotLoadingEnabled";
NSString *const ABI29_0_0EXDevSettingLiveReloadEnabled = @"liveReloadEnabled";
NSString *const ABI29_0_0EXDevSettingIsInspectorShown = @"showInspector";
NSString *const ABI29_0_0EXDevSettingIsDebuggingRemotely = @"isDebuggingRemotely";

@interface ABI29_0_0EXDevSettingsDataSource ()

@property (nonatomic, strong) NSString *experienceId;
@property (nonatomic, readonly) NSSet *settingsDisabledInProduction;

@end

@implementation ABI29_0_0EXDevSettingsDataSource {
  NSMutableDictionary *_settings;
  NSUserDefaults *_userDefaults;
  BOOL _isDevelopment;
}

- (instancetype)initWithDefaultValues:(NSDictionary *)defaultValues forExperienceId:(NSString *)experienceId isDevelopment:(BOOL)isDevelopment
{
  if (self = [super init]) {
    _experienceId = experienceId;
    _userDefaults = [NSUserDefaults standardUserDefaults];
    _isDevelopment = isDevelopment;
    _settingsDisabledInProduction = [NSSet setWithArray:@[
      ABI29_0_0EXDevSettingShakeToShowDevMenu,
      ABI29_0_0EXDevSettingProfilingEnabled,
      ABI29_0_0EXDevSettingHotLoadingEnabled,
      ABI29_0_0EXDevSettingLiveReloadEnabled,
      ABI29_0_0EXDevSettingIsInspectorShown,
      ABI29_0_0EXDevSettingIsDebuggingRemotely,
    ]];
    if (defaultValues) {
      [self _reloadWithDefaults:defaultValues];
    }
  }
  return self;
}

- (void)updateSettingWithValue:(id)value forKey:(NSString *)key
{
  ABI29_0_0RCTAssert((key != nil), @"%@", [NSString stringWithFormat:@"%@: Tried to update nil key", [self class]]);

  id currentValue = [self settingForKey:key];
  if (currentValue == value || [currentValue isEqual:value]) {
    return;
  }
  if (value) {
    _settings[key] = value;
  } else {
    [_settings removeObjectForKey:key];
  }
  [_userDefaults setObject:_settings forKey:[self _userDefaultsKey]];
}

- (id)settingForKey:(NSString *)key
{
  // prohibit these settings if not serving the experience as a developer
  if (!_isDevelopment && [_settingsDisabledInProduction containsObject:key]) {
    return @NO;
  }
  return _settings[key];
}

#pragma mark - internal

- (void)_reloadWithDefaults:(NSDictionary *)defaultValues
{
  NSString *defaultsKey = [self _userDefaultsKey];
  NSDictionary *existingSettings = [_userDefaults objectForKey:defaultsKey];
  _settings = existingSettings ? [existingSettings mutableCopy] : [NSMutableDictionary dictionary];
  for (NSString *key in [defaultValues keyEnumerator]) {
    if (!_settings[key]) {
      _settings[key] = defaultValues[key];
    }
  }
  [_userDefaults setObject:_settings forKey:defaultsKey];
}

- (NSString *)_userDefaultsKey
{
  if (_experienceId) {
    return [NSString stringWithFormat:@"%@/%@", _experienceId, ABI29_0_0EXDevSettingsUserDefaultsKey];
  } else {
    ABI29_0_0RCTLogWarn(@"Can't scope dev settings because bridge is not set");
    return ABI29_0_0EXDevSettingsUserDefaultsKey;
  }
}

@end
