/* CalendarViewController.h - Displays and manages an on-screen calendar
 * Copyright (C) 2008 Sam Steele
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

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@class CalendarViewController;

@protocol CalendarViewControllerDelegate
-(void)calendarViewController:(CalendarViewController *)controller didSelectDate:(NSDate *)date;
@end

@interface CalendarViewController : UIViewController {
	IBOutlet UILabel *_month;
	IBOutlet UILabel *_sun;
	IBOutlet UILabel *_mon;
	IBOutlet UILabel *_tue;
	IBOutlet UILabel *_wed;
	IBOutlet UILabel *_thur;
	IBOutlet UILabel *_fri;
	IBOutlet UILabel *_sat;
	IBOutlet UIView *_days;
	NSArray *eventDates;
	NSDate *date;
	NSDate *selectedDate;
	id<CalendarViewControllerDelegate> delegate;
	UIButton *tiles[7][7];
	UIImageView *_transitionImage;
	int _lastRowInMonth;
}
@property (nonatomic, retain) NSArray *eventDates;
@property (nonatomic, retain) id<CalendarViewControllerDelegate> delegate; 
- (void)prevMonthButtonPressed:(id)sender;
- (void)nextMonthButtonPressed:(id)sender;
@end
