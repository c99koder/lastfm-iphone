/* CalendarViewController.h - Displays and manages an on-screen calendar
 * 
 * Copyright 2009 Last.fm Ltd.
 *   - Primarily authored by Sam Steele <sam@last.fm>
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

#import "CalendarViewController.h"
#import "MobileLastFMApplicationDelegate.h"
#import "NSString+MD5.h"
#import "NSString+URLEscaped.h"
#import "version.h"
#import <QuartzCore/QuartzCore.h>

UIImage *calendarDay;
UIImage *calendarDaySelected;

@implementation CalendarViewController
@synthesize delegate;
- (int)daysInMonth:(NSDate *)month {
	NSDateComponents *components = [[NSCalendar currentCalendar] components:NSMonthCalendarUnit|NSYearCalendarUnit fromDate:month];
	[components setDay:1];
	NSDate *monthStart = [[NSCalendar currentCalendar] dateFromComponents:components];
	
	components = [[NSCalendar currentCalendar] components:NSWeekdayCalendarUnit fromDate:monthStart];
	
	components = [[NSDateComponents alloc] init];
	[components setMonth:1];
	NSDate *nextMonth = [[NSCalendar currentCalendar] dateByAddingComponents:components toDate:monthStart options:0];
	[components release];
	return [nextMonth timeIntervalSinceDate:monthStart] / DAYS;
}
- (void)_buildCalendar {
	NSInteger x=0, y=0, day=0;
	NSDateComponents *components = [[NSCalendar currentCalendar] components:NSMonthCalendarUnit|NSYearCalendarUnit fromDate:date];
	[components setDay:1];
	NSDate *monthStart = [[NSCalendar currentCalendar] dateFromComponents:components];
	
	components = [[NSCalendar currentCalendar] components:NSWeekdayCalendarUnit fromDate:monthStart];
	x = [components weekday]-1;
	
	int daysInMonth = [self daysInMonth: date];
	components = [[NSDateComponents alloc] init];
	[components setMonth:-1];
	NSDate *lastMonth = [[NSCalendar currentCalendar] dateByAddingComponents:components toDate:date options:0];
	[components release];
	int daysInLastMonth = [self daysInMonth: lastMonth];
	
	if(x) {
		components = [[[NSDateComponents alloc] init] autorelease];
		[components setMonth:-1];
		components = [[NSCalendar currentCalendar] components:NSMonthCalendarUnit|NSYearCalendarUnit fromDate:[[NSCalendar currentCalendar] dateByAddingComponents:components  toDate:date options:0]];

		for(day=0; day<x; day++) {
			UIButton *b = tiles[day][y];
			[b setTitleColor: [UIColor colorWithPatternImage:[UIImage imageNamed:@"daygradient-disabled.png"]] forState:UIControlStateNormal];
			[b setTitleShadowColor: [UIColor whiteColor] forState:UIControlStateNormal];
			[b setBackgroundImage:calendarDay forState:UIControlStateNormal];
			[b setTitle:[NSString stringWithFormat:@"%i", day+daysInLastMonth-x+1] forState:UIControlStateNormal];
			[b removeTarget:self action:NULL forControlEvents:UIControlEventTouchUpInside];
			[b addTarget:self action:@selector(_selectDayInPreviousMonth:) forControlEvents:UIControlEventTouchUpInside];
			[components setDay:day+daysInLastMonth-x+1];
			if(eventDates) {
				NSDate *currentDate = [[NSCalendar currentCalendar] dateFromComponents:components];
				for(NSDate *d in eventDates) {
					if([d isEqualToDate:currentDate]) {
						[b setBackgroundImage:calendarDaySelected forState:UIControlStateNormal];
						[b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
						[b setTitleShadowColor: [UIColor colorWithWhite:0 alpha:0.4] forState:UIControlStateNormal];
						break;
					}
				}
			}
		}
	}
	
	components = [[NSCalendar currentCalendar] components:NSMonthCalendarUnit|NSYearCalendarUnit fromDate:date];

	for(day=0; day<daysInMonth; day++) {
		UIButton *b = tiles[x][y];
		[components setDay:day+1];
		BOOL found=NO;
		if(eventDates) {
			NSDate *currentDate = [[NSCalendar currentCalendar] dateFromComponents:components];
			for(NSDate *d in eventDates) {
				if([d isEqualToDate:currentDate]) {
					found=YES;
					break;
				}
			}
		}
		if(found) {
			[b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
			[b setTitleShadowColor: [UIColor colorWithWhite:0 alpha:0.4] forState:UIControlStateNormal];
			[b setBackgroundImage:calendarDaySelected forState:UIControlStateNormal];
		} else {
			[b setTitleColor: [UIColor colorWithPatternImage:[UIImage imageNamed:@"daygradient.png"]] forState:UIControlStateNormal];
			[b setTitleShadowColor: [UIColor whiteColor] forState:UIControlStateNormal];
			[b setBackgroundImage:calendarDay forState:UIControlStateNormal];
		}
		[b setTitle:[NSString stringWithFormat:@"%i", day+1] forState:UIControlStateNormal];
		[b removeTarget:self action:NULL forControlEvents:UIControlEventTouchUpInside];
		[b addTarget:self action:@selector(_selectDayInCurrentMonth:) forControlEvents:UIControlEventTouchUpInside];
		x++;
		if(x>6) {
			x=0;
			y++;
		}
	}
	
	_lastRowInMonth = y;
	
	if(x<7 || y<7) {
		components = [[[NSDateComponents alloc] init] autorelease];
		[components setMonth:1];
		components = [[NSCalendar currentCalendar] components:NSMonthCalendarUnit|NSYearCalendarUnit fromDate:[[NSCalendar currentCalendar] dateByAddingComponents:components  toDate:date options:0]];

		day = 0;
		
		for(; y<7; y++) {
			for(; x<7; x++) {
				UIButton *b = tiles[x][y];
				[b setTitleColor: [UIColor colorWithPatternImage:[UIImage imageNamed:@"daygradient-disabled.png"]] forState:UIControlStateNormal];
				[b setTitleShadowColor: [UIColor whiteColor] forState:UIControlStateNormal];
				[b setBackgroundImage:calendarDay forState:UIControlStateNormal];
				[b setTitle:[NSString stringWithFormat:@"%i", day+1] forState:UIControlStateNormal];
				[b removeTarget:self action:NULL forControlEvents:UIControlEventTouchUpInside];
				[b addTarget:self action:@selector(_selectDayInNextMonth:) forControlEvents:UIControlEventTouchUpInside];
				[components setDay:day+1];
				if(eventDates) {
					NSDate *currentDate = [[NSCalendar currentCalendar] dateFromComponents:components];
					for(NSDate *d in eventDates) {
						if([d isEqualToDate:currentDate]) {
							[b setBackgroundImage:calendarDaySelected forState:UIControlStateNormal];
							[b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
							[b setTitleShadowColor: [UIColor colorWithWhite:0 alpha:0.4] forState:UIControlStateNormal];
							break;
						}
					}
				}
				day++;
			}
			x=0;
		}
	}
	
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateFormat:@"MMMM yyyy"];
	_month.text = [formatter stringFromDate:date];
	[formatter release];
}
- (void)viewDidLoad {
	int x,y;
	_month.textColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"daygradient.png"]];
	_sun.textColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"daygradient.png"]];
	_mon.textColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"daygradient.png"]];
	_tue.textColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"daygradient.png"]];
	_wed.textColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"daygradient.png"]];
	_thur.textColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"daygradient.png"]];
	_fri.textColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"daygradient.png"]];
	_sat.textColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"daygradient.png"]];

	if(!calendarDay)
		calendarDay = [[UIImage imageNamed:@"calendarday.png"] retain];
	if(!calendarDaySelected)
		calendarDaySelected = [[UIImage imageNamed:@"calendarday-selected.png"] retain];
	date = [[NSDate date] retain];
	NSDateComponents *components = [[NSCalendar currentCalendar] components:NSMonthCalendarUnit|NSDayCalendarUnit|NSYearCalendarUnit fromDate:date];
	selectedDate = [[[NSCalendar currentCalendar] dateFromComponents:components] retain];
	
	for(y=0; y<7; y++) {
		for(x=0; x<7; x++) {
			tiles[x][y] = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
			tiles[x][y].frame = CGRectMake(x*46, y*46, 46, 46);
			tiles[x][y].opaque = NO;
			[tiles[x][y] setTitleShadowColor:[UIColor whiteColor] forState:UIControlStateNormal];
			tiles[x][y].titleShadowOffset = CGSizeMake(0,1);
			tiles[x][y].font = [UIFont boldSystemFontOfSize:22];
			[_days addSubview: tiles[x][y]];
		}
	}
	[self _buildCalendar];
}
- (void)_selectDayInCurrentMonth:(id)sender {
	NSDateComponents *components = [[NSCalendar currentCalendar] components:NSMonthCalendarUnit|NSYearCalendarUnit fromDate:date];
	[components setDay:[[sender titleForState:UIControlStateNormal] intValue]];
	[selectedDate release];
	selectedDate = [[[NSCalendar currentCalendar] dateFromComponents:components] retain];
	if(delegate)
		[delegate calendarViewController:self didSelectDate:selectedDate];
}
- (void)_selectDayInPreviousMonth:(id)sender {
	[sender retain];
	[self prevMonthButtonPressed:sender];
	[self _selectDayInCurrentMonth:sender];
	[sender release];
}
- (void)_selectDayInNextMonth:(id)sender {
	[sender retain];
	[self nextMonthButtonPressed:sender];
	[self _selectDayInCurrentMonth:sender];
	[sender release];
}
- (void)_transitionEnded {
	[_transitionImage removeFromSuperview];
	[_transitionImage release];
	_transitionImage = nil;
}
- (void)prevMonthButtonPressed:(id)sender {
	NSDateComponents *components = [[NSDateComponents alloc] init];
	[components setMonth:-1];
	NSDate *newDate = [[NSCalendar currentCalendar] dateByAddingComponents:components toDate:date options:0];
	[date release];
	date = [newDate retain];
	[components release];
	if(!_transitionImage) {
		_transitionImage = [[UIImageView alloc] initWithFrame:_days.frame];
		[_days addSubview:_transitionImage];
		[_days sendSubviewToBack:_transitionImage];
	}
	UIGraphicsBeginImageContext(_transitionImage.bounds.size);
	[_days.layer renderInContext:UIGraphicsGetCurrentContext()];
	_transitionImage.image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	[self _buildCalendar];
	CGRect frame = _days.frame;
	_transitionImage.frame = CGRectMake(0,322 - ((7-_lastRowInMonth) * 46),322,322);
	_days.frame = CGRectMake(-1,49-322+((7-_lastRowInMonth) * 46),322,322);
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration: 0.25];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationDidStopSelector:@selector(_transitionEnded)];
	_days.frame = frame;
	[UIView commitAnimations];
}
- (void)nextMonthButtonPressed:(id)sender {
	NSDateComponents *components = [[NSDateComponents alloc] init];
	[components setMonth:1];
	NSDate *newDate = [[NSCalendar currentCalendar] dateByAddingComponents:components toDate:date options:0];
	[date release];
	date = [newDate retain];
	[components release];
	if(!_transitionImage) {
		_transitionImage = [[UIImageView alloc] initWithFrame:_days.frame];
	}
	UIGraphicsBeginImageContext(_transitionImage.bounds.size);
	[_days.layer renderInContext:UIGraphicsGetCurrentContext()];
	_transitionImage.image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	[_days addSubview:_transitionImage];
	[_days sendSubviewToBack:_transitionImage];
	CGRect frame = _days.frame;
	_transitionImage.frame = CGRectMake(0,-322 + ((7-_lastRowInMonth) * 46),322,322);
	_days.frame = CGRectMake(-1,49+322-((7-_lastRowInMonth) * 46),322,322);
	[self _buildCalendar];
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration: 0.25];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationDidStopSelector:@selector(_transitionEnded)];
	_days.frame = frame;
	[UIView commitAnimations];
}
- (NSArray *)eventDates {
	return eventDates;
}
- (void)setEventDates:(NSArray *)e {
	[eventDates release];
	eventDates = [e retain];
	[date release];
	[selectedDate release];
	
	if([e count])
		date = [[e objectAtIndex:0] retain];
	else
		date = [[NSDate date] retain];
	NSDateComponents *components = [[NSCalendar currentCalendar] components:NSMonthCalendarUnit|NSDayCalendarUnit|NSYearCalendarUnit fromDate:date];
	selectedDate = [[[NSCalendar currentCalendar] dateFromComponents:components] retain];
	[self _buildCalendar];
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
- (void)dealloc {
	[super dealloc];
	[eventDates release];
	[date release];
}
@end
