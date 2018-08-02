// Copyright 2016-present 650 Industries. All rights reserved.

#import "ABI29_0_0EXFacebook.h"

#import <ReactABI29_0_0/ABI29_0_0RCTUtils.h>
#import <ABI29_0_0EXConstantsInterface/ABI29_0_0EXConstantsInterface.h>

#import "ABI29_0_0EXModuleRegistryBinding.h"
#import "FBSDKCoreKit/FBSDKCoreKit.h"
#import "FBSDKLoginKit/FBSDKLoginKit.h"
#import "../Private/FBSDKCoreKit/FBSDKInternalUtility.h"

@implementation FBSDKInternalUtility (ABI29_0_0EXFacebook)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
+ (BOOL)isRegisteredURLScheme:(NSString *)urlScheme
{
  // !!!: Make FB SDK think we can open fb<app id>:// urls
  return ![@[FBSDK_CANOPENURL_FACEBOOK, FBSDK_CANOPENURL_MESSENGER, FBSDK_CANOPENURL_FBAPI, FBSDK_CANOPENURL_SHARE_EXTENSION]
           containsObject:urlScheme];
}
#pragma clang diagnostic pop

@end

@implementation ABI29_0_0EXFacebook

@synthesize bridge = _bridge;

ABI29_0_0RCT_EXPORT_MODULE(ExponentFacebook)

ABI29_0_0RCT_REMAP_METHOD(logInWithReadPermissionsAsync,
                 appId:(NSString *)appId
                 config:(NSDictionary *)config
                 resolver:(ABI29_0_0RCTPromiseResolveBlock)resolve
                 rejecter:(ABI29_0_0RCTPromiseRejectBlock)reject)
{
  NSArray *permissions = config[@"permissions"];
  if (!permissions) {
    permissions = @[@"public_profile", @"email", @"user_friends"];
  }

  NSString *behavior = config[@"behavior"];

  // FB SDK requires login to run on main thread
  // Needs to not race with other mutations of this global FB state
  dispatch_async(dispatch_get_main_queue(), ^{
    [FBSDKAccessToken setCurrentAccessToken:nil];
    [FBSDKSettings setAppID:appId];
    FBSDKLoginManager *loginMgr = [[FBSDKLoginManager alloc] init];

    loginMgr.loginBehavior = FBSDKLoginBehaviorWeb;
    if (behavior) {
      // TODO: Support other logon behaviors?
      //       - browser is problematic because it navigates to fb<appid>:// when done
      //       - system is problematic because it asks whether to give 'Exponent' permissions,
      //         just a weird user-facing UI
      if ([behavior isEqualToString:@"native"]) {
        loginMgr.loginBehavior = FBSDKLoginBehaviorNative;
      } else if ([behavior isEqualToString:@"browser"]) {
        loginMgr.loginBehavior = FBSDKLoginBehaviorBrowser;
      } else if ([behavior isEqualToString:@"system"]) {
        loginMgr.loginBehavior = FBSDKLoginBehaviorSystemAccount;
      } else if ([behavior isEqualToString:@"web"]) {
        loginMgr.loginBehavior = FBSDKLoginBehaviorWeb;
      }
    }
    
    if (loginMgr.loginBehavior != FBSDKLoginBehaviorWeb) {
      id<ABI29_0_0EXConstantsInterface> constants = [self->_bridge.scopedModules.moduleRegistry getModuleImplementingProtocol:@protocol(ABI29_0_0EXConstantsInterface)];
      
      if ([constants.appOwnership isEqualToString:@"expo"]) {
        // expo client: only web
        NSString *message = @"Only `web` behavior is supported in Expo Client.";
        reject(@"E_BEHAVIOR_NOT_PERMITTED", message, ABI29_0_0RCTErrorWithMessage(message));
        return;
      } else {
        if (![[self class] facebookAppIdFromNSBundle]) {
          // standalone: non-web requires native config
          NSString *message = [NSString stringWithFormat:
                               @"Tried to perform Facebook login with behavior `%@`, but "
                               "no Facebook app id was provided. Specify Facebook app id in app.json "
                               "or switch to `web` behavior.", behavior];
          reject(@"E_BEHAVIOR_NOT_SUPPORTED", message, ABI29_0_0RCTErrorWithMessage(message));
          return;
        }
      }
    }

    @try {
      [loginMgr logInWithReadPermissions:permissions fromViewController:nil handler:^(FBSDKLoginManagerLoginResult *result, NSError *error) {
        if (error) {
          reject(@"E_FBLOGIN_ERROR", @"Error with Facebook login", error);
          return;
        }

        if (result.isCancelled || !result.token) {
          resolve(@{ @"type": @"cancel" });
          return;
        }

        if (![result.token.appID isEqualToString:appId]) {
          reject(@"E_FBLOGIN_ERROR", @"Logged into wrong app, try again?", nil);
          return;
        }

        NSInteger expiration = [result.token.expirationDate timeIntervalSince1970];
        resolve(@{ @"type": @"success", @"token": result.token.tokenString, @"expires": @(expiration) });
      }];
    }
    @catch (NSException *exception) {
      NSString *message = [@"An error occurred while trying to log in to Facebook: " stringByAppendingString:exception.reason];
      reject(@"E_FBLOGIN_ERROR", message, nil);
    }
  });
}

+ (id)facebookAppIdFromNSBundle
{
  return [[NSBundle mainBundle].infoDictionary objectForKey:@"FacebookAppID"];
}

@end
