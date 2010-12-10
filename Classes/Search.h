//
//  Search.h
//  MobileLastFM
//
//  Created by Sam Steele on 12/1/10.
//  Copyright 2010 Last.fm. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface GlobalSearchDataSource : NSObject<UITableViewDataSource, UITableViewDelegate> {
	NSArray *_artists;
	NSArray *_tags;
	NSArray *_data;
}
-(void)search:(NSString *)query;
@end

@interface RadioSearchDataSource : NSObject<UITableViewDataSource, UITableViewDelegate> {
	NSArray *_artists;
	NSArray *_tags;
	NSArray *_data;
}
-(void)search:(NSString *)query;
@end
