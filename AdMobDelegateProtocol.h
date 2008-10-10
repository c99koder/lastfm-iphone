/**
 * AdMobDelegateProtocol.h
 * AdMob iPhone SDK publisher code.
 *
 * Defines the AdMobDelegate protocol.
 */
@class AdMobView;

@protocol AdMobDelegate<NSObject>

@required

// Use this to provide a publisher id for an ad request. Get a publisher id
// from http://www.admob.com
- (NSString *)publisherId;

@optional

// Sent when an ad request loaded an ad; this is a good opportunity to add
// this view to the hierachy, if it has not yet been added.
// Note that this will only ever be sent once per AdMobView, regardless of whether
// new ads are subsequently requested in the same AdMobView.
- (void)didReceiveAd:(AdMobView *)adView;

// Sent when an ad request failed to load an ad.
// Note that this will only ever be sent once per AdMobView, regardless of whether
// new ads are subsequently requested in the same AdMobView.
- (void)didFailToReceiveAd:(AdMobView *)adView;

// Specifies the ad background color, for tile+text ads.
// Defaults to [UIColor colorWithRed:0.443 green:0.514 blue:0.631 alpha:1], which is a chrome-y color.
// Note that the alpha channel in the provided color will be ignored and treated as 1.
// We recommend against using a white or very light color as the background color, but
// if you do, be sure to implement adTextColor and useGraySpinner.
// Grayscale colors won't function correctly here. Use e.g. [UIColor colorWithRed:0 green:0 blue:0 alpha:1]
// instead of [UIColor colorWithWhite:0 alpha:1] or [UIColor blackColor].
- (UIColor *)adBackgroundColor;

// Specifies the ad text color, for tile+text ads.
// Defaults to [UIColor whiteColor].
// Note that the alpha channel in the provided color will be ignored and treated as 1.
- (UIColor *)adTextColor;

// When a spinner is shown over the adBackgroundColor (e.g. on clicks), it is by default
// a white spinner. If this returns YES, a gray spinner will be used instead,
// which looks better when the adBackgroundColor is white or very light in color.
- (BOOL)useGraySpinner;

// Whether AdMob may request location information from the phone. Defaults to NO.
// We ask that you respect your users' privacy and only enable location requests
// if your app already uses location information.
// Note that even if this is set to no, you will still need to include the CoreLocation
// framework to compile your app; it will simply not get used. (It is a dynamic
// framework, so including it will not increase the size of your app.)
- (BOOL)mayAskForLocation;

// If implemented, lets you specify whether to issue a real ad request or a test
// ad request (to be used for development only, of course). Defaults to NO.
- (BOOL)useTestAd;

// The following functions, if implemented, provide extra information
// for the ad request. If you happen to have this information, providing it will
// help select better targeted ads and will improve monetization.
// Note that providing a search string may seriously negatively impact your fill rate; we
// recommend using it only when the user is submitting a free-text search request
// and you want to _only_ display ads relevant to that search. In those situations,
// however, providing a search string can yield a significant monetization boost.
- (NSString *)postalCode; // user's postal code, e.g. "94401"
- (NSString *)areaCode; // user's area code, e.g. "415"
- (NSDate *)dateOfBirth; // user's date of birth
- (NSString *)gender; // user's gender (e.g. @"m" or @"f")
- (NSString *)searchString; // a search string the user has provided

// Sent just before presenting a canvas page. Use this opportunity to (say)
// stop animations, time sensitive interactions, etc.
- (void)willPresentModalCanvas;

// Sent just after dismissing a canvas page. Use this opportunity to
// restart anything you may have stopped as part of -willPresentModalCanvas:.
- (void)didDismissModalCanvas;

@end