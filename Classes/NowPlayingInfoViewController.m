//
//  NowPlayingInfoViewController.m
//  MobileLastFM
//
//  Created by Sam Steele on 1/26/11.
//  Copyright 2011 Last.fm. All rights reserved.
//

#import "LastFMService.h"
#import "ArtworkCell.h"
#import "UITableViewCell+ProgressIndicator.h"
#import "NSString+URLEscaped.h"
#import "NowPlayingInfoViewController.h"
#import "MobileLastFMApplicationDelegate.h"
#import "UIApplication+openURLWithWarning.h"

int tagSort(id tag1, id tag2, void *context);

@interface NowPlayingInfoStyleSheet : TTDefaultStyleSheet {
};
@end

@implementation NowPlayingInfoStyleSheet
-(UIColor *)textColor {
	return [UIColor grayColor];
}
-(UIColor *)linkTextColor {
	return [UIColor colorWithRed:(100.0/256.0) green:(172.0/256.0) blue:(245.0/256.0) alpha:1.0];
}
@end

@implementation NowPlayingInfoViewController
- (void)_loadInfo {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSDictionary *trackData = [[LastFMService sharedInstance] metadataForTrack:[_trackInfo objectForKey:@"title"] byArtist:[_trackInfo objectForKey:@"creator"] inLanguage:@"en"];
	NSDictionary *artistData = [[LastFMService sharedInstance] metadataForArtist:[_trackInfo objectForKey:@"creator"] inLanguage:@"en"];
	NSArray *tags = [[LastFMService sharedInstance] topTagsForTrack:[_trackInfo objectForKey:@"title"] byArtist:[_trackInfo objectForKey:@"creator"]];
	NSArray *usertags = [[LastFMService sharedInstance] tagsForTrack:[_trackInfo objectForKey:@"title"] byArtist:[_trackInfo objectForKey:@"creator"]];
	NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
	[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];

	_artistImageURL = [[artistData objectForKey:@"image"] retain];
	
	_trackStatsView.html = [NSString stringWithFormat:@"%@ Scrobbles<br>(%@ Listeners)<br><b>%@ plays in your library</b>",
													[numberFormatter stringFromNumber:[NSNumber numberWithInteger:[[trackData objectForKey:@"playcount"] intValue]]],
													[numberFormatter stringFromNumber:[NSNumber numberWithInteger:[[trackData objectForKey:@"listeners"] intValue]]],
													[numberFormatter stringFromNumber:[NSNumber numberWithInteger:[[trackData objectForKey:@"userplaycount"] intValue]]]];
	
	_artistStatsView.html = [NSString stringWithFormat:@"%@ Scrobbles<br>(%@ Listeners)<br><b>%@ plays in your library</b>",
													[numberFormatter stringFromNumber:[NSNumber numberWithInteger:[[artistData objectForKey:@"playcount"] intValue]]],
													[numberFormatter stringFromNumber:[NSNumber numberWithInteger:[[artistData objectForKey:@"listeners"] intValue]]],
													[numberFormatter stringFromNumber:[NSNumber numberWithInteger:[[artistData objectForKey:@"userplaycount"] intValue]]]];
	
	NSString *taghtml = @"";

	if([tags count]) {
		taghtml = [taghtml stringByAppendingString:@"Popular: "];

		for(int i = 0; i < [tags count] && i < 5; i++) {
			if(i < [tags count]-1 && i < 4)
				taghtml = [taghtml stringByAppendingFormat:@"%@, ", [[[tags objectAtIndex: i] objectForKey:@"name"] lowercaseString]];
			else
				taghtml = [taghtml stringByAppendingFormat:@"%@", [[[tags objectAtIndex: i] objectForKey:@"name"] lowercaseString]];
		}
	}
	
	if([usertags count]) {
		taghtml = [taghtml stringByAppendingString:@"<br><b>Yours: "];

		for(int i = 0; i < [usertags count] && i < 5; i++) {
			if(i < [usertags count]-1 && i < 4)
				taghtml = [taghtml stringByAppendingFormat:@"%@, ", [[[usertags objectAtIndex: i] objectForKey:@"name"] lowercaseString]];
			else
				taghtml = [taghtml stringByAppendingFormat:@"%@", [[[usertags objectAtIndex: i] objectForKey:@"name"] lowercaseString]];
		}

		taghtml = [taghtml stringByAppendingString:@"</b>"];
	}
	
	_trackTagsView.html = taghtml;
	
	NSString *bio = [[artistData objectForKey:@"summary"] stringByReplacingOccurrencesOfString:@"\n" withString:@"<br/>"];
	_artistBioView.html=[NSString stringWithFormat:@"%@ <a href=\"http://www.last.fm/music/%@/+wiki\">Read More »</a>", bio, [[artistData objectForKey:@"name"] URLEscaped]];
	_loaded = YES;
	[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
	[self performSelectorOnMainThread:@selector(loadContentForCells:) withObject:[self.tableView visibleCells] waitUntilDone:YES];
	[numberFormatter release];
	[pool release];
}
- (id)initWithTrackInfo:(NSDictionary *)trackInfo {
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		_trackInfo = [trackInfo retain];
		self.title = @"Now Playing Info";
		_trackStatsView = [[TTStyledTextLabel alloc] initWithFrame:CGRectZero];
		_trackStatsView.backgroundColor = [UIColor blackColor];
		_trackStatsView.font = [UIFont systemFontOfSize:12];
		_artistStatsView = [[TTStyledTextLabel alloc] initWithFrame:CGRectZero];
		_artistStatsView.backgroundColor = [UIColor blackColor];
		_artistStatsView.font = [UIFont systemFontOfSize:12];
		_trackTagsView = [[TTStyledTextLabel alloc] initWithFrame:CGRectZero];
		_trackTagsView.backgroundColor = [UIColor blackColor];
		_trackTagsView.font = [UIFont systemFontOfSize:12];
		_artistBioView = [[TTStyledTextLabel alloc] initWithFrame:CGRectZero];
		_artistBioView.backgroundColor = [UIColor blackColor];
		_artistBioView.font = [UIFont systemFontOfSize:12];
		UIButton *btn = [[UIButton alloc] initWithFrame: CGRectMake(0, 0, 61, 31)];
		[btn setBackgroundImage:[UIImage imageNamed:@"nowplaying_back.png"] forState:UIControlStateNormal];
		btn.adjustsImageWhenHighlighted = YES;
		[btn addTarget:self.navigationController action:@selector(popViewControllerAnimated:) forControlEvents:UIControlEventTouchUpInside];
		UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithCustomView: btn];
		self.navigationItem.leftBarButtonItem = item;
		self.toolbarItems = [NSArray arrayWithObjects:
												 [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease],
												 [[[UIBarButtonItem alloc] initWithTitle:@"Tag" style:UIBarButtonItemStyleBordered target:self action:@selector(tagButtonPressed)] autorelease],
												 [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease],
												 [[[UIBarButtonItem alloc] initWithTitle:@"Share" style:UIBarButtonItemStyleBordered target:self action:@selector(shareButtonPressed)] autorelease],
												 [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease],
												 [[[UIBarButtonItem alloc] initWithTitle:@"Buy" style:UIBarButtonItemStyleBordered target:self action:@selector(buyButtonPressed)] autorelease],
												 [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease],nil];
		[item release];
		[btn release];
		_loaded = NO;
	}
	return self;
}
- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self.navigationController setToolbarHidden:YES];
	self.navigationController.toolbar.barStyle = UIBarStyleDefault;
	[TTStyleSheet setGlobalStyleSheet:[[TTDefaultStyleSheet alloc] init]];
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:NO];
	self.navigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;
	[self.navigationController setToolbarHidden:NO];
	self.navigationController.toolbar.barStyle = UIBarStyleBlackOpaque;
	self.tableView.backgroundColor = [UIColor blackColor];
	[self.tableView reloadData];
	[self loadContentForCells:[self.tableView visibleCells]];
	[NSThread detachNewThreadSelector:@selector(_loadInfo) toTarget:self withObject:nil];
	[TTStyleSheet setGlobalStyleSheet:[[NowPlayingInfoStyleSheet alloc] init]];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	switch([indexPath section]) {
		case 0:
			return 90;
		case 1:
			if(_loaded) {
				_trackStatsView.text.width = 210;
				return _trackStatsView.text.height;
			} else {
				return 64;
			}
		case 2:
			_artistStatsView.text.width = 210;
			return _artistStatsView.text.height;
		case 3:
			_trackTagsView.text.width = 210;
			return _trackTagsView.text.height;
		case 4:
			_artistBioView.text.width = 210;
			return _artistBioView.text.height;
		default:
			return 52;
	}
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	if(!_loaded)
		return 2;
	else
		return 5;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return 1;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"InfoCell"];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"InfoCell"] autorelease];
	}
	[cell showProgress:NO];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	
	if([indexPath section] == 0) {
		ArtworkCell *profilecell = (ArtworkCell *)[tableView dequeueReusableCellWithIdentifier:@"ProfileCell"];
		if(profilecell == nil) {
			profilecell = [[[ArtworkCell alloc] initWithStyle:UITableViewCellStyleValue2 reuseIdentifier:@"ProfileCell"] autorelease];
			profilecell.contentView.frame = CGRectMake(0,0,96,96);
			profilecell.backgroundView = [[[UIView alloc] init] autorelease];
			profilecell.selectionStyle = UITableViewCellSelectionStyleNone;
			profilecell.placeholder = @"noimage_artist.png";
			profilecell.shouldCacheArtwork = YES;
			profilecell.title.text = [_trackInfo objectForKey:@"creator"];
			profilecell.title.font = [UIFont boldSystemFontOfSize:16];
			profilecell.title.textColor = [UIColor whiteColor];
			profilecell.title.backgroundColor = [UIColor blackColor];
			profilecell.subtitle.text = [_trackInfo objectForKey:@"title"];
			profilecell.subtitle.font = [UIFont boldSystemFontOfSize:16];
			profilecell.subtitle.textColor = [UIColor whiteColor];
			profilecell.subtitle.backgroundColor = [UIColor blackColor];
			profilecell.detailTextLabel.text = [_trackInfo objectForKey:@"album"];
			profilecell.detailTextLabel.font = [UIFont systemFontOfSize:14];
			profilecell.detailTextLabel.textColor = [UIColor whiteColor];
			profilecell.detailTextLabel.backgroundColor = [UIColor blackColor];
			profilecell.accessoryType = UITableViewCellAccessoryNone;
		}
			
		if(_loaded)
			profilecell.imageURL = _artistImageURL;

		return profilecell;
	}
	
	if(_loaded) {
		cell.backgroundView = [[[UIView alloc] init] autorelease];
		UILabel *titleLabel = [[[UILabel alloc] initWithFrame:CGRectMake(0,0,self.view.frame.size.width - 220 - 20,14)] autorelease];
		titleLabel.font = [UIFont boldSystemFontOfSize: 12];
		titleLabel.textColor = [UIColor whiteColor];
		titleLabel.backgroundColor = [UIColor blackColor];
		titleLabel.textAlignment = UITextAlignmentRight;
		cell.detailTextLabel.backgroundColor = [UIColor blackColor];
		[[cell.contentView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
		[cell.contentView addSubview: titleLabel];
		
		switch([indexPath section]) {
			case 1:
				titleLabel.text = @"Track Stats";
				_trackStatsView.frame = CGRectMake(self.view.frame.size.width - 210 - 20,0,_trackStatsView.text.width,_trackStatsView.text.height);
				[cell.contentView addSubview: _trackStatsView];
				break;
			case 2:
				titleLabel.text = @"Artist Stats";
				_artistStatsView.frame = CGRectMake(self.view.frame.size.width - 210 - 20,0,_artistStatsView.text.width,_artistStatsView.text.height);
				[cell.contentView addSubview: _artistStatsView];
				break;
			case 3:
				titleLabel.text = @"Track Tags";
				_trackTagsView.frame = CGRectMake(self.view.frame.size.width - 210 - 20,0,_trackTagsView.text.width,_trackTagsView.text.height);
				[cell.contentView addSubview: _trackTagsView];
				break;
			case 4:
				titleLabel.text = @"Artist Bio";
				_artistBioView.frame = CGRectMake(self.view.frame.size.width - 210 - 20,0,_artistBioView.text.width,_artistBioView.text.height);
				[cell.contentView addSubview: _artistBioView];
				break;
		}
	} else {
		UITableViewCell *loadingcell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"LoadingCell"] autorelease];
		loadingcell.textLabel.text = @"Loading";
		[loadingcell showProgress:YES];
		return loadingcell;
	}
	
  return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	[tableView deselectRowAtIndexPath:newIndexPath animated:NO];
}
- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
	[self becomeFirstResponder];
	[self dismissModalViewControllerAnimated:YES];
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
}
- (void)shareToAddressBook {
	if(NSClassFromString(@"MFMailComposeViewController") != nil && [MFMailComposeViewController canSendMail]) {
		[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
		MFMailComposeViewController *mail = [[MFMailComposeViewController alloc] init];
		[mail setMailComposeDelegate:self];
		[mail setSubject:[NSString stringWithFormat:@"Last.fm: %@ shared %@",[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"], [_trackInfo objectForKey:@"title"]]];
		[mail setMessageBody:[NSString stringWithFormat:@"Hi there,<br/>\
													<br/>\
													%@ at Last.fm wants to share this with you:<br/>\
													<br/>\
													<a href='http://www.last.fm/music/%@/_/%@'>%@</a><br/>\
													<br/>\
													If you like this, add it to your Library. <br/>\
													This will make it easier to find, and will tell your Last.fm profile a bit more<br/>\
													about your music taste. This improves your recommendations and your Last.fm Radio.<br/>\
													<br/>\
													The more good music you add to your Last.fm Profile, the better it becomes :)<br/>\
													<br/>\
													Best Regards,<br/>\
													The Last.fm Team<br/>\
													--<br/>\
													Visit Last.fm for personal radio, tons of recommended music, and free downloads.<br/>\
													Create your own music profile at <a href='http://www.last.fm'>Last.fm</a><br/>",
													[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"],
													[[_trackInfo objectForKey:@"creator"] URLEscaped],
													[[_trackInfo objectForKey:@"title"] URLEscaped],
													[_trackInfo objectForKey:@"title"]
													] isHTML:YES];
		[self presentModalViewController:mail animated:YES];
		[mail release];
	} else {
		ABPeoplePickerNavigationController *peoplePicker = [[ABPeoplePickerNavigationController alloc] init];
		peoplePicker.displayedProperties = [NSArray arrayWithObjects:[NSNumber numberWithInteger:kABPersonEmailProperty], nil];
		peoplePicker.peoplePickerDelegate = self;
		[self.navigationController presentModalViewController:peoplePicker animated:YES];
		[peoplePicker release];
		[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
	}
}
- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person {
	return YES;
}
- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifier {
	ABMultiValueRef value = ABRecordCopyValue(person, property);
	NSString *email = (NSString *)ABMultiValueCopyValueAtIndex(value, ABMultiValueGetIndexForIdentifier(value, identifier));
	[self.navigationController dismissModalViewControllerAnimated:YES];
	
	[[LastFMService sharedInstance] recommendTrack:[_trackInfo objectForKey:@"title"]
																				byArtist:[_trackInfo objectForKey:@"creator"]
																	toEmailAddress:email];
	[email release];
	CFRelease(value);
	
	if([LastFMService sharedInstance].error)
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) reportError:[LastFMService sharedInstance].error];
	else
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) displayError:NSLocalizedString(@"SHARE_SUCCESSFUL", @"Share successful") withTitle:NSLocalizedString(@"SHARE_SUCCESSFUL_TITLE", @"Share successful title")];
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
	return NO;
}
- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker {
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
	[self.navigationController dismissModalViewControllerAnimated:YES];
}
- (void)shareToFriend {
	FriendsViewController *friends = [[FriendsViewController alloc] initWithUsername:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]];
	if(friends) {
		friends.delegate = self;
		friends.title = NSLocalizedString(@"Choose A Friend", @"Friend selector title");
		UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:friends];
		[friends release];
		[self.navigationController presentModalViewController:nav animated:YES];
		[nav release];
		[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
	}
}
- (void)friendsViewController:(FriendsViewController *)friends didSelectFriend:(NSString *)username {
	[[LastFMService sharedInstance] recommendTrack:[_trackInfo objectForKey:@"title"]
																				byArtist:[_trackInfo objectForKey:@"creator"]
																	toEmailAddress:username];
	if([LastFMService sharedInstance].error)
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) reportError:[LastFMService sharedInstance].error];
	else
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) displayError:NSLocalizedString(@"SHARE_SUCCESSFUL", @"Share successful") withTitle:NSLocalizedString(@"SHARE_SUCCESSFUL_TITLE", @"Share successful title")];
	
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
	[self.navigationController dismissModalViewControllerAnimated:YES];
}
- (void)friendsViewControllerDidCancel:(FriendsViewController *)friends {
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
	[self.navigationController dismissModalViewControllerAnimated:YES];
}
-(void)tagEditorDidCancel {
	[self.navigationController dismissModalViewControllerAnimated:YES];
}
- (void)tagEditorAddTags:(NSArray *)tags {
	NSDictionary *trackInfo = [[LastFMRadio sharedInstance] trackInfo];
	[[LastFMService sharedInstance] addTags:tags toTrack:[trackInfo objectForKey:@"title"] byArtist:[trackInfo objectForKey:@"creator"]];
	if([LastFMService sharedInstance].error)
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) reportError:[LastFMService sharedInstance].error];
	[self dismissModalViewControllerAnimated:YES];
}
- (void)tagEditorRemoveTags:(NSArray *)tags {
	NSDictionary *trackInfo = [[LastFMRadio sharedInstance] trackInfo];
	for(NSString *tag in tags) {
		[[LastFMService sharedInstance] removeTag:tag fromTrack:[trackInfo objectForKey:@"title"] byArtist:[trackInfo objectForKey:@"creator"]];
		if([LastFMService sharedInstance].error)
			[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) reportError:[LastFMService sharedInstance].error];
	}
}
- (void)tagButtonPressed {
	NSArray *topTags = [[[LastFMService sharedInstance] topTagsForTrack:[_trackInfo objectForKey:@"title"] byArtist:[_trackInfo objectForKey:@"creator"]] sortedArrayUsingFunction:tagSort context:nil];
	NSArray *userTags = [[[LastFMService sharedInstance] tagsForUser:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]] sortedArrayUsingFunction:tagSort context:nil];
	TagEditorViewController *t = [[TagEditorViewController alloc] initWithTopTags:topTags userTags:userTags];
	t.delegate = self;
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:NO];
	[self presentModalViewController:t animated:YES];
	[t setTags: [[LastFMService sharedInstance] tagsForTrack:[_trackInfo objectForKey:@"title"] byArtist:[_trackInfo objectForKey:@"creator"]]];
	[t release];
}
- (void)buyButtonPressed {
	NSString *ITMSURL = [NSString stringWithFormat:@"http://phobos.apple.com/WebObjects/MZSearch.woa/wa/search?term=%@ %@&s=143444&partnerId=2003&affToken=www.last.fm", 
											 [_trackInfo objectForKey:@"creator"],
											 [_trackInfo objectForKey:@"title"]];
	NSString *URL;
	if([[[NSUserDefaults standardUserDefaults] objectForKey:@"country"] isEqualToString:@"United States"])
		URL = [NSString stringWithFormat:@"http://click.linksynergy.com/fs-bin/stat?id=bKEBG4*hrDs&offerid=78941&type=3&subid=0&tmpid=1826&RD_PARM1=%@", [[ITMSURL URLEscaped] stringByReplacingOccurrencesOfString:@"=" withString:@"%3D"]];
	else
		URL = [NSString stringWithFormat:@"http://clk.tradedoubler.com/click?p=23761&a=1474288&url=%@&tduid=lastfm&partnerId=2003", [[ITMSURL URLEscaped] stringByReplacingOccurrencesOfString:@"=" withString:@"%3D"]];
	
	[[UIApplication sharedApplication] openURLWithWarning:[NSURL URLWithString:URL]];
}
- (void)shareButtonPressed {
	UIActionSheet *sheet;
	if(NSClassFromString(@"MFMailComposeViewController") != nil && [NSClassFromString(@"MFMailComposeViewController") canSendMail]) {
		sheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Who would you like to share this track with?", @"Share sheet title")
																				delegate:self
															 cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
													destructiveButtonTitle:nil
															 otherButtonTitles:@"E-mail Address", NSLocalizedString(@"Last.fm Friends", @"Share to Last.fm friend"), nil];
	} else {
		sheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Who would you like to share this track with?", @"Share sheet title")
																				delegate:self
															 cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
													destructiveButtonTitle:nil
															 otherButtonTitles:NSLocalizedString(@"Contacts", @"Share to Address Book"), NSLocalizedString(@"Last.fm Friends", @"Share to Last.fm friend"), nil];
	}
	[sheet showFromTabBar:self.tabBarController.tabBar];
	[sheet release];	
}
-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	if([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Contacts", @"Share to Address Book")] ||
		 [[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:@"E-mail Address"]) {
		[self shareToAddressBook];
	}
	
	if([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Last.fm Friends", @"Share to Last.fm friend")]) {
		[self shareToFriend];
	}
}
- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
	[super didReceiveMemoryWarning];
	
	// Relinquish ownership any cached data, images, etc. that aren't in use.
}
- (void)viewDidUnload {
	// Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
	// For example: self.myOutlet = nil;
}
- (void)dealloc {
	[_trackInfo release];
	[_artistImageURL release];
	[_trackStatsView release];
	[_artistStatsView release];
	[_trackTagsView release];
	[_artistBioView release];
  [super dealloc];
}
@end

