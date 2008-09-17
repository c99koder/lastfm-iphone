//
//  DebugViewController.h
//  MobileLastFM
//
//  Created by Sam Steele on 9/17/08.
//  Copyright 2008 Last.fm. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface DebugViewController : UIViewController {
	IBOutlet UILabel *_httpBuffers;
	IBOutlet UILabel *_audioBuffers;
	IBOutlet UILabel  *_errorCode;
	IBOutlet UILabel *_errorMsg;
	IBOutlet UITextView *_log;
	NSTimer *_timer;
}
-(IBAction)uploadLogs:(id)sender;
@end
