/* EventsViewController.m - Display various kinds of events for a user
 * 
 * Copyright 2010 Last.fm Ltd.
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

#import "EventsTabViewController.h"
#import "UIViewController+NowPlayingButton.h"
#import "UITableViewCell+ProgressIndicator.h"
#import "MobileLastFMApplicationDelegate.h"
#include "version.h"
#import "NSString+URLEscaped.h"
#import "DetailsViewController.h"

@implementation EventsTabViewController
- (id)initWithUsername:(NSString *)username {
	if (self = [super initWithStyle:UITableViewStylePlain]) {
		_username = [username retain];
		self.title = [username retain];
	}
	return self;
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self showNowPlayingButton:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate isPlaying]];
	[self.tableView reloadData];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return 3;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 46;
}
-(void)_rowSelected:(NSIndexPath *)newIndexPath {
	UINavigationController *controller = nil;
	NSArray *data = nil;
	
	switch([newIndexPath row]) {
		case 0:
			data = [[LastFMService sharedInstance] eventsForUser:_username];
			controller = [[EventsViewController alloc] initWithUsername:_username withEvents:data];
			break;
		case 1:
			data = [[LastFMService sharedInstance] recommendedEventsForUser:_username];
			controller = [[EventsViewController alloc] initWithUsername:_username withEvents:data];
			break;
		case 2:
			if (nil == _locationManager)
        _locationManager = [[CLLocationManager alloc] init];
			
			_locationManager.delegate = self;
			_locationManager.desiredAccuracy = kCLLocationAccuracyKilometer;
			
			// Set a movement threshold for new events
			_locationManager.distanceFilter = 500;
			
			[_locationManager startUpdatingLocation];
			return;
			break;
	}
	
	if(controller) {
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).rootViewController pushViewController:controller animated:YES];
		[controller release];
	}
	[[self tableView] reloadData];
}
// Delegate method from the CLLocationManagerDelegate protocol.
- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
					 fromLocation:(CLLocation *)oldLocation
{
	if(_locationManager != nil) {
			NSLog(@"latitude %+.6f, longitude %+.6f\n",
						newLocation.coordinate.latitude,
						newLocation.coordinate.longitude);
		[_locationManager stopUpdatingLocation];
		NSArray *data = [[LastFMService sharedInstance] eventsForLatitude:newLocation.coordinate.latitude longitude:newLocation.coordinate.longitude radius:50];
		UINavigationController *controller = [[EventsViewController alloc] initWithUsername:_username withEvents:data];
		if(controller) {
			[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).rootViewController pushViewController:controller animated:YES];
			[controller release];
		}
		//[_locationManager release];
		_locationManager = nil;
		[[self tableView] reloadData];
	}
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	[[tableView cellForRowAtIndexPath: newIndexPath] showProgress:YES];
	[tableView deselectRowAtIndexPath:newIndexPath animated:YES];
	[self performSelector:@selector(_rowSelected:) withObject:newIndexPath afterDelay:0.5];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"simplecell"];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"simplecell"] autorelease];
	}
	
	switch([indexPath row]) {
		case 0:
			cell.textLabel.text = @"My Events";
			break;
		case 1:
			cell.textLabel.text = @"Recommended by Last.fm";
			break;
		case 2:
			cell.textLabel.text = @"Events Near Me";
			break;
	}
	[cell showProgress: NO];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	return cell;
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
- (void)dealloc {
	[super dealloc];
	[_username release];
}
@end
