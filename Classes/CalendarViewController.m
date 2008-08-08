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
			[b setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
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
			[b setBackgroundImage:calendarDaySelected forState:UIControlStateNormal];
		} else {
			[b setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
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
	
	if(x<7 || y<7) {
		components = [[[NSDateComponents alloc] init] autorelease];
		[components setMonth:1];
		components = [[NSCalendar currentCalendar] components:NSMonthCalendarUnit|NSYearCalendarUnit fromDate:[[NSCalendar currentCalendar] dateByAddingComponents:components  toDate:date options:0]];

		day = 0;
		
		for(; y<7; y++) {
			for(; x<7; x++) {
				UIButton *b = tiles[x][y];
				[b setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
				[b setBackgroundImage:calendarDay forState:UIControlStateNormal];
				[b setTitle:[NSString stringWithFormat:@"%i", day+1] forState:UIControlStateNormal];
				[b removeTarget:self action:NULL forControlEvents:UIControlEventTouchUpInside];
				[b addTarget:self action:@selector(_selectDayInNextMonth:) forControlEvents:UIControlEventTouchUpInside];
				[components setDay:day+1];
				if(eventDates) {
					NSDate *currentDate = [[NSCalendar currentCalendar] dateFromComponents:components];
					for(NSDate *d in eventDates) {
						if([d isEqualToDate:currentDate]) {
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
			tiles[x][y].opaque = YES;
			[tiles[x][y] setTitleShadowColor:[UIColor whiteColor] forState:UIControlStateNormal];
			tiles[x][y].titleShadowOffset = CGSizeMake(0,-1);
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
- (void)prevMonthButtonPressed:(id)sender {
	NSDateComponents *components = [[NSDateComponents alloc] init];
	[components setMonth:-1];
	NSDate *newDate = [[NSCalendar currentCalendar] dateByAddingComponents:components toDate:date options:0];
	[date release];
	date = [newDate retain];
	[components release];
	if(!_transitionImage) {
		_transitionImage = [[UIImageView alloc] initWithFrame:_days.frame];
		[self.view addSubview:_transitionImage];
	}
	UIGraphicsBeginImageContext(_transitionImage.bounds.size);
	[_days.layer renderInContext:UIGraphicsGetCurrentContext()];
	_transitionImage.image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	CGRect frame = _days.frame;
	_transitionImage.frame = frame;
	frame.origin.x = -322;
	_days.frame = frame;
	[self _buildCalendar];
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration: 0.2];
	frame = _transitionImage.frame;
	_days.frame = frame;
	frame.origin.x = 322;
	_transitionImage.frame = frame;
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
		[self.view addSubview:_transitionImage];
	}
	UIGraphicsBeginImageContext(_transitionImage.bounds.size);
	[_days.layer renderInContext:UIGraphicsGetCurrentContext()];
	_transitionImage.image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	CGRect frame = _days.frame;
	_transitionImage.frame = frame;
	frame.origin.x = 320;
	_days.frame = frame;
	[self _buildCalendar];
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration: 0.2];
	frame = _transitionImage.frame;
	_days.frame = frame;
	frame.origin.x = -322;
	_transitionImage.frame = frame;
	[UIView commitAnimations];
}
- (NSArray *)eventDates {
	return eventDates;
}
- (void)setEventDates:(NSArray *)e {
	[eventDates release];
	eventDates = [e retain];
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
