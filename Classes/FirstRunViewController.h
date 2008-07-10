#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface FirstRunViewController : UIViewController {
	IBOutlet UINavigationBar *_navBar;
	IBOutlet UITextField *_username;
	IBOutlet UITextField *_password;
}
-(IBAction)registerButtonPressed:(id)sender;
-(IBAction)loginButtonPressed:(id)sender;
@end
