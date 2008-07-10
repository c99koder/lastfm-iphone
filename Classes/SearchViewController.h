/* SearchViewController.h - Search view controller
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
#import "LastFMService.h"

@interface SearchViewController : UIViewController<UISearchBarDelegate, UITextFieldDelegate> {
	IBOutlet UISegmentedControl *_searchType;
	IBOutlet UISearchBar *_searchBar;
	IBOutlet UITableView *_table;
	NSArray *_data;
	NSThread *_searchThread;
	NSTimer *_searchTimer;
}
-(IBAction)backButtonPressed:(id)sender;
-(IBAction)searchBarSearchButtonClicked:(id)sender;
-(IBAction)searchTypeChanged:(id)sender;
@end
