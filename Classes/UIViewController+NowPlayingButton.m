/* UIViewController+NowPlayingButton.m - Now Playing button methods
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

#import "MobileLastFMApplicationDelegate.h"
#import "UIViewController+NowPlayingButton.h"

@implementation UIViewController (NowPlayingButton)
-(void)showNowPlayingButton:(BOOL)show {
	if(self.navigationController == ((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController.selectedViewController || self.tabBarController) {
		if(show) {
			UIButton *btn = [[UIButton alloc] initWithFrame: CGRectMake(0, 0, 61, 31)];
			if([((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate) isPaused])
				[btn setBackgroundImage:[UIImage imageNamed:@"nowpaused_fwd.png"] forState:UIControlStateNormal];
			else
				[btn setBackgroundImage:[UIImage imageNamed:@"nowplaying_fwd.png"] forState:UIControlStateNormal];
			btn.adjustsImageWhenHighlighted = YES;
			[btn addTarget:self action:@selector(nowPlayingButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
			UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithCustomView: btn];
			self.navigationItem.rightBarButtonItem = item;
			[item release];
			[btn release];
		} else {
			self.navigationItem.rightBarButtonItem = nil;
			if( [[UIApplication sharedApplication] respondsToSelector:@selector(endReceivingRemoteControlEvents)])
				[[UIApplication sharedApplication] endReceivingRemoteControlEvents];
		}
	}
}
-(void)nowPlayingButtonPressed:(id)sender {
	[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) showPlaybackView];
}
@end
