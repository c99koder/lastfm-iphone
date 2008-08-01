#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@class CalendarViewController;

@protocol CalendarViewControllerDelegate
-(void)calendarViewController:(CalendarViewController *)controller didSelectDate:(NSDate *)date;
@end

@interface CalendarViewController : UIViewController {
	IBOutlet UILabel *_month;
	IBOutlet UIView *_days;
	NSArray *eventDates;
	NSDate *date;
	NSDate *selectedDate;
	id<CalendarViewControllerDelegate> delegate;
}
@property (nonatomic, retain) NSArray *eventDates;
@property (nonatomic, retain) id<CalendarViewControllerDelegate> delegate; 
- (void)prevMonthButtonPressed:(id)sender;
- (void)nextMonthButtonPressed:(id)sender;
@end
