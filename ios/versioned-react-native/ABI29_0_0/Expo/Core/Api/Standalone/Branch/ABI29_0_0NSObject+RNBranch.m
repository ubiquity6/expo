//
//  NSObject+RNBranch.m
//  ABI29_0_0RNBranch
//
//  Created by Jimmy Dee on 1/26/17.
//  Copyright © 2017 Branch Metrics. All rights reserved.
//

#import <ReactABI29_0_0/ABI29_0_0RCTLog.h>

#import "ABI29_0_0NSObject+RNBranch.h"
#import "ABI29_0_0RNBranchProperty.h"

@implementation NSObject(ABI29_0_0RNBranch)

+ (NSDictionary<NSString *,ABI29_0_0RNBranchProperty *> *)supportedProperties
{
    return @{};
}

- (void)setSupportedPropertiesWithMap:(NSDictionary *)map
{
    for (NSString *key in map.allKeys) {
        ABI29_0_0RNBranchProperty *property = self.class.supportedProperties[key];
        if (!property) {
            ABI29_0_0RCTLogWarn(@"\"%@\" is not a supported property for %@.", key, NSStringFromClass(self.class));
            continue;
        }
        
        id value = map[key];
        Class type = property.type;
        if (![value isKindOfClass:type]) {
            ABI29_0_0RCTLogWarn(@"\"%@\" requires a value of type %@.", key, NSStringFromClass(type));
            continue;
        }
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:property.setterSelector withObject:value];
#pragma clang diagnostic pop
    }
}

@end
