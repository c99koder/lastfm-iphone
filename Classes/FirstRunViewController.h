#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface FirstRunViewController : UIViewController<UITextFieldDelegate> {
	IBOutlet UITextField *_username;
	IBOutlet UITextField *_password;
}
-(IBAction)loginButtonPressed:(id)sender;
-(IBAction)registerButtonPressed:(id)sender;
-(BOOL)textFieldShouldReturn:(UITextField *)textField;
-(void)dismissKeyboard;
@end

@interface FirstRunViewBackground : UIImageView {
	IBOutlet FirstRunViewController *delegate;
}
@end
