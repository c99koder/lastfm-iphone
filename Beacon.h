//
//  Beacon.h r69
//  Pinch Media Analytics Library
//
//  Created by Jesse Rohland on 4/6/08.
//  Copyright 2008 PinchMedia. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

// This is the key we respect in the user's preferences (NSUserDefaults)
// See http://resources.pinchmedia.com/ for more information.
#define kEnablePinchMediaStatsCollection @"kEnablePinchMediaStatsCollection"

@interface Beacon : NSObject <CLLocationManagerDelegate> {}

+ (id)initAndStartBeaconWithApplicationCode:(NSString *)theApplicationCode useCoreLocation:(BOOL)coreLocation useOnlyWiFi:(BOOL)wifiState;
+ (void)endBeacon;
+ (id)shared;

- (void)startBeacon;
- (void)endBeacon;

- (void)startSubBeaconWithName:(NSString *)beaconName timeSession:(BOOL)trackSession;
- (void)endSubBeaconWithName:(NSString *)beaconName;

- (void)setBeaconLocation:(CLLocation *)newLocation;

@end
