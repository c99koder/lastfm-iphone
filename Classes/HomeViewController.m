//
//  HomeViewController.m
//  MobileLastFM
//
//  Created by Sam Steele on 11/17/10.
//  Copyright 2010 Last.fm. All rights reserved.
//

#import "HomeViewController.h"
#import "UIViewController+NowPlayingButton.h"
#import "MobileLastFMApplicationDelegate.h"

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
	if(self.navigationController) {
		for(int i = 0; i < [self.viewControllers count]; i++) {
			if([(UINavigationController *)[[[self.viewControllers objectAtIndex:i] viewControllers] objectAtIndex:0] isKindOfClass:[ProfileViewController class]]) {
				((UINavigationController *)[[[self.viewControllers objectAtIndex:i] viewControllers] objectAtIndex:0]).navigationItem.title = _username;
			}
			UIButton *btn = [[UIButton alloc] initWithFrame: CGRectMake(0, 0, 42, 30)];
			[btn setBackgroundImage:[UIImage imageNamed:@"blueBackBtn.png"] forState:UIControlStateNormal];
			btn.adjustsImageWhenHighlighted = YES;
			[btn addTarget:self action:@selector(backButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
			UIBarButtonItem *backBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView: btn];
			[btn release];
			((UINavigationController *)[[[self.viewControllers objectAtIndex:i] viewControllers] objectAtIndex:0]).navigationItem.leftBarButtonItem = backBarButtonItem;
			[backBarButtonItem release];
		}
	}
}
- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	self.navigationController.navigationBarHidden = NO;
}
- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
	[(UINavigationController *)tabBarController.selectedViewController popToRootViewControllerAnimated:NO];
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
