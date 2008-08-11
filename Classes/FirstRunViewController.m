#import "FirstRunViewController.h"
#import "MobileLastFMApplicationDelegate.h"
#import "NSString+MD5.h"
#import "NSString+URLEscaped.h"
#import "version.h"

@implementation FirstRunViewController
-(void)_authenticateUser:(NSTimer *)timer {
	NSDictionary *session = [[LastFMService sharedInstance] getMobileSessionForUser:_username.text password:_password.text];
	if([[session objectForKey:@"key"] length]) {
		[[NSUserDefaults standardUserDefaults] setObject:_username.text forKey:@"lastfm_user"];
		[[NSUserDefaults standardUserDefaults] setObject:[session objectForKey:@"key"] forKey:@"lastfm_session"];
		[[NSUserDefaults standardUserDefaults] setObject:[session objectForKey:@"subscriber"] forKey:@"lastfm_subscriber"];
		[[NSUserDefaults standardUserDefaults] synchronize];
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) showProfileView:YES];
	} else {
		if([[LastFMService sharedInstance].error.domain isEqualToString:LastFMServiceErrorDomain] && [LastFMService sharedInstance].error.code == errorCodeAuthenticationFailed) {
			[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) displayError:NSLocalizedString(@"ERROR_AUTH", @"Auth error") withTitle:NSLocalizedString(@"ERROR_AUTH_TITLE", @"Auth error title")];
		} else {
			[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) reportError:[LastFMService sharedInstance].error];
		}
		_username.enabled = YES;
		_password.text = @"";
		_password.enabled = YES;
	}
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}
-(void)viewWillAppear:(BOOL)animated {
	_username.text = [[NSUserDefaults standardUserDefaults] objectForKey: @"lastfm_user"];
}
-(IBAction)registerButtonPressed:(id)sender {
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.last.fm/join/iphone"]];
}
-(IBAction)loginButtonPressed:(id)sender {
	if([_username.text length] && [_password.text length]) {
		[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
		_username.enabled = NO;
		_password.enabled = NO;
		[NSTimer scheduledTimerWithTimeInterval:0.1
																		 target:self
																	 selector:@selector(_authenticateUser:)
																	 userInfo:nil
																		repeats:NO];
	} else {
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) displayError:NSLocalizedString(@"ERROR_MISSINGINFO", @"Missing info") withTitle:NSLocalizedString(@"ERROR_MISSINGINFO_TITLE", @"Missing info title")];
	}
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	if(textField == _username && [_username.text length] > 0)
		[_password becomeFirstResponder];
	if(textField == _password && [_password.text length] > 0)
		[self loginButtonPressed:textField];
	return NO;
}
-(void)dismissKeyboard {
	[_username resignFirstResponder];
	[_password resignFirstResponder];
}
@end

@implementation FirstRunViewBackground
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	[delegate dismissKeyboard];
}
@end
