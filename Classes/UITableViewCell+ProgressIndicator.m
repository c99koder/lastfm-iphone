/* UITableViewCell+ProgressIndicator.m - Show/hide a progress spinner on a table cell
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

#import "UITableViewCell+ProgressIndicator.h"

@implementation UITableViewCell (ProgressIndicator)
- (void)showProgress:(BOOL)show {
	if(show) {
		UIActivityIndicatorView *progress = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
		UIView *progressView = [[UIView alloc] initWithFrame:CGRectMake(0,0,20,20)];
		[progressView addSubview: progress];
		if(self.accessoryView) {
			progressView.frame = self.accessoryView.bounds;
		}
		progress.center = progressView.center;
		[progress startAnimating];
		self.accessoryView = progressView;
		[progress release];
		[progressView release];
	} else {
		self.accessoryView = nil;
	}
}
@end
