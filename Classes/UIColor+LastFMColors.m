/* UIColor+LastFMColors.m - Colors!
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


#import "UIColor+LastFMColors.h"


@implementation UIColor (LastFMColors)
+ (UIColor*)lfmTableBackgroundColor {
	return [UIColor colorWithRed:196.0f/255.0f green:204.0f/255.0f blue:212.0f/255.0f alpha:1.0f];
}
+ (UIColor*)dateColor {
	return [UIColor colorWithRed:36.0f/255.0f green:112.0f/255.0f blue:216.0f/255.0f alpha:1.0];
}
@end
