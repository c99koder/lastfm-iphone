//
//  DebugViewController.m
//  MobileLastFM
//
//  Created by Sam Steele on 9/17/08.
//  Copyright 2008 Last.fm. All rights reserved.
//

#import "DebugViewController.h"
#import "LastFMRadio.h"
#import "LastFMService.h"

@implementation DebugViewController

- (void)viewDidLoad {
	_timer = [NSTimer scheduledTimerWithTimeInterval:0.25 target:self selector:@selector(update) userInfo:nil repeats:YES];
	_log.text = [NSString stringWithContentsOfFile:CACHE_FILE(@"debug.log")];
  [super viewDidLoad];
}
-(void)update {
	_httpBuffers.text = [NSString stringWithFormat:@"%.0f KB", (float)[[[LastFMRadio sharedInstance] currentTrack] httpBufferSize] / 1024.0f];
	_audioBuffers.text = [NSString stringWithFormat:@"%i", [[[LastFMRadio sharedInstance] currentTrack] audioBufferCount]];
	_errorCode.text = [NSString stringWithFormat:@"%i", [LastFMService sharedInstance].error.code];
	_errorMsg.text = [[LastFMService sharedInstance].error.userInfo objectForKey:NSLocalizedDescriptionKey];
}
-(IBAction)uploadLogs:(id)sender {
	[NSThread detachNewThreadSelector:@selector(sendCrashReport) toTarget:[UIApplication sharedApplication].delegate withObject:nil];
}
- (void)dealloc {
	[_timer invalidate];
  [super dealloc];
}


@end
