/* FirstRunViewController.h - Last.fm login screen
 * 
 * Copyright 2011 Last.fm Ltd.
 *   - Primarily authored by Sam Steele <sam@last.fm>
 *
 * This file is part of MobileLastFM.
 *
 * MobileLastFM is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * MobileLastFM is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with MobileLastFM.  If not, see <http://www.gnu.org/licenses/>.
 */

#import "FirstRunViewController.h"
#import "MobileLastFMApplicationDelegate.h"
#import "NSString+MD5.h"
#import "NSString+URLEscaped.h"
#import "version.h"
#if !(TARGET_IPHONE_SIMULATOR)
#import "FlurryAnalytics.h"
#endif

@interface FirstRunViewStyleSheet : TTDefaultStyleSheet {
};
@end

@implementation FirstRunViewStyleSheet
-(UIColor *)textColor {
	return [UIColor whiteColor];
}
-(UIColor *)linkTextColor {
	return [UIColor whiteColor];
}
@end

@implementation FirstRunViewController
-(void)_authenticateUser {
	NSDictionary *session = [[LastFMService sharedInstance] getMobileSessionForUser:_username.text password:_password.text];
	if([[session objectForKey:@"key"] length]) {
		[[NSUserDefaults standardUserDefaults] setObject:_username.text forKey:@"lastfm_user"];
		[[NSUserDefaults standardUserDefaults] setObject:[session objectForKey:@"key"] forKey:@"lastfm_session"];
		[[NSUserDefaults standardUserDefaults] setObject:[session objectForKey:@"subscriber"] forKey:@"lastfm_subscriber"];
		[[NSUserDefaults standardUserDefaults] setObject:@"YES" forKey:@"removeUserTags"];
		[[NSUserDefaults standardUserDefaults] setObject:@"YES" forKey:@"removePlaylists"];
		[[NSUserDefaults standardUserDefaults] setObject:@"YES" forKey:@"removeLovedTracks"];
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
	[super viewWillAppear:animated];
	_username.text = [[NSUserDefaults standardUserDefaults] objectForKey: @"lastfm_user"];
	[TTStyleSheet setGlobalStyleSheet:[[[FirstRunViewStyleSheet alloc] init] autorelease]];
}
- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[TTStyleSheet setGlobalStyleSheet:[[[TTDefaultStyleSheet alloc] init] autorelease]];
}
-(IBAction)registerButtonPressed:(id)sender {
	_regusername.text = @"";
	_regpassword.text = @"";
	_regemail.text = @"";
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration:0.75];
	[UIView setAnimationTransition:UIViewAnimationTransitionCurlUp forView:self.view cache:YES];
	[self.view addSubview:_registrationView];
	[UIView commitAnimations];
}
-(void)_registerUser {
	[[LastFMService sharedInstance] createUser:_regusername.text withPassword:_regpassword.text andEmail:_regemail.text];
	if([LastFMService sharedInstance].error) {
		if([[LastFMService sharedInstance].error.domain isEqualToString:LastFMServiceErrorDomain] && [LastFMService sharedInstance].error.code == 6) {
			[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) displayError:[[LastFMService sharedInstance].error.userInfo objectForKey:NSLocalizedDescriptionKey] withTitle:NSLocalizedString(@"ERROR_REGFAILURE_TITLE", @"Registration error title")];
		} else {
			[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) reportError:[LastFMService sharedInstance].error];
		}
		_regusername.enabled = YES;
		_regpassword.text = @"";
		_regpassword.enabled = YES;
		_regemail.enabled = YES;
	} else {
		_username.text = _regusername.text;
		_password.text = _regpassword.text;
		[self cancelButtonPressed:nil];
		[self loginButtonPressed:nil];
#if !(TARGET_IPHONE_SIMULATOR)
		[FlurryAnalytics logEvent:@"signup"];
#endif
	}	
}
- (BOOL)validateEmail: (NSString *) candidate {
	NSString *emailRegex = @"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}"; 
	NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex]; 
	
	return [emailTest evaluateWithObject:candidate];
}
-(IBAction)createButtonPressed:(id)sender {
	if([_regusername.text length] && [_regpassword.text length] && [_regemail.text length] && [self validateEmail:_regemail.text]) {
		[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
		_regusername.enabled = NO;
		_regpassword.enabled = NO;
		_regemail.enabled = NO;
		[self performSelector:@selector(_registerUser) withObject:nil afterDelay:0.1];
	} else {
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) displayError:NSLocalizedString(@"ERROR_MISSINGINFO", @"Missing info") withTitle:NSLocalizedString(@"ERROR_MISSINGINFO_TITLE", @"Missing info title")];
	}	
}
-(IBAction)cancelButtonPressed:(id)sender {
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration:0.75];
	[UIView setAnimationTransition:UIViewAnimationTransitionCurlDown forView:self.view cache:YES];
	[_registrationView removeFromSuperview];
	[UIView commitAnimations];
}
-(IBAction)loginButtonPressed:(id)sender {
	if([_username.text length] && [_password.text length]) {
		[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
		_username.enabled = NO;
		_password.enabled = NO;
		[self performSelector:@selector(_authenticateUser) withObject:nil afterDelay:0.1];
	} else {
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) displayError:NSLocalizedString(@"ERROR_MISSINGINFO", @"Missing info") withTitle:NSLocalizedString(@"ERROR_MISSINGINFO_TITLE", @"Missing info title")];
	}
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	if(textField == _username && [_username.text length] > 0)
		[_password becomeFirstResponder];
	if(textField == _password && [_password.text length] > 0)
		[self loginButtonPressed:textField];
	if(textField == _regusername && [_regusername.text length] > 0)
		[_regpassword becomeFirstResponder];
	if(textField == _regpassword && [_regpassword.text length] > 0)
		[_regemail becomeFirstResponder];
	if(textField == _regemail && [_regemail.text length] > 0)
		[self createButtonPressed:textField];
	return NO;
}
-(void)dismissKeyboard {
	[_username resignFirstResponder];
	[_password resignFirstResponder];
}
-(void)viewDidLoad {
	_tandcview = [[TTStyledTextLabel alloc] initWithFrame:CGRectMake(9,198,302,100)];
	_tandcview.backgroundColor = [UIColor clearColor];
	_tandcview.font = [UIFont systemFontOfSize:12];
	_tandcview.html = @"By creating an account, you agree to the <a href='http://m.last.fm/legal/terms'>Terms of Use</a> and <a href='http://m.last.fm/legal/privacy'>Privacy Policy</a>, and confirm that you are 13 years of age or over.";
	[_registrationView addSubview: _tandcview];
}
-(void)viewDidUnload {
	[_tandcview removeFromSuperview];
	[_tandcview release];
	_tandcview = nil;
}
- (void)dealloc {
	[_tandcview release];
	[super dealloc];
}
@end

@implementation FirstRunViewBackground
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	[delegate dismissKeyboard];
}
@end
