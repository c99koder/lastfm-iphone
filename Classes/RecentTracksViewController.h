//
//  RecentTracksViewController.h
//  MobileLastFM
//
//  Created by Sam Steele on 1/26/11.
//  Copyright 2011 Last.fm. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface RecentTracksViewController : UITableViewController {
	NSArray *_data;
}
- (id)initWithUsername:(NSString *)username;
@end
