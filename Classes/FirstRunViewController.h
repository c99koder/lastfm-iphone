/* FirstRunViewController.h - Last.fm login screen
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

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface FirstRunViewController : UIViewController<UITextFieldDelegate> {
	IBOutlet UITextField *_username;
	IBOutlet UITextField *_password;
	IBOutlet UITextField *_regusername;
	IBOutlet UITextField *_regpassword;
	IBOutlet UITextField *_regemail;
	IBOutlet UIView *_registrationView;
}
-(IBAction)loginButtonPressed:(id)sender;
-(IBAction)registerButtonPressed:(id)sender;
-(IBAction)createButtonPressed:(id)sender;
-(IBAction)cancelButtonPressed:(id)sender;
-(BOOL)textFieldShouldReturn:(UITextField *)textField;
-(void)dismissKeyboard;
@end

@interface FirstRunViewBackground : UIImageView {
	IBOutlet FirstRunViewController *delegate;
}
@end
