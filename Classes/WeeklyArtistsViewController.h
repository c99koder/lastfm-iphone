//
//  WeeklyArtistsViewController.h
//  MobileLastFM
//
//  Created by Sam Steele on 1/26/11.
//  Copyright 2011 Last.fm. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface WeeklyArtistsViewController : UITableViewController {
	NSArray *_data;
	NSDate* _from;
	NSDate* _to;
	NSMutableDictionary *_images;
}
- (id)initWithUsername:(NSString *)username;
@end
