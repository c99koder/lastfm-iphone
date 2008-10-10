/**
 * AdMobView.h
 * AdMob iPhone SDK publisher code.
 *
 * The entry point for requesting an AdMob ad to display.
 */
#import <UIKit/UIKit.h>

@protocol AdMobDelegate;

@interface AdMobView : UIView

/**
 * Initiates an ad request and returns a view that will contain the results;
 * the delegate is alerted when the ad is ready to display (or has failed to
 * load); this is a good opportunity to attach the view to your hierarchy.
 * If you already have a AdMobView with an ad loaded, and simply want to show
 * a new ad in the same location, you may use -requestFreshAd instead (see below).
 *
 * This method should only be called from a run loop in default run loop mode.
 * If you don't know what that means, you're probably ok. If in doubt, check
 * whether ([[NSRunLoop currentRunLoop] currentMode] == NSDefaultRunLoopMode).
 */
+ (AdMobView *)requestAdWithDelegate:(id<AdMobDelegate>)delegate;

/**
 * Causes an existing AdMobView to display a fresh ad. If an ad successfully loads,
 * it is animated in with a flip; if not, this call fails silently and the old
 * ad remains onscreen.
 *
 * Note that, during the flip, views under the AdMobView will be exposed.
 *
 * To preserve the user experience, we recommend loading fresh ads no more
 * frequently than once per minute.
 */
- (void)requestFreshAd;

@end