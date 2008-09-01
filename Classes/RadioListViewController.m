/* RadioListViewController.m - Display a Last.fm radio list
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

#import "RadioListViewController.h"
#import "SearchViewController.h"
#import "TagRadioViewController.h"
#import "UIViewController+NowPlayingButton.h"
#import "UITableViewCell+ProgressIndicator.h"
#import "MobileLastFMApplicationDelegate.h"
#include "version.h"
#import "NSString+URLEscaped.h"
#import "ArtworkCell.h"
#import </usr/include/objc/objc-class.h>

@implementation UIColor (TableHax)
+ (UIColor *)pinStripeColorHax {
	return [UIColor blackColor];
}
@end

@implementation RadioListViewController
BOOL _PerformSwizzle(Class klass, SEL origSel, SEL altSel, BOOL forInstance) {
	
	// Make sure the class isn't nil
	if (klass == nil)
		return NO;
	
	// Look for the methods in the implementation of the immediate class
	Class iterKlass = (forInstance ? klass : klass->isa);
	Method origMethod = NULL, altMethod = NULL;
	NSUInteger methodCount = 0;
	Method *mlist = class_copyMethodList(iterKlass, &methodCount);
	if ( mlist != NULL ) {
		int i;
		for (i = 0; i < methodCount; ++i) {
			if ( method_getName(mlist[i]) == origSel )
				origMethod = mlist[i];
			if (method_getName(mlist[i]) == altSel)
				altMethod = mlist[i];
		}
	}
	
	// if origMethod was not found, that means it is not in the immediate class
	// try searching the entire class hierarchy with class_getInstanceMethod
	// if not found or not added, bail out
	if ( origMethod == NULL ) {
		origMethod = class_getInstanceMethod(iterKlass, origSel);
		if ( origMethod == NULL )
			return NO;
		if ( class_addMethod(iterKlass, method_getName(origMethod), method_getImplementation(origMethod), method_getTypeEncoding(origMethod)) == NO )
			return NO;
	}
	
	// same thing with altMethod
	if ( altMethod == NULL ) {
		altMethod = class_getInstanceMethod(iterKlass, altSel);
		if ( altMethod == NULL ) 
			return NO;
		if ( class_addMethod(iterKlass, method_getName(altMethod), method_getImplementation(altMethod), method_getTypeEncoding(altMethod)) == NO )
			return NO;
	}
	
	//clean up
	free(mlist);
	
	// we now have to look up again for the methods in case they were not in the class implementation,
	//but in one of the superclasses. In the latter, that means we added the method to the class,
	//but the Leopard APIs is only 'class_addMethod', in which case we need to have the pointer
	//to the Method objects actually stored in the Class structure (in the Tiger implementation, 
	//a new mlist was explicitely created with the added methods and directly added to the class; 
	//thus we were able to add a new Method AND get the pointer to it)
	
	// for simplicity, just use the same code as in the first step
	origMethod = NULL;
	altMethod = NULL;
	methodCount = 0;
	mlist = class_copyMethodList(iterKlass, &methodCount);
	if ( mlist != NULL ) {
		int i;
		for (i = 0; i < methodCount; ++i) {
			if ( method_getName(mlist[i]) == origSel )
				origMethod = mlist[i];
			if (method_getName(mlist[i]) == altSel)
				altMethod = mlist[i];
		}
	}
	
	// bail if one of the methods doesn't exist anywhere
	// with all we did, this should not happen, though
	if (origMethod == NULL || altMethod == NULL)
		return NO;
	
	// now swizzle
	method_exchangeImplementations(origMethod, altMethod);
	
	//clean up
	free(mlist);
	
	return YES;
}
- (id)initWithUsername:(NSString *)username {
	_PerformSwizzle([UIColor class], @selector(pinStripeColor),@selector(pinStripeColorHax), NO);
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		self.title = [username retain];
		_username = [username retain];
		self.tableView.sectionHeaderHeight = 0;
		self.tableView.sectionFooterHeight = 0;
	}
	_PerformSwizzle([UIColor class], @selector(pinStripeColor),@selector(pinStripeColorHax), NO);
	return self;
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self showNowPlayingButton:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate isPlaying]];
	[_playlists release];
	_playlists = [[NSMutableArray alloc] init];
	NSArray *playlists = [[LastFMService sharedInstance] playlistsForUser:_username];
	for(NSDictionary *playlist in playlists) {
		if(![[playlist objectForKey:@"streamable"] isEqualToString:@"0"])
			[_playlists addObject:playlist];
	}
	[_recent release];
	_recent = [[[LastFMRadio sharedInstance] recentURLs] retain];
	if(![[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] isEqualToString:_username])
		_commonArtists = [[[[LastFMService sharedInstance] compareArtistsOfUser:_username withUser:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]] objectForKey:@"artists"] retain];
	if(![_commonArtists isKindOfClass:[NSArray class]]) {
		[_commonArtists release];
		_commonArtists = nil;
	}
	[self.tableView reloadData];
	[self loadContentForCells:[self.tableView visibleCells]];
}
- (void)viewDidLoad {
	self.tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 5;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	switch(section) {
		case 0:
			return 1;
		case 1:
			if([[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_subscriber"] intValue])
				return 5;
			else
				return 3;
		case 2:
			return [_commonArtists count]?[_commonArtists count]+1:0;			
		case 3:
			if([[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] isEqualToString:_username])
				return [_recent count]?[_recent count]+1:0;
			else
				return 0;
		case 4:
			if([[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_subscriber"] intValue])
				return [_playlists count]?[_playlists count]+1:0;
			else
				return 0;
	}
	return 0;
}
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	if([self tableView:tableView numberOfRowsInSection:section])
		return 10;
	else
		return 0;
}
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	return [[[UIView alloc] init] autorelease];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if([indexPath section] == 0)
		return [[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] isEqualToString:_username]?46:64;
	else if([indexPath row] > 0)
		return 46;
	else
		return 29;
}
-(void)playRadioStation:(NSString *)url {
	if(![(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate hasNetworkConnection]) {
		[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate displayError:NSLocalizedString(@"ERROR_NONETWORK",@"No network available") withTitle:NSLocalizedString(@"ERROR_NONETWORK_TITLE",@"No network available title")];
	} else {
		[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate playRadioStation:url animated:YES];
	}
}
-(void)_rowSelected:(NSIndexPath *)newIndexPath {
	if([newIndexPath section] > 0 && [newIndexPath row] == 0)
		return;
	
	switch([newIndexPath section]) {
		case 0:
		{
			SearchViewController *controller = [[SearchViewController alloc] initWithNibName:@"SearchView" bundle:nil];
			[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).rootViewController pushViewController:controller animated:YES];
			break;
		}
		case 1:
			switch([newIndexPath row]-1) {
				case 0:
					[self playRadioStation:[NSString stringWithFormat:@"lastfm://user/%@/personal", _username]];
					break;
				case 1:
					[self playRadioStation:[NSString stringWithFormat:@"lastfm://user/%@/recommended", _username]];
					break;
				case 2:
					[self playRadioStation:[NSString stringWithFormat:@"lastfm://user/%@/loved", _username]];
					break;
				case 3:
				{
					TagRadioViewController *tags = [[TagRadioViewController alloc] initWithUsername:_username];
					if(tags) {
						[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).rootViewController pushViewController:tags animated:YES];
						[tags release];
					}
					break;
				}
			}
			break;
		case 3:
			[self playRadioStation:[[_recent objectAtIndex:[newIndexPath row]-1] objectForKey:@"url"]];
			break;
		case 4:
			[self playRadioStation:[NSString stringWithFormat:@"lastfm://playlist/%@/shuffle", [[_playlists objectAtIndex:[newIndexPath row]-1] objectForKey:@"id"]]];
			break;
	}
	[self.tableView reloadData];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	[tableView deselectRowAtIndexPath:newIndexPath animated:NO];
	if([newIndexPath row] > 0) {
		[[tableView cellForRowAtIndexPath: newIndexPath] showProgress:YES];
	}
	[self performSelector:@selector(_rowSelected:) withObject:newIndexPath afterDelay:0.1];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero] autorelease];
	UIImageView *v;
	UILabel *l;
	UIImageView *img;

	[cell showProgress: NO];
	cell.accessoryType = UITableViewCellAccessoryNone;
	
	switch([indexPath section]) {
		case 0:
			if([[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] isEqualToString:_username] && [[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] isEqualToString:_username]) {
				v = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"rounded_table_cell_button.png"]];
				cell.backgroundView = v;
				[v release];
				l = [[UILabel alloc] initWithFrame:CGRectMake(10,0,280,46)];
				l.textAlignment = UITextAlignmentLeft;
				l.font = [UIFont boldSystemFontOfSize:18];
				l.textColor = [UIColor whiteColor];
				l.shadowColor = [UIColor blackColor];
				l.shadowOffset = CGSizeMake(0,-1);
				l.backgroundColor = [UIColor clearColor];
				l.text = NSLocalizedString(@"Start a New Station", @"Start a New Station button");
				l.textAlignment = UITextAlignmentCenter;
				[cell.contentView addSubview:l];
				[l release];
			} else {
				ArtworkCell *profilecell = (ArtworkCell *)[tableView dequeueReusableCellWithIdentifier:@"ProfileCell"];
				if(profilecell == nil) {
					NSDictionary *profile = [[LastFMService sharedInstance] profileForUser:_username];
					profilecell = [[ArtworkCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"ProfileCell"];
					profilecell.imageURL = [profile objectForKey:@"avatar"];
					NSMutableString *html = [[NSMutableString alloc] init];
					[html appendString:@"<html><body style=\"padding: 0px; margin: 0px; width: 100%\">"];
					if([[profile objectForKey:@"realname"] length]) {
						[html appendFormat:@"<b>%@</b><br/>", [profile objectForKey:@"realname"]];
					}
					if([[profile objectForKey:@"age"] length])
						[html appendFormat:@"%@, ", [profile objectForKey:@"age"]];
					[html appendFormat:@"%@<br/>", [profile objectForKey:@"country"]];
					NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
					[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
					[html appendFormat:@"%@ %@ %@<br/>",[numberFormatter stringFromNumber:[NSNumber numberWithInteger:[[profile objectForKey:@"playcount"] intValue]]], NSLocalizedString(@"plays since", @"x plays since join date"), [profile objectForKey:@"registered"]];
					[html appendString:@"</body></html>"];
					UIWebView *webView = [[UIWebView alloc] initWithFrame:CGRectMake(66,0,210,60)];
					[webView loadHTMLString:html baseURL:nil];
					[profilecell.contentView addSubview: webView];
					[webView release];
					[html release];
				}
				return profilecell;
			}
			break;
		case 1:
			switch([indexPath row]) {
				case 0:
					v = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"rounded_table_cell_header.png"]];
					cell.backgroundView = v;
					l = [[UILabel alloc] initWithFrame:v.frame];
					l.textAlignment = UITextAlignmentCenter;
					l.font = [UIFont boldSystemFontOfSize:14];
					l.textColor = [UIColor whiteColor];
					l.shadowColor = [UIColor blackColor];
					l.shadowOffset = CGSizeMake(0,-1);
					l.backgroundColor = [UIColor clearColor];
					if([[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] isEqualToString:_username])
						l.text = NSLocalizedString(@"My Stations", @"My Stations heading");
					else
						l.text = [NSString stringWithFormat:@"%@'s Stations", _username];
					[cell.contentView addSubview:l];
					[l release];
					[v release];
					break;
				case 1:
					cell.text = NSLocalizedString(@"My Library", @"My Library station");
					break;
				case 2:
					cell.text = NSLocalizedString(@"Recommended by Last.fm", @"Recommended by Last.fm station");
					break;
				case 3:
					cell.text = NSLocalizedString(@"Loved Tracks", @"Loved Tracks station");
					break;
				case 4:
					cell.text = NSLocalizedString(@"Tag Radio", @"Tag Radio station");
					cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
					break;
			}
			break;
		case 2:
			if([indexPath row] == 0) {
				v = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"rounded_table_cell_header.png"]];
				cell.backgroundView = v;
				l = [[UILabel alloc] initWithFrame:v.frame];
				l.textAlignment = UITextAlignmentCenter;
				l.font = [UIFont boldSystemFontOfSize:14];
				l.textColor = [UIColor whiteColor];
				l.shadowColor = [UIColor blackColor];
				l.shadowOffset = CGSizeMake(0,-1);
				l.backgroundColor = [UIColor clearColor];
				l.text = NSLocalizedString(@"Common Artists", @"Common Artists heading");
				[cell.contentView addSubview:l];
				[l release];
				[v release];
			} else {
				cell.text = [_commonArtists objectAtIndex:[indexPath row]-1];
			}
			break;			
		case 3:
			if([indexPath row] == 0) {
				v = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"rounded_table_cell_header.png"]];
				cell.backgroundView = v;
				l = [[UILabel alloc] initWithFrame:v.frame];
				l.textAlignment = UITextAlignmentCenter;
				l.font = [UIFont boldSystemFontOfSize:14];
				l.textColor = [UIColor whiteColor];
				l.shadowColor = [UIColor blackColor];
				l.shadowOffset = CGSizeMake(0,-1);
				l.backgroundColor = [UIColor clearColor];
				l.text = NSLocalizedString(@"Recent Stations", @"Recent Stations heading");
				[cell.contentView addSubview:l];
				[l release];
				[v release];
			} else {
				cell.text = [[_recent objectAtIndex:[indexPath row]-1] objectForKey:@"name"];
			}
			break;
		case 4:
			if([indexPath row] == 0) {
				v = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"rounded_table_cell_header.png"]];
				cell.backgroundView = v;
				l = [[UILabel alloc] initWithFrame:v.frame];
				l.textAlignment = UITextAlignmentCenter;
				l.font = [UIFont boldSystemFontOfSize:14];
				l.textColor = [UIColor whiteColor];
				l.shadowColor = [UIColor blackColor];
				l.shadowOffset = CGSizeMake(0,-1);
				l.backgroundColor = [UIColor clearColor];
				l.text = NSLocalizedString(@"My Playlists", @"My Playlists heading");
				[cell.contentView addSubview:l];
				[l release];
				[v release];
			} else {
				cell.text = [[_playlists objectAtIndex:[indexPath row]-1] objectForKey:@"title"];
			}
			break;
	}
	if([indexPath row] > 0 && cell.accessoryType == UITableViewCellAccessoryNone) {
		img = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"streaming.png"]];
		img.opaque = YES;
		cell.accessoryView = img;
		[img release];
	}
	return cell;
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
- (void)dealloc {
	[super dealloc];
	[_loadingThread cancel];
	[_username release];
	[_playlists release];
	[_recent release];
}
@end
