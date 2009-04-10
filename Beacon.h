//
//  Beacon.h r39
//  PinchMedia
//
//  Created by Jesse Rohland on 4/6/08.
//  Copyright 2008 PinchMedia. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

@interface Beacon : NSObject <CLLocationManagerDelegate> {
	NSString			*applicationCode;
	BOOL				beaconStarted;
	BOOL				uploading;
	BOOL				pathFlag;
	BOOL				useWiFi;
	BOOL				useCoreLocation;
	CLLocationManager	*locationManager;
	NSURLConnection		*connection;
	NSMutableData		*receivedData;
}


+ (id)initAndStartBeaconWithApplicationCode:(NSString *)theApplicationCode useCoreLocation:(BOOL)coreLocation useOnlyWiFi:(BOOL)wifiState;
+ (void)endBeacon;
+ (id)shared;

- (void)startBeacon;
- (void)endBeacon;

- (void)startSubBeaconWithName:(NSString *)beaconName timeSession:(BOOL)trackSession;
- (void)endSubBeaconWithName:(NSString *)beaconName;

- (void)setBeaconLocation:(CLLocation *)newLocation;

@end
