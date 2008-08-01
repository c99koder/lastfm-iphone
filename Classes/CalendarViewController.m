#import "CalendarViewController.h"
#import "MobileLastFMApplicationDelegate.h"
#import "NSString+MD5.h"
#import "NSString+URLEscaped.h"
#import "version.h"

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
	
	int dayWidth = _days.frame.size.width / 7;
	int dayHeight = _days.frame.size.height / ((x + daysInMonth)/7 + 1);

	components = [[NSCalendar currentCalendar] components:NSMonthCalendarUnit|NSYearCalendarUnit fromDate:date];
	
	[[_days subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
	
	if(x) {
		for(day=0; day<x; day++) {
			UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
			b.frame = CGRectMake(day*dayWidth,y*dayHeight,dayWidth,dayHeight);
			[b setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
			[b setBackgroundImage:calendarDay forState:UIControlStateNormal];
			[b setTitle:[NSString stringWithFormat:@"%i", day+daysInLastMonth-x+1] forState:UIControlStateNormal];
			[_days addSubview: b];
		}
	}
	
	for(day=0; day<daysInMonth; day++) {
		UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
		b.frame = CGRectMake(x*dayWidth,y*dayHeight,dayWidth,dayHeight);
		[components setDay:day+1];
		BOOL found=NO;
		if(eventDates) {
			for(NSDate *d in eventDates) {
				if([d isEqualToDate:[[NSCalendar currentCalendar] dateFromComponents:components]]) {
					found=YES;
					break;
				}
			}
		}
		if(found) {
		}
		if([selectedDate isEqualToDate:[[NSCalendar currentCalendar] dateFromComponents:components]]) {
			[b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
			[b setBackgroundImage:calendarDaySelected forState:UIControlStateNormal];
		} else {
			[b setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
			[b setBackgroundImage:calendarDay forState:UIControlStateNormal];
		}
		[b setTitle:[NSString stringWithFormat:@"%i", day+1] forState:UIControlStateNormal];
		[_days addSubview: b];
		x++;
		if(x>6) {
			x=0;
			y++;
		}
	}
	
	if(x<7) {
		for(day=0; day<(7-x); day++) {
			UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
			b.frame = CGRectMake((x+day)*dayWidth,y*dayHeight,dayWidth,dayHeight);
			[b setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
			[b setBackgroundImage:calendarDay forState:UIControlStateNormal];
			[b setTitle:[NSString stringWithFormat:@"%i", day+1] forState:UIControlStateNormal];
			[_days addSubview: b];
		}
	}
	
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateFormat:@"MMMM yyyy"];
	_month.text = [formatter stringFromDate:date];
	[formatter release];
}
- (void)viewDidLoad {
	if(!calendarDay)
		calendarDay = [[[UIImage imageNamed:@"calendarday.png"] stretchableImageWithLeftCapWidth:1 topCapHeight:0] retain];
	if(!calendarDaySelected)
		calendarDaySelected = [[[UIImage imageNamed:@"calendarday-selected.png"] stretchableImageWithLeftCapWidth:1 topCapHeight:0] retain];
	date = [[NSDate date] retain];
	NSDateComponents *components = [[NSCalendar currentCalendar] components:NSMonthCalendarUnit|NSDayCalendarUnit|NSYearCalendarUnit fromDate:date];
	selectedDate = [[[NSCalendar currentCalendar] dateFromComponents:components] retain];
	[self _buildCalendar];
}
- (void)prevMonthButtonPressed:(id)sender {
	NSDateComponents *components = [[NSDateComponents alloc] init];
	[components setMonth:-1];
	NSDate *newDate = [[NSCalendar currentCalendar] dateByAddingComponents:components toDate:date options:0];
	[date release];
	date = [newDate retain];
	[components release];
	[self _buildCalendar];
}
- (void)nextMonthButtonPressed:(id)sender {
	NSDateComponents *components = [[NSDateComponents alloc] init];
	[components setMonth:1];
	NSDate *newDate = [[NSCalendar currentCalendar] dateByAddingComponents:components toDate:date options:0];
	[date release];
	date = [newDate retain];
	[components release];
	[self _buildCalendar];
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
