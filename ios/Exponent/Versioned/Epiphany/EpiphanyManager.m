#import "EpiphanyManager.h"

#import "EXGLViewManager.h"
#import "EXGLView.h"

#include "math.h"

#import <CoreLocation/CLLocationManager.h>
#import <ARKit/ARKit.h>
#import <Vision/Vision.h>
#import <React/RCTLog.h>
#import <React/RCTUIManager.h>

#import <Epiphany/Epiphany.h>

/****************************************************************************************************
 * NOTE(AK): The GPS functionality here is hastily done. It may make more sense to just use Expo's
 * Location services directly and pass the result in to the enqueueSensorPacket call. Of course
 * eventually we may as well make sure our implementation here is good.
 ****************************************************************************************************/

@interface EpiphanyManager ()
@property (nonatomic, weak) ARSession *arSession;
@property (strong, nonatomic) CLLocationManager *locationManager;
@property double lastTime;
@end

@implementation EpiphanyManager

@synthesize bridge = _bridge;

int Sign(float x)
{
  if (x < 0) return -1;
  else return 1;
}

void QuaternionFromMatrix(matrix_float4x4 m, float* rw, float* rx, float* ry, float* rz)
{
  float m00 = m.columns[0].x;
  float m11 = m.columns[1].y;
  float m22 = m.columns[2].z;
  float m21 = m.columns[1].z;
  float m12 = m.columns[2].y;
  float m02 = m.columns[2].x;
  float m20 = m.columns[0].z;
  float m10 = m.columns[0].y;
  float m01 = m.columns[1].x;
  
  
  *rw = sqrt( MAX( 0, (1 + m00 + m11 + m22 )) ) / 2;
  *rx = sqrt( MAX( 0, (1 + m00 - m11 - m22 )) ) / 2;
  *ry = sqrt( MAX( 0, (1 - m00 + m11 - m22 )) ) / 2;
  *rz = sqrt( MAX( 0, (1 - m00 - m11 + m22 )) ) / 2;
  *rx *= Sign( *rx * ( m21 - m12 ) );
  *ry *= Sign( *ry * ( m02 - m20 ) );
  *rz *= Sign( *rz * ( m10 - m01 ) );
}

void PositionFromMatrix(matrix_float4x4 m, float* x, float* y, float* z)
{
  *x = m.columns[3].x;
  *y = m.columns[3].y;
  *z = m.columns[3].z;
}
RCT_EXPORT_MODULE(EpiphanyManager)

RCT_REMAP_METHOD(turnOnGPS,
                 turnOnGPSWithOptions: (NSDictionary *)options
                             resolver: (RCTPromiseResolveBlock)resolve
                             rejecter: (RCTPromiseRejectBlock)reject)
{
  _lastTime = 0;

  RCTLogInfo(@"Turning on GPS!");
  _locationManager = [[CLLocationManager alloc] init];
  [_locationManager setDelegate:self];
  [_locationManager setDistanceFilter:kCLDistanceFilterNone];
  [_locationManager setDesiredAccuracy:kCLLocationAccuracyThreeKilometers];
  // Set a movement threshold for new events.
  [_locationManager requestWhenInUseAuthorization];
  [_locationManager startUpdatingLocation];
  resolve(@"success");
  RCTLogInfo(@"GPS turned on!");
}

RCT_EXPORT_METHOD(turnOffGPS)
{
  [_locationManager stopUpdatingLocation];
  self.locationManager = nil;
  _lastTime = 0;
}

RCT_EXPORT_METHOD(detectQRCode)
{
  CVPixelBufferRef pixelBuffer = self.arSession.currentFrame.capturedImage;
  VNDetectBarcodesRequest *req = [[VNDetectBarcodesRequest alloc] initWithCompletionHandler:(VNRequestCompletionHandler) ^(VNRequest *request, NSError *error){
    dispatch_async(dispatch_get_main_queue(), ^{
      RCTLogInfo(@"Detect Barcodes Request Handler!");
      RCTLogInfo(@"Result count %d", request.results.count);
      if (request.results.count > 0)
      {
        VNBarcodeObservation *obs = (VNBarcodeObservation *)request.results[0];
        RCTLogInfo(obs.payloadStringValue);
        RCTLogInfo(@"%f, %f", obs.bottomLeft.x, obs.bottomLeft.y);
      }

    });
  }];
  
  NSArray *reqArray = @[req];
  NSDictionary *options = [[NSDictionary alloc] init];

  VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCVPixelBuffer:pixelBuffer options:options];
  
  dispatch_async(dispatch_get_main_queue(), ^{
    [handler performRequests:reqArray error:nil];
  });
  
  CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
  
}

RCT_REMAP_METHOD(openAtlasConnection,
                 openAtlasConnectionWithOptions: (NSDictionary *)options
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  NSString *sensor_packet_url = [RCTConvert NSString:options[@"sensor_packet_url"]];
  int session_id = [RCTConvert int:options[@"session_id"]];
  int num_workers = [RCTConvert int:options[@"num_workers"]];
  int max_images = [RCTConvert int:options[@"max_images"]];
  int map_id = [RCTConvert int:options[@"map_id"]];

  int connection_handle = epiphany_openAtlasConnection(
        [sensor_packet_url UTF8String],
        session_id,
        num_workers,
        max_images,
        map_id
        );

  if (connection_handle < 0)
  {
    NSString *errMsg = @"Unable to open atlas connection.";
    reject(@"E_ATLAS_CONNECTION_FAILURE", errMsg, RCTErrorWithMessage(errMsg));
  }
  else
  {
    NSInteger hdl = (NSInteger)connection_handle;
    NSDictionary *response = @{ @"connection_handle" : @(hdl)};

    resolve(response);
  }
}

RCT_REMAP_METHOD(closeAtlasConnection,
                 closeAtlasConnectionWithHandle:(nonnull NSNumber *)connectionHandle
                                          flush:(BOOL)flushQueue
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{

  int connection_handle = [connectionHandle intValue];
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      epiphany_closeAtlasConnection(connection_handle, flushQueue);
      resolve(@"success");
      });
}


RCT_REMAP_METHOD(openOfflineAtlasConnection,
                 openOfflineAtlasConnectionWithOptions: (NSDictionary *)options
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  NSString *cache_dir = [RCTConvert NSString:options[@"cache_dir"]];
  int num_workers = [RCTConvert int:options[@"num_workers"]];
  int max_images = [RCTConvert int:options[@"max_images"]];


  int connection_handle = epiphany_openOfflineAtlasConnection(
        [cache_dir UTF8String],
        num_workers,
        max_images
        );

  if (connection_handle < 0)
  {
    NSString *errMsg = @"Unable to open atlas connection.";
    reject(@"E_ATLAS_CONNECTION_FAILURE", errMsg, RCTErrorWithMessage(errMsg));
  }
  else
  {
    NSInteger hdl = (NSInteger)connection_handle;
    NSDictionary *response = @{ @"connection_handle" : @(hdl)};

    resolve(response);
  }
}


RCT_EXPORT_METHOD(helloWorld) {
  int hello_world = 3;//epiphany_hello_world();
  RCTLogInfo(@"hello world %d ", hello_world);
}

RCT_REMAP_METHOD(linkARSessionAsync,
                 linkARSessionAsyncWithReactTag:(nonnull NSNumber *)sessionId
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  EXGLViewManager *glViewManager = [self.bridge moduleForName:@"ExponentGLViewManager"];
  if (!glViewManager)
  {
    RCTLogInfo(@"glViewManager was null!");
    NSString *errMsg = @"EXGLViewManager not found!";
    reject(@"E_BAD_ARSESSION", errMsg, RCTErrorWithMessage(errMsg));
  }
  EXGLView* view = glViewManager.arSessions[sessionId];
  if (!view)
  {
    RCTLogInfo(@"EXGLView was null!");
    NSString *errMsg = @"EXGLView was not found!";
    reject(@"E_BAD_ARSESSION", errMsg, RCTErrorWithMessage(errMsg));
  }
  
  _arSession = (ARSession *)[view arSession];
  if (!_arSession)
  {
    RCTLogInfo(@"ARSession was null!");
    NSString *errMsg = @"ARSession was null!";
    reject(@"E_BAD_ARSESSION", errMsg, RCTErrorWithMessage(errMsg));
    
  }
  RCTLogInfo(@"Got an arsession!");
  resolve(@"Success");
}

RCT_REMAP_METHOD(enqueueSensorPacket,
                 enqueueSensorPacketWithHandle:(nonnull NSNumber *)connectionHandle
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  // get the pose
  matrix_float4x4 transform = [self.arSession.currentFrame.camera transform];
  
  epiphany_pose_measurement epiphany_pose_measurement;
  epiphany_pose *epiphany_p = &epiphany_pose_measurement.pose;
  QuaternionFromMatrix(transform, &epiphany_p->rw, &epiphany_p->rx, &epiphany_p->ry, &epiphany_p->rz);
  PositionFromMatrix(transform, &epiphany_p->x, &epiphany_p->y, &epiphany_p->z);

  // go to ubq format
  epiphany_arkitToUbq(*epiphany_p, epiphany_p);
  
  // get the image
  // TODO: use jpeg instead! There is some implementation in ubiquity/expo from Ryan.
  CVPixelBufferRef pixelBuffer = self.arSession.currentFrame.capturedImage;
  CVPixelBufferLockBaseAddress(pixelBuffer, 0);
  unsigned long numBytesY = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0) * CVPixelBufferGetHeightOfPlane(pixelBuffer,0);
  void* baseAddressY = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer,0);
  
  unsigned long numBytesUV = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1) * CVPixelBufferGetHeightOfPlane(pixelBuffer,1);
  void* baseAddressUV = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer,1);
  
  // we store as one block; it is useful anyways because this way we can unlock the base address asap.
  NSMutableData *nsData = [NSMutableData dataWithCapacity:numBytesY+numBytesUV];
  [nsData replaceBytesInRange:NSMakeRange(0, numBytesY) withBytes:baseAddressY];
  [nsData replaceBytesInRange:NSMakeRange(numBytesY,numBytesUV) withBytes:baseAddressUV];
  size_t width = CVPixelBufferGetWidth(pixelBuffer);
  size_t height = CVPixelBufferGetHeight(pixelBuffer);
  CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
  
  NSTimeInterval uptime = [NSProcessInfo processInfo].systemUptime;
  
  // Now since 1970
  NSTimeInterval nowTimeIntervalSince1970 = [[NSDate date] timeIntervalSince1970];
  
  // Voila our offset
  double ar_timestamp = (nowTimeIntervalSince1970 - uptime) + self.arSession.currentFrame.timestamp;

  // make the image
  epiphany_photo_measurement photo_measurement;
  photo_measurement.raw_buffer = [nsData bytes];
  photo_measurement.width = width;
  photo_measurement.height = height;
  photo_measurement.timestamp_seconds = ar_timestamp;
  epiphany_pose_measurement.timestamp_seconds = ar_timestamp;
  
  // now build the sensor packet.
  int connection_handle = [connectionHandle intValue];
  epiphany_startBuildingSensorPacket(connection_handle, 0);
  epiphany_addPose(connection_handle, epiphany_pose_measurement, 0);
  epiphany_addPhoto(connection_handle, photo_measurement, 0);


  if (_locationManager != nil)
  {
    CLLocation *lastKnown = [_locationManager location];
    double gpstime_seconds = [lastKnown.timestamp timeIntervalSince1970];
    if (gpstime_seconds > _lastTime)
    {
      _lastTime = gpstime_seconds;
      epiphany_gps_measurement gps_measurement;
      gps_measurement.timestamp_seconds = gpstime_seconds;
      gps_measurement.lat = lastKnown.coordinate.latitude;
      gps_measurement.lon = lastKnown.coordinate.longitude;
      gps_measurement.alt = lastKnown.altitude;
      gps_measurement.horizontal_accuracy = lastKnown.horizontalAccuracy;
      gps_measurement.vertical_accuracy = lastKnown.verticalAccuracy;
      RCTLogInfo(@"Adding GPS!");
      epiphany_addGPS(connection_handle, gps_measurement, 0);
    }
  }

  int sp_id = epiphany_finalizeSensorPacket(connection_handle, 0);
  NSInteger hdl = (NSInteger)sp_id;
  NSDictionary *response = @{ @"sensor_packet_id" : @(hdl)};

  resolve(response);
}

RCT_REMAP_METHOD(addSensorPacketCache,
                 addSensorPacketCacheWithHandle:(nonnull NSNumber *)connectionHandle
                                       cacheDir:(nonnull NSString *)cacheDirectory
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  
  // now build the sensor packet.
  int connection_handle = [connectionHandle intValue];
  epiphany_addSensorPacketCache(connection_handle, [cacheDirectory UTF8String]);

  resolve(@"success");
}


RCT_REMAP_METHOD(getTrackingUpdateIdentifier,
                 getTrackingUpdateIdentifierWithHandle:(nonnull NSNumber *)connectionHandle
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  int identifier = epiphany_getTrackingUpdateIdentifier([connectionHandle intValue]);
  NSInteger hdl = (NSInteger)identifier;
  NSDictionary *response = @{ @"tracking_update_identifier" : @(hdl)};
  resolve(response);
}

RCT_REMAP_METHOD(getSensorPacketStatus,
                 getSensorPacketStatusWithHandle:(nonnull NSNumber *)connectionHandle
                 sensorPacketId:(nonnull NSNumber *)sensorPacketId
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  int status = epiphany_getSensorPacketStatus(
      [connectionHandle intValue],
      [sensorPacketId intValue]
      );

  
  if (status == 0)
  {
    NSDictionary *response = @{ @"status" : @"pending"};
    resolve(response);
  }
  else if (status == 1)
  {
    NSDictionary *response = @{ @"status" : @"success"};
    resolve(response);
  }
  else if (status == 2)
  {
    NSDictionary *response = @{ @"status" : @"failure"};
    resolve(response);
  }
  else
  {
    NSString *errMsg = @"Unknown status int.";
    reject(@"E_UNKNOWN_FAILURE", errMsg, RCTErrorWithMessage(errMsg));
  }
}



@end
