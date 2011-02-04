/* NSString+LastFMTimeExtensions.m - convert timestamps to strings
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

#import "NSString+LastFMTimeExtensions.h"

@implementation NSString (LastFMTimeExtensions)
- (NSString *)StringFromTimestamp {

	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease]];
	[formatter setDateFormat:@"dd MMM yyyy, HH:mm zzz"];
	NSDate *date = [formatter dateFromString:[self stringByAppendingString:@" GMT"]];
	[formatter setLocale:[NSLocale currentLocale]];
	NSDateComponents *components = [[NSCalendar currentCalendar] components:NSDayCalendarUnit|NSMonthCalendarUnit|NSYearCalendarUnit fromDate:[NSDate date]];
	[components setHour: 23];
	[components setMinute: 59];
	[components setSecond:59];
	NSDate *today = [[NSCalendar currentCalendar] dateFromComponents:components];
	NSTimeInterval seconds = [today timeIntervalSinceDate:date];
	
	if(seconds/HOURS < 24) {
		[formatter setTimeStyle:NSDateFormatterShortStyle];
		[formatter setDateStyle:NSDateFormatterNoStyle];
	} else if(seconds/DAYS < 2) {
		[formatter setDateFormat:NSLocalizedString(@"'Yesterday'", @"Yesterday date format string")];
	} else if(seconds/DAYS < 7) {
		[formatter setDateFormat:@"EEEE"];
	} else {
		[formatter setDateStyle:NSDateFormatterShortStyle];
	}
	
	NSString *output = [formatter stringFromDate:date];
	[formatter release];
	return output;
	
}

- (NSString *)StringFromUTS {
	
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease]];
	[formatter setDateFormat:@"dd MMM yyyy, HH:mm zzz"];
	NSDate *date = [NSDate dateWithTimeIntervalSince1970: [self doubleValue]];
	[formatter setLocale:[NSLocale currentLocale]];
	NSDateComponents *components = [[NSCalendar currentCalendar] components:NSDayCalendarUnit|NSMonthCalendarUnit|NSYearCalendarUnit fromDate:[NSDate date]];
	[components setHour: 23];
	[components setMinute: 59];
	[components setSecond:59];
	NSDate *today = [[NSCalendar currentCalendar] dateFromComponents:components];
	NSTimeInterval seconds = [today timeIntervalSinceDate:date];
	
	if(seconds/HOURS < 24) {
		[formatter setTimeStyle:NSDateFormatterShortStyle];
		[formatter setDateStyle:NSDateFormatterNoStyle];
	} else if(seconds/DAYS < 2) {
		[formatter setDateFormat:NSLocalizedString(@"'Yesterday'", @"Yesterday date format string")];
	} else if(seconds/DAYS < 7) {
		[formatter setDateFormat:@"EEEE"];
	} else {
		[formatter setDateStyle:NSDateFormatterShortStyle];
	}
	
	NSString *output = [formatter stringFromDate:date];
	[formatter release];
	return output;
	
}

- (NSString *)shortDateStringFromUTS {
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease]];
	[formatter setDateFormat:@"dd MMM yyyy, HH:mm zzz"];
	NSDate *date = [NSDate dateWithTimeIntervalSince1970: [self doubleValue]];
	[formatter setLocale:[NSLocale currentLocale]];
	NSDateComponents *components = [[NSCalendar currentCalendar] components:NSDayCalendarUnit|NSMonthCalendarUnit|NSYearCalendarUnit fromDate:[NSDate date]];
	[components setHour: 23];
	[components setMinute: 59];
	[components setSecond:59];
	NSDate *today = [[NSCalendar currentCalendar] dateFromComponents:components];
	NSTimeInterval seconds = [today timeIntervalSinceDate:date];
	
	if(seconds/HOURS < 24) {
		[formatter setTimeStyle:NSDateFormatterShortStyle];
		[formatter setDateStyle:NSDateFormatterNoStyle];
	} else {
		[formatter setDateStyle:NSDateFormatterShortStyle];
	}
	
	NSString *output = [formatter stringFromDate:date];
	[formatter release];
	return output;
}

@end
