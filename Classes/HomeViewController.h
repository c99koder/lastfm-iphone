//
//  HomeViewController.h
//  MobileLastFM
//
//  Created by Sam Steele on 11/17/10.
//  Copyright 2010 Last.fm. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ProfileViewController.h"
#import "EventsTabViewController.h"
#import "RadioListViewController.h"
#import "FriendsViewController.h"
#import "RecsViewController.h"
#import "SearchTabViewController.h"

@interface HomeViewController : UIViewController<UITabBarControllerDelegate> {
	UITabBarController *tabBarController;
	/*ProfileViewController *_profileController;
	RecsViewController *_recsController;
	EventsTabViewController *_eventsController;
	RadioListViewController *_radioController;
	SearchTabViewController *_searchController;*/
	NSString *_username;
	
	//int currentTab;
}
-(id)initWithUsername:(NSString *)user;
//-(void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item;

@property (nonatomic, retain) UITabBarController *tabBarController;

@end
