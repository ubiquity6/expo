#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <ABI29_0_0EXCamera/ABI29_0_0EXCameraManager.h>
#import <ABI29_0_0EXCore/ABI29_0_0EXModuleRegistry.h>
#import <ABI29_0_0EXCore/ABI29_0_0EXAppLifecycleListener.h>
#import <ABI29_0_0EXCameraInterface/ABI29_0_0EXCameraInterface.h>

@class ABI29_0_0EXCameraManager;

@interface ABI29_0_0EXCamera : UIView <AVCaptureMetadataOutputObjectsDelegate, AVCaptureFileOutputRecordingDelegate, ABI29_0_0EXAppLifecycleListener, ABI29_0_0EXCameraInterface>

@property (nonatomic, strong) dispatch_queue_t sessionQueue;
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureDeviceInput *videoCaptureDeviceInput;
@property (nonatomic, strong) AVCaptureStillImageOutput *stillImageOutput;
@property (nonatomic, strong) AVCaptureMovieFileOutput *movieFileOutput;
@property (nonatomic, strong) AVCaptureMetadataOutput *metadataOutput;
@property (nonatomic, strong) id runtimeErrorHandlingObserver;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) NSArray *barCodeTypes;

@property (nonatomic, assign) NSInteger presetCamera;
@property (nonatomic, assign) NSInteger flashMode;
@property (nonatomic, assign) CGFloat zoom;
@property (nonatomic, assign) NSInteger autoFocus;
@property (nonatomic, assign) float focusDepth;
@property (nonatomic, assign) NSInteger whiteBalance;
@property (assign, nonatomic) AVCaptureSessionPreset pictureSize;

@property (nonatomic, assign) BOOL isReadingBarCodes;
@property (nonatomic, assign) BOOL isDetectingFaces;

- (id)initWithModuleRegistry:(ABI29_0_0EXModuleRegistry *)moduleRegistry;
- (void)updateType;
- (void)updateFlashMode;
- (void)updateFocusMode;
- (void)updateFocusDepth;
- (void)updateZoom;
- (void)updateWhiteBalance;
- (void)updatePictureSize;
- (void)updateFaceDetectorSettings:(NSDictionary *)settings;
- (void)takePicture:(NSDictionary *)options resolve:(ABI29_0_0EXPromiseResolveBlock)resolve reject:(ABI29_0_0EXPromiseRejectBlock)reject;
- (void)record:(NSDictionary *)options resolve:(ABI29_0_0EXPromiseResolveBlock)resolve reject:(ABI29_0_0EXPromiseRejectBlock)reject;
- (void)stopRecording;
- (void)resumePreview;
- (void)pausePreview;
- (void)setupOrDisableBarcodeScanner;
- (void)onReady:(NSDictionary *)event;
- (void)onMountingError:(NSDictionary *)event;
- (void)onCodeRead:(NSDictionary *)event;
- (void)onPictureSaved:(NSDictionary *)event;

@end


