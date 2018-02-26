#import <React/RCTViewManager.h>

@class EXGLView;

@interface EXGLViewManager : RCTViewManager
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, EXGLView *> *arSessions;

@end
