#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface EventsViewController : UIViewController {
	IBOutlet UILabel *_month;
	IBOutlet UIView *_days;
	NSArray *events;
	NSDate *date;
}
@property (nonatomic, retain) NSArray *events;
- (void)prevMonthButtonPressed:(id)sender;
- (void)nextMonthButtonPressed:(id)sender;
@end
