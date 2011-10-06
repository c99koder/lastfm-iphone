/* ButtonsCell.h - A table cell that contains some UIButtons
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

#import "ButtonsCell.h"

@implementation ButtonsCell

- (id)initWithReuseIdentifier:(NSString*)identifier buttons:(UIButton*)firstButton,... {
	if ( self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier] ) {
		va_list argumentList;
		if(firstButton) {
			_buttons = [[NSMutableArray alloc] init];

			[_buttons addObject: firstButton];
			[self.contentView addSubview:firstButton];
			
			va_start(argumentList, firstButton);
			UIButton* button;
			while ((button = va_arg(argumentList, UIButton*))) {
				[_buttons addObject: button];
				[self.contentView addSubview: button];
			}
			va_end(argumentList);
			
			self.backgroundView = [[[UIView alloc] initWithFrame:CGRectZero] autorelease];
			self.selectionStyle = UITableViewCellSelectionStyleNone;
		} else {
			return nil;
		}	
	}
	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	int rows = ceil(([_buttons count] / 2.0));
	float buttonWidth = floor(self.contentView.bounds.size.width / 2) - 7;
	float buttonHeight = floor( self.contentView.bounds.size.height / rows ) - (10 * (rows - 1));
	float top = 0;
	float left = 0;
	for( int index = 0; index < [_buttons count]; ++index ) {
		left = (index % 2) * (10 + buttonWidth);
		((UIButton*)[_buttons objectAtIndex:index]).frame = CGRectMake(left, top, buttonWidth, buttonHeight);
		top += (index % 2) * (10 + buttonHeight);
	}
}

- (void)dealloc {
	[super dealloc];
	[_buttons release];
}
@end
