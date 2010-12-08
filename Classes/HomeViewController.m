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
	if (self = [super initWithNibName:@"HomeViewController" bundle:nil]) {
		_username = [user retain];
		return self;
	}
	return nil;
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self showNowPlayingButton:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate isPlaying]];
	switch(_tabBar.selectedItem.tag) {
		case 0:
			[_profileController viewWillAppear:animated];
			break;
		case 1:
			[_recsController viewWillAppear:animated];
			break;
		case 2:
			[_eventsController viewWillAppear:animated];
			break;
		case 3:
			[_radioController viewWillAppear:animated];
			break;
		case 4:
			[_friendsController viewWillAppear:animated];
			break;
	}
}
- (void)viewDidLoad {
	[super viewDidLoad];
	
	_profileController = [[ProfileViewController alloc] initWithUsername:_username];
	_eventsController = [[EventsTabViewController alloc] initWithUsername:_username];
	_radioController = [[RadioListViewController alloc] initWithUsername:_username];
	_friendsController = [[FriendsViewController alloc] initWithUsername:_username];
	_recsController = [[RecsViewController alloc] initWithUsername:_username];
	
	if(![_username isEqualToString:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]]) {
		NSMutableArray *array = [NSMutableArray arrayWithArray:_tabBar.items];
		[array removeObjectAtIndex:1];
		_tabBar.items = array;
	}
	
	_tabBar.selectedItem = [_tabBar.items objectAtIndex:0];
	[self tabBar:_tabBar didSelectItem:_tabBar.selectedItem];
}

-(void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item {
	[[_contentView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
	
	switch(item.tag) {
		case 0:
			self.title = _profileController.title;
			self.navigationItem.titleView = nil;
			[_profileController viewWillAppear:NO];
			_profileController.view.frame = CGRectMake(0,0,_contentView.frame.size.width,_contentView.frame.size.height);
			[_contentView addSubview:_profileController.view];
			break;
		case 1:
			self.navigationItem.titleView = _recsController.navigationItem.titleView;
			self.navigationItem.rightBarButtonItem = _recsController.navigationItem.rightBarButtonItem;
			//self.title = _recsController.title;
			[_recsController viewWillAppear:NO];
			_recsController.view.frame = CGRectMake(0,0,_contentView.frame.size.width,_contentView.frame.size.height);
			[_contentView addSubview:_recsController.view];
			break;
		case 2:
			self.title = _eventsController.title;
			self.navigationItem.titleView = nil;
			[_eventsController viewWillAppear:NO];
			_eventsController.view.frame = CGRectMake(0,0,_contentView.frame.size.width,_contentView.frame.size.height);
			[_contentView addSubview:_eventsController.view];
			break;
		case 3:
			self.title = _radioController.title;
			self.navigationItem.titleView = nil;
			[_radioController viewWillAppear:NO];
			_radioController.view.frame = CGRectMake(0,0,_contentView.frame.size.width,_contentView.frame.size.height);
			[_contentView addSubview:_radioController.view];
			break;
		case 4:
			self.navigationItem.titleView = _friendsController.navigationItem.titleView;
			self.navigationItem.leftBarButtonItem = nil;
			[_friendsController viewWillAppear:NO];
			_friendsController.view.frame = CGRectMake(0,0,_contentView.frame.size.width,_contentView.frame.size.height);
			[_contentView addSubview:_friendsController.view];
			break;
	}
}

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
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


- (void)dealloc {
	[super dealloc];
	[_profileController release];
	[_eventsController release];
	[_radioController release];
	[_friendsController release];
	[_recsController release];
}


@end
