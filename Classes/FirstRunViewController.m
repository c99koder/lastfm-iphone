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
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 3;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (section == 0)?2:1;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	[tableView deselectRowAtIndexPath:newIndexPath animated:YES];
	switch([newIndexPath section]) {
		case 0:
			switch([newIndexPath row]) {
				case 0:
					[_username becomeFirstResponder];
					break;
				case 1:
					[_password becomeFirstResponder];
					break;
			}
			break;
		case 1:
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
			break;
		case 2:
			[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.last.fm/join/iphone"]];
			break;
	}
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"basiccell"];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] init] autorelease];
	}
	switch([indexPath section]) {
		case 0:
			switch([indexPath row]) {
				case 0:
					cell.text = NSLocalizedString(@"Username", @"Username");
					if(!_username) {
						_username = [[UITextField alloc] initWithFrame:CGRectMake(0,0,190,22)];
						_username.autocorrectionType = UITextAutocorrectionTypeNo;
					}
					cell.accessoryView = _username;
					_username.text = [[NSUserDefaults standardUserDefaults] objectForKey: @"lastfm_user"];
					cell.selectionStyle = UITableViewCellSelectionStyleNone;
					break;
				case 1:
					cell.text = NSLocalizedString(@"Password", @"Password");
					if(!_password) {
						_password = [[UITextField alloc] initWithFrame:CGRectMake(0,0,190,22)];
						_password.secureTextEntry = YES;
					}
					cell.accessoryView = _password;
					cell.selectionStyle = UITableViewCellSelectionStyleNone;
					break;
			}
			break;
		case 1:
			cell.text = NSLocalizedString(@"Login", @"Login Button");
			cell.textAlignment = UITextAlignmentCenter;
			break;
		case 2:
			cell.text = NSLocalizedString(@"Sign Up", @"Sign Up Button");
			cell.textAlignment = UITextAlignmentCenter;
			break;
	}
	return cell;
}
@end
