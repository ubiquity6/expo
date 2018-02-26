#import "EXGLView.h"
#import <ARKit/ARKit.h>


@interface EXGLARSessionManager : NSObject

- (NSDictionary *)startARSessionWithGLView:(EXGLView *)glView;
- (void)stopARSession;
- (void)updateARCamTexture;
- (NSDictionary *)arMatricesForViewportSize:(CGSize)viewportSize zNear:(CGFloat)zNear zFar:(CGFloat)zFar;
- (NSDictionary *)arLightEstimation;
- (NSDictionary *)rawFeaturePoints;
- (NSDictionary *)planes;
- (id)underlyingARSession;

@property (nonatomic, assign) BOOL isPlaneDetectionEnabled;
@property (nonatomic, assign) BOOL isLightEstimationEnabled;
@property (nonatomic, assign) NSInteger worldAlignment;

@end

