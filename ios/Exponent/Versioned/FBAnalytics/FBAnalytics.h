//
//  taken from https://github.com/evollu/react-native-firebase-analytics/tree/master/ios
//

#ifndef FBAnalytics_h
#define FBAnalytics_h
#import <Foundation/Foundation.h>

#if __has_include(<FirebaseAnalytics/FIRAnalytics.h>)
#import <React/RCTBridgeModule.h>

@interface FBAnalytics : NSObject <RCTBridgeModule> {
  
}

@end

#else
@interface FBAnalytics : NSObject
@end
#endif

#endif
