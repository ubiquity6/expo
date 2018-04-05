//
//  ABI26_0_0AIRGoogleMap.h
//  AirMaps
//
//  Created by Gil Birman on 9/1/16.
//

#import <UIKit/UIKit.h>
#import <ReactABI26_0_0/ABI26_0_0RCTComponent.h>
#import <GoogleMaps/GoogleMaps.h>
#import <MapKit/MapKit.h>
#import "ABI26_0_0AIRGMSMarker.h"
#import "ABI26_0_0RCTConvert+AirMap.h"

@interface ABI26_0_0AIRGoogleMap : GMSMapView

// TODO: don't use MK region?
@property (nonatomic, assign) MKCoordinateRegion initialRegion;
@property (nonatomic, assign) MKCoordinateRegion region;
@property (nonatomic, assign) NSString *customMapStyleString;
@property (nonatomic, assign) UIEdgeInsets mapPadding;
@property (nonatomic, copy) ABI26_0_0RCTBubblingEventBlock onMapReady;
@property (nonatomic, copy) ABI26_0_0RCTBubblingEventBlock onPress;
@property (nonatomic, copy) ABI26_0_0RCTBubblingEventBlock onLongPress;
@property (nonatomic, copy) ABI26_0_0RCTBubblingEventBlock onMarkerPress;
@property (nonatomic, copy) ABI26_0_0RCTBubblingEventBlock onChange;
@property (nonatomic, copy) ABI26_0_0RCTDirectEventBlock onRegionChange;
@property (nonatomic, copy) ABI26_0_0RCTDirectEventBlock onRegionChangeComplete;
@property (nonatomic, strong) NSMutableArray *markers;
@property (nonatomic, strong) NSMutableArray *polygons;
@property (nonatomic, strong) NSMutableArray *polylines;
@property (nonatomic, strong) NSMutableArray *circles;
@property (nonatomic, strong) NSMutableArray *tiles;

@property (nonatomic, assign) BOOL showsBuildings;
@property (nonatomic, assign) BOOL showsTraffic;
@property (nonatomic, assign) BOOL showsCompass;
@property (nonatomic, assign) BOOL scrollEnabled;
@property (nonatomic, assign) BOOL zoomEnabled;
@property (nonatomic, assign) BOOL rotateEnabled;
@property (nonatomic, assign) BOOL pitchEnabled;
@property (nonatomic, assign) BOOL showsUserLocation;
@property (nonatomic, assign) BOOL showsMyLocationButton;
@property (nonatomic, assign) BOOL showsIndoorLevelPicker;

- (void)didPrepareMap;
- (BOOL)didTapMarker:(GMSMarker *)marker;
- (void)didTapPolyline:(GMSPolyline *)polyline;
- (void)didTapPolygon:(GMSPolygon *)polygon;
- (void)didTapAtCoordinate:(CLLocationCoordinate2D)coordinate;
- (void)didLongPressAtCoordinate:(CLLocationCoordinate2D)coordinate;
- (void)didChangeCameraPosition:(GMSCameraPosition *)position;
- (void)idleAtCameraPosition:(GMSCameraPosition *)position;

+ (MKCoordinateRegion)makeGMSCameraPositionFromMap:(GMSMapView *)map andGMSCameraPosition:(GMSCameraPosition *)position;
+ (GMSCameraPosition*)makeGMSCameraPositionFromMap:(GMSMapView *)map andMKCoordinateRegion:(MKCoordinateRegion)region;

@end
