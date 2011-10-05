//
//  PosterViewController.h
//  Festivals
//
//  Created by Sam Steele on 6/16/11.
//  Copyright 2011 Last.fm. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface PosterViewController : UIViewController<UIScrollViewDelegate> {
	UIImageView *_poster;
	UIScrollView *_scrollView;
	NSDictionary *_event;
}

-(id)initWithEvent:(NSDictionary *)event;

@end
