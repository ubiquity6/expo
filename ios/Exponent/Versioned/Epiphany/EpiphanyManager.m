#import "EpiphanyManager.h"

#import "EXGLViewManager.h"
#import "EXGLView.h"

#include "math.h"

#import <ARKit/ARKit.h>
#import <React/RCTLog.h>
#import <React/RCTUIManager.h>

#import <Epiphany/Epiphany.h>

@interface EpiphanyManager ()
@property (nonatomic, weak) ARSession *arSession;
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

RCT_REMAP_METHOD(openAtlasConnection,
                 openAtlasConnectionWithOptions: (NSDictionary *)options
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  NSString *sensor_packet_url = [RCTConvert NSString:options[@"sensor_packet_url"]];
  int session_id = [RCTConvert int:options[@"session_id"]];
  NSString *device_identifier = [RCTConvert NSString:options[@"device_identifier"]];
  int earth_alignment = [RCTConvert int:options[@"earth_alignment"]];
  int num_workers = [RCTConvert int:options[@"num_workers"]];
  int max_images = [RCTConvert int:options[@"max_images"]];
  int map_id = [RCTConvert int:options[@"map_id"]];

  int connection_handle = epiphany_openAtlasConnection(
        [sensor_packet_url UTF8String],
        session_id,
        [device_identifier UTF8String],
        earth_alignment,
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

RCT_EXPORT_METHOD(enqueueSensorPacket:(nonnull NSNumber*)connectionHandle)
{
  // get the pose
  matrix_float4x4 transform = [self.arSession.currentFrame.camera transform];
  float rw = 1;
  float rx = 0;
  float ry = 0;
  float rz = 0;
  QuaternionFromMatrix(transform, &rw, &rx, &ry, &rz);
  float x = 0;
  float y = 0;
  float z = 0;
  PositionFromMatrix(transform, &x, &y, &z);
  
  
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
  
  // now build the sensor packet.
  int connection_handle = [connectionHandle intValue];
  epiphany_startBuildingSensorPacket(connection_handle, 0);
  epiphany_addPose(connection_handle, x, y, z, rw, rx, ry, rz, ar_timestamp, 0);
  epiphany_addPhoto(connection_handle, [nsData bytes], width, height, ar_timestamp, 0);
  epiphany_finalizeSensorPacket(connection_handle, 0);
}

@end
