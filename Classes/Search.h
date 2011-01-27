//
//  Search.h
//  MobileLastFM
//
//  Created by Sam Steele on 12/1/10.
//  Copyright 2010 Last.fm. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface GlobalSearchDataSource : NSObject<UITableViewDataSource, UITableViewDelegate> {
	NSArray *_results;
	NSArray *_data;
}
-(void)search:(NSString *)query;
-(NSArray *)data;
-(void)clear;
@end

@interface RadioSearchDataSource : NSObject<UITableViewDataSource, UITableViewDelegate> {
	NSArray *_results;
	NSArray *_data;
}
-(void)search:(NSString *)query;
@end
