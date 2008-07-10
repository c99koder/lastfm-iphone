/* UIViewController+NowPlayingButton.m - Now Playing button methods
 * Copyright (C) 2008 Sam Steele
 *
 * This file is part of MobileLastFM.
 *
 * MobileLastFM is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2
 * as published by the Free Software Foundation.
 *
 * MobileLastFM is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA
 */

#import "MobileLastFMApplicationDelegate.h"
#import "UIViewController+NowPlayingButton.h"

@implementation UIViewController (NowPlayingButton)
-(void)showNowPlayingButton:(BOOL)show {
	if(show) {
		UIButton *btn = [[UIButton alloc] initWithFrame: CGRectMake(0, 0, 64, 30)];
		[btn setBackgroundImage:[UIImage imageNamed:@"now_playing_header.png"] forState:UIControlStateNormal];
		btn.adjustsImageWhenHighlighted = YES;
		[btn addTarget:self action:@selector(nowPlayingButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
		UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithCustomView: btn];
		self.navigationItem.rightBarButtonItem = item;
		[item release];
		[btn release];
	} else {
		self.navigationItem.rightBarButtonItem = nil;
	}
}
-(void)nowPlayingButtonPressed:(id)sender {
	[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) showPlaybackView];
}
@end
