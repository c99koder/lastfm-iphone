/* HomeViewController.m - Display the home screen
 * 
 * Copyright 2011 Last.fm Ltd.
 *   - Primarily authored by Sam Steele <sam@last.fm>
 *
 * This file is part of MobileLastFM.
 *
 * MobileLastFM is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * MobileLastFM is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with MobileLastFM.  If not, see <http://www.gnu.org/licenses/>.
 */

#import "HomeViewController.h"
#import "UIViewController+NowPlayingButton.h"
#import "MobileLastFMApplicationDelegate.h"
#if !(TARGET_IPHONE_SIMULATOR)
#import "FlurryAnalytics.h"
#endif

@implementation HomeViewController

-(id)initWithUsername:(NSString *)user {
	if (self = [super init]) {
		_username = [user retain];
		self.title = _username;
		self.delegate = self;
		self.hidesBottomBarWhenPushed = YES;
		ProfileViewController *profileController = [[ProfileViewController alloc] initWithUsername:_username];
		EventsTabViewController *eventsController = [[EventsTabViewController alloc] initWithUsername:_username];
		RadioListViewController *radioController = [[RadioListViewController alloc] initWithUsername:_username];
		SearchTabViewController *searchController = [[SearchTabViewController alloc] initWithStyle:UITableViewStylePlain];
		
		if(![_username isEqualToString:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]]) {
			eventsController.navigationItem.title = [NSString stringWithFormat:@"%@'s Events", _username];
			radioController.navigationItem.title = [NSString stringWithFormat:@"%@'s Radio", _username];
			[self setViewControllers:[NSArray arrayWithObjects:[[[UINavigationController alloc] initWithRootViewController:profileController] autorelease],
																[[[UINavigationController alloc] initWithRootViewController:eventsController] autorelease],
																[[[UINavigationController alloc] initWithRootViewController:searchController] autorelease],
																[[[UINavigationController alloc] initWithRootViewController:radioController] autorelease], nil]];
		} else {
			RecsViewController *recsController = [[RecsViewController alloc] initWithUsername:_username];
			[self setViewControllers:[NSArray arrayWithObjects:[[[UINavigationController alloc] initWithRootViewController:profileController] autorelease],
																[[[UINavigationController alloc] initWithRootViewController:recsController] autorelease],
																[[[UINavigationController alloc] initWithRootViewController:eventsController] autorelease],
																[[[UINavigationController alloc] initWithRootViewController:searchController] autorelease],
																[[[UINavigationController alloc] initWithRootViewController:radioController] autorelease], nil]];
			[recsController release];
		}

#if !(TARGET_IPHONE_SIMULATOR)
		for(int i = 0; i < [self.viewControllers count]; i++) {
			[FlurryAnalytics logAllPageViews:[self.viewControllers objectAtIndex:i]];
		}			
#endif
		
		[profileController release];
		[eventsController release];
		[radioController release];
		[searchController release];
		return self;
	}
	return nil;
}
- (void)backButtonPressed:(id)sender {
	self.navigationController.navigationBarHidden = NO;
	[self.navigationController popViewControllerAnimated:YES];
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	self.navigationController.navigationBarHidden = YES;
}
- (void)setBackButton:(UIImage *)image {
	for(int i = 0; i < [self.viewControllers count]; i++) {
		if([(UINavigationController *)[[[self.viewControllers objectAtIndex:i] viewControllers] objectAtIndex:0] isKindOfClass:[ProfileViewController class]]) {
			((UINavigationController *)[[[self.viewControllers objectAtIndex:i] viewControllers] objectAtIndex:0]).navigationItem.title = _username;
		}
		UIButton *btn = [[UIButton alloc] initWithFrame: CGRectMake(0, 0, image.size.width, image.size.height)];
		[btn setBackgroundImage:image forState:UIControlStateNormal];
		btn.adjustsImageWhenHighlighted = YES;
		[btn addTarget:self action:@selector(backButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
		UIBarButtonItem *backBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView: btn];
		[btn release];
		((UINavigationController *)[[[self.viewControllers objectAtIndex:i] viewControllers] objectAtIndex:0]).navigationItem.leftBarButtonItem = backBarButtonItem;
		[backBarButtonItem release];
	}
}
- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	self.navigationController.navigationBarHidden = NO;
}
- (BOOL)tabBarController:(UITabBarController *)tabBarController shouldSelectViewController:(UIViewController *)viewController {
	[(UINavigationController *)tabBarController.selectedViewController popToRootViewControllerAnimated:NO];
	return YES;
}
- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc. that aren't in use.
}

- (void)dealloc {
	[super dealloc];
	[_username release];
}


@end
