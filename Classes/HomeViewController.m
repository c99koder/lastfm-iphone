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

@synthesize tabBarController;

-(id)initWithUsername:(NSString *)user {
	if (self = [super init]) {
		_username = [user retain];
		self.title = _username;
		self.hidesBottomBarWhenPushed = YES;
		return self;
	}
	return nil;
}
/*- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	
	switch(_tabBar.selectedItem.tag) {
		case 0:
			[_profileController viewWillDisappear:animated];
			break;
		case 1:
			[_recsController viewWillDisappear:animated];
			break;
		case 2:
			[_eventsController viewWillDisappear:animated];
			break;
		case 3:
			[_radioController viewWillDisappear:animated];
			break;
		case 4:
			[_searchController viewWillDisappear:animated];
			break;
	}
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	if(_tabBar.selectedItem.tag != 1)
		[self showNowPlayingButton:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate isPlaying]];
	
	switch(_tabBar.selectedItem.tag) {
		case 0:
			[_profileController viewWillAppear:animated];
			break;
		case 1:
			[_recsController viewWillAppear:animated];
			self.navigationItem.titleView = _recsController.navigationItem.titleView;
			self.navigationItem.rightBarButtonItem = _recsController.navigationItem.rightBarButtonItem;
			break;
		case 2:
			[_eventsController viewWillAppear:animated];
			break;
		case 3:
			[_radioController viewWillAppear:animated];
			break;
		case 4:
			[_searchController viewWillAppear:animated];
			break;
	}
}*/
- (void)loadView {
	UIView *contentView = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
	contentView.backgroundColor = [UIColor groupTableViewBackgroundColor];
	self.view = contentView;
	[contentView release];
	
	ProfileViewController *profileController = [[ProfileViewController alloc] initWithUsername:_username];
	EventsTabViewController *eventsController = [[EventsTabViewController alloc] initWithUsername:_username];
	RadioListViewController *radioController = [[RadioListViewController alloc] initWithUsername:_username];
	SearchTabViewController *searchController = [[SearchTabViewController alloc] initWithStyle:UITableViewStylePlain];
	UIButton *btn = [[UIButton alloc] initWithFrame: CGRectMake(0, 0, 42, 30)];
	[btn setBackgroundImage:[UIImage imageNamed:@"blueBackBtn.png"] forState:UIControlStateNormal];
	btn.adjustsImageWhenHighlighted = YES;
	[btn addTarget:self action:@selector(backButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
	UIBarButtonItem *backBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView: btn];
	[btn release];
	
	if(self.navigationController) {
		profileController.navigationItem.title = _username;
		profileController.navigationItem.leftBarButtonItem = backBarButtonItem;
		eventsController.navigationItem.leftBarButtonItem = backBarButtonItem;
		radioController.navigationItem.leftBarButtonItem = backBarButtonItem;
		searchController.navigationItem.leftBarButtonItem = backBarButtonItem;
		self.navigationItem.backBarButtonItem = backBarButtonItem;
	}
	
	tabBarController = [[UITabBarController alloc] init];
	tabBarController.delegate = self;
	tabBarController.view.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
	
	if(![_username isEqualToString:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]]) {
		[tabBarController setViewControllers:[NSArray arrayWithObjects:[[[UINavigationController alloc] initWithRootViewController:profileController] autorelease],
																						[[[UINavigationController alloc] initWithRootViewController:eventsController] autorelease],
																						[[[UINavigationController alloc] initWithRootViewController:searchController] autorelease],
																						[[[UINavigationController alloc] initWithRootViewController:radioController] autorelease], nil]];
	} else {
		RecsViewController *recsController = [[RecsViewController alloc] initWithUsername:_username];
		if(self.navigationController) {
			recsController.navigationItem.backBarButtonItem = backBarButtonItem;
		}
		[tabBarController setViewControllers:[NSArray arrayWithObjects:[[[UINavigationController alloc] initWithRootViewController:profileController] autorelease],
																					[[[UINavigationController alloc] initWithRootViewController:recsController] autorelease],
																					[[[UINavigationController alloc] initWithRootViewController:eventsController] autorelease],
																					[[[UINavigationController alloc] initWithRootViewController:searchController] autorelease],
																					[[[UINavigationController alloc] initWithRootViewController:radioController] autorelease], nil]];
		[recsController release];
	}

	[profileController viewWillAppear: YES];
	[self.view addSubview: tabBarController.view];
	
	[profileController release];
	[eventsController release];
	[radioController release];
	[searchController release];
	[backBarButtonItem release];
	
	self.navigationController.navigationBarHidden = YES;
}
- (void)backButtonPressed:(id)sender {
	[tabBarController.view removeFromSuperview];
	self.navigationController.navigationBarHidden = NO;
	[self.navigationController popViewControllerAnimated:YES];
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[tabBarController selectedViewController] viewWillAppear:animated];
	self.navigationController.navigationBarHidden = YES;
}
-(void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
	[viewController viewWillAppear: YES];
}
/*
-(void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item {
	if(item.tag != currentTab) {
		switch(currentTab) {
			case 0:
				[_profileController viewWillDisappear:NO];
				break;
			case 1:
				[_recsController viewWillDisappear:NO];
				break;
			case 2:
				[_eventsController viewWillDisappear:NO];
				break;
			case 3:
				[_radioController viewWillDisappear:NO];
				break;
			case 4:
				[_searchController viewWillDisappear:NO];
				break;
		}
	}
	currentTab = item.tag;
	[[_contentView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
	if(item.tag != 1)
		[self showNowPlayingButton:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate isPlaying]];
	
	switch(item.tag) {
		case 0:
			self.title = _profileController.title;
			self.navigationItem.titleView = nil;
			self.navigationItem.backBarButtonItem = nil;
			[_profileController viewWillAppear:NO];
			_profileController.view.frame = CGRectMake(0,0,_contentView.frame.size.width,_contentView.frame.size.height);
			[_contentView addSubview:_profileController.view];
			break;
		case 1:
			self.navigationItem.titleView = _recsController.navigationItem.titleView;
			self.navigationItem.rightBarButtonItem = _recsController.navigationItem.rightBarButtonItem;
			//self.title = _recsController.title;
			self.navigationItem.backBarButtonItem = _recsController.navigationItem.backBarButtonItem;
			[_recsController viewWillAppear:NO];
			_recsController.view.frame = CGRectMake(0,0,_contentView.frame.size.width,_contentView.frame.size.height);
			[_contentView addSubview:_recsController.view];
			break;
		case 2:
			self.title = _eventsController.title;
			self.navigationItem.titleView = nil;
			self.navigationItem.backBarButtonItem = nil;
			[_eventsController viewWillAppear:NO];
			_eventsController.view.frame = CGRectMake(0,0,_contentView.frame.size.width,_contentView.frame.size.height);
			[_contentView addSubview:_eventsController.view];
			break;
		case 3:
			self.title = _radioController.title;
			self.navigationItem.titleView = nil;
			self.navigationItem.backBarButtonItem = nil;
			[_radioController viewWillAppear:NO];
			_radioController.view.frame = CGRectMake(0,0,_contentView.frame.size.width,_contentView.frame.size.height);
			[_contentView addSubview:_radioController.view];
			break;
		case 4:
			self.title = _searchController.title;
			self.navigationItem.titleView = nil;
			self.navigationItem.backBarButtonItem = nil;
			[_searchController viewWillAppear:NO];
			_searchController.view.frame = CGRectMake(0,0,_contentView.frame.size.width,_contentView.frame.size.height);
			[_contentView addSubview:_searchController.view];
			break;
	}
}
*/
/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations.
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc. that aren't in use.
}

- (void)viewDidUnload {
  [super viewDidUnload];
	[tabBarController release];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
	/*[_profileController release];
	_profileController = nil;
	[_eventsController release];
	_eventsController = nil;
	[_radioController release];
	_radioController = nil;
	[_recsController release];
	_recsController = nil;
	[_searchController release];
	_searchController = nil;
	_tabBar = nil;
	currentTab = 0;*/
}


- (void)dealloc {
	[super dealloc];
	[tabBarController release];
	[_username release];
	/*[_profileController release];
	[_eventsController release];
	[_radioController release];
	[_recsController release];*/
}


@end
