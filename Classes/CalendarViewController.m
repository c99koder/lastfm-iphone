#import "CalendarViewController.h"
#import "MobileLastFMApplicationDelegate.h"
#import "NSString+MD5.h"
#import "NSString+URLEscaped.h"
#import "version.h"

UIImage *calendarDay;
UIImage *calendarDaySelected;
UIImage *eventMarker;
UIImage *eventMarkerSelected;
UIImage *eventMarkerDisabled;

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

	[[_days subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
	
	if(x) {
		components = [[[NSDateComponents alloc] init] autorelease];
		[components setMonth:-1];
		components = [[NSCalendar currentCalendar] components:NSMonthCalendarUnit|NSYearCalendarUnit fromDate:[[NSCalendar currentCalendar] dateByAddingComponents:components  toDate:date options:0]];

		for(day=0; day<x; day++) {
			UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
			b.frame = CGRectMake(day*dayWidth,y*dayHeight,dayWidth,dayHeight);
			[b setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
			[b setBackgroundImage:calendarDay forState:UIControlStateNormal];
			[b setTitle:[NSString stringWithFormat:@"%i", day+daysInLastMonth-x+1] forState:UIControlStateNormal];
			[b addTarget:self action:@selector(_selectDayInPreviousMonth:) forControlEvents:UIControlEventTouchUpInside];
			[components setDay:day+daysInLastMonth-x+1];
			if(eventDates) {
				for(NSDate *d in eventDates) {
					if([d isEqualToDate:[[NSCalendar currentCalendar] dateFromComponents:components]]) {
						UIImageView *v = [[UIImageView alloc] initWithImage:eventMarkerDisabled];
						v.frame = CGRectMake(dayWidth / 2 - 2, dayHeight - 7, 4, 5);
						v.userInteractionEnabled = NO;
						[b addSubview: v];
						[v release];
						break;
					}
				}
			}
			[_days addSubview: b];
		}
	}
	
	components = [[NSCalendar currentCalendar] components:NSMonthCalendarUnit|NSYearCalendarUnit fromDate:date];

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
		if([selectedDate isEqualToDate:[[NSCalendar currentCalendar] dateFromComponents:components]]) {
			[b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
			[b setBackgroundImage:calendarDaySelected forState:UIControlStateNormal];
			if(found) {
				UIImageView *v = [[UIImageView alloc] initWithImage:eventMarkerSelected];
				v.frame = CGRectMake(dayWidth / 2 - 2, dayHeight - 7, 4, 5);
				v.userInteractionEnabled = NO;
				[b addSubview: v];
				[v release];
			}
		} else {
			[b setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
			[b setBackgroundImage:calendarDay forState:UIControlStateNormal];
			if(found) {
				UIImageView *v = [[UIImageView alloc] initWithImage:eventMarker];
				v.frame = CGRectMake(dayWidth / 2 - 2, dayHeight - 7, 4, 5);
				v.userInteractionEnabled = NO;
				[b addSubview: v];
				[v release];
			}
		}
		[b setTitle:[NSString stringWithFormat:@"%i", day+1] forState:UIControlStateNormal];
		[b addTarget:self action:@selector(_selectDayInCurrentMonth:) forControlEvents:UIControlEventTouchUpInside];
		[_days addSubview: b];
		x++;
		if(x>6) {
			x=0;
			y++;
		}
	}
	
	if(x<7) {
		components = [[[NSDateComponents alloc] init] autorelease];
		[components setMonth:1];
		components = [[NSCalendar currentCalendar] components:NSMonthCalendarUnit|NSYearCalendarUnit fromDate:[[NSCalendar currentCalendar] dateByAddingComponents:components  toDate:date options:0]];

		for(day=0; day<(7-x); day++) {
			UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
			b.frame = CGRectMake((x+day)*dayWidth,y*dayHeight,dayWidth,dayHeight);
			[b setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
			[b setBackgroundImage:calendarDay forState:UIControlStateNormal];
			[b setTitle:[NSString stringWithFormat:@"%i", day+1] forState:UIControlStateNormal];
			[b addTarget:self action:@selector(_selectDayInNextMonth:) forControlEvents:UIControlEventTouchUpInside];
			[components setDay:day+1];
			if(eventDates) {
				for(NSDate *d in eventDates) {
					if([d isEqualToDate:[[NSCalendar currentCalendar] dateFromComponents:components]]) {
						UIImageView *v = [[UIImageView alloc] initWithImage:eventMarkerDisabled];
						v.frame = CGRectMake(dayWidth / 2 - 2, dayHeight - 7, 4, 5);
						v.userInteractionEnabled = NO;
						[b addSubview: v];
						[v release];
						break;
					}
				}
			}
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
	if(!eventMarker)
		eventMarker = [[UIImage imageNamed:@"eventmarker.png"] retain];
	if(!eventMarkerSelected)
		eventMarkerSelected = [[UIImage imageNamed:@"eventmarker-selected.png"] retain];
	if(!eventMarkerDisabled)
		eventMarkerDisabled = [[UIImage imageNamed:@"eventmarker-disabled.png"] retain];
	date = [[NSDate date] retain];
	NSDateComponents *components = [[NSCalendar currentCalendar] components:NSMonthCalendarUnit|NSDayCalendarUnit|NSYearCalendarUnit fromDate:date];
	selectedDate = [[[NSCalendar currentCalendar] dateFromComponents:components] retain];
	[self _buildCalendar];
}
- (void)_selectDayInCurrentMonth:(id)sender {
	NSDateComponents *components = [[NSCalendar currentCalendar] components:NSMonthCalendarUnit|NSYearCalendarUnit fromDate:date];
	[components setDay:[[sender titleForState:UIControlStateNormal] intValue]];
	[selectedDate release];
	selectedDate = [[[NSCalendar currentCalendar] dateFromComponents:components] retain];
	if(delegate)
		[delegate calendarViewController:self didSelectDate:selectedDate];
	[self _buildCalendar];
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
