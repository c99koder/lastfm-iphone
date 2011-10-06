/* DebugViewController.m - Displays debug statistics
 * 
 * Copyright 2011 Last.fm Ltd.
 *   - Primarily authored by Sam Steele <sam@last.fm>
 *
 * This file is part of MobileLastFM.
 *
 * MobileLastFM is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * MobileLastFM is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with MobileLastFM.  If not, see <http://www.gnu.org/licenses/>.
 */

#import "DebugViewController.h"
#import "LastFMRadio.h"
#import "LastFMService.h"

@implementation DebugViewController

- (void)viewDidLoad {
	_timer = [NSTimer scheduledTimerWithTimeInterval:0.25 target:self selector:@selector(update) userInfo:nil repeats:YES];
	_log.text = [NSString stringWithContentsOfFile:CACHE_FILE(@"debug.log") encoding:NSUTF8StringEncoding error:nil];
  [super viewDidLoad];
}
-(void)update {
	_httpBuffers.text = [NSString stringWithFormat:@"%.0f KB", (float)[[[LastFMRadio sharedInstance] currentTrack] httpBufferSize] / 1024.0f];
	_audioBuffers.text = [NSString stringWithFormat:@"%i", [[[LastFMRadio sharedInstance] currentTrack] audioBufferCount]];
	_errorCode.text = [NSString stringWithFormat:@"%i", [LastFMService sharedInstance].error.code];
	_errorMsg.text = [[LastFMService sharedInstance].error.userInfo objectForKey:NSLocalizedDescriptionKey];
}
-(IBAction)uploadLogs:(id)sender {
	[[NSData dataWithContentsOfFile:CACHE_FILE(@"debug.log")] writeToFile:CACHE_FILE(@"crash.log") atomically:YES];
	[NSThread detachNewThreadSelector:@selector(sendCrashReport) toTarget:[UIApplication sharedApplication].delegate withObject:nil];
}
- (void)dealloc {
	[_timer invalidate];
  [super dealloc];
}


@end
