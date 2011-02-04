/* UITableViewCell+ProgressIndicator.m - Show/hide a progress spinner on a table cell
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
		if(self.detailTextLabel.textAlignment == UITextAlignmentRight)
			self.detailTextLabel.text = @"";
		[progress release];
		[progressView release];
	} else {
		self.accessoryView = nil;
	}
}
@end
