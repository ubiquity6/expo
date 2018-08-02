/*

 Erica Sadun, http://ericasadun.com
 https://github.com/erica/iOS-Drawing/tree/master/C08/Quartz%20Book%20Pack/Bezier
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#define ABI29_0_0RNSVGNULLPOINT CGRectNull.origin

@interface ABI29_0_0RNSVGBezierElement : NSObject

// Element storage
@property (nonatomic, assign) CGPathElementType elementType;
@property (nonatomic, assign) CGPoint point;
@property (nonatomic, assign) CGPoint controlPoint1;
@property (nonatomic, assign) CGPoint controlPoint2;

// Instance creation
+ (instancetype) elementWithPathElement: (CGPathElement) element;
+ (NSArray *) elementsFromCGPath:(CGPathRef)path;

@end;

