/* TagEditorViewController.m - Displays and manages a modal tag editor view
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

#import "TagEditorViewController.h"

int tagSort(id tag1, id tag2, void *context);

@implementation TagsModel

@synthesize tags = _tags;

- (id)initWithTopTags:(NSArray *)topTags userTags:(NSArray *)userTags {
	int x=0, y=0;
	if (self = [super init]) {
		_delegates = nil;
		NSMutableArray *newUserTags = [[NSMutableArray alloc] init];
		NSMutableArray *newTopTags = [NSMutableArray arrayWithArray:topTags];
		for(x = 0; x < [userTags count]; x++) {
			for(y = 0; y < [newTopTags count]; y++) {
				if([[[userTags objectAtIndex:x] objectForKey:@"name"] isEqualToString:[[newTopTags objectAtIndex:y] objectForKey:@"name"]]) {
					[newUserTags addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[userTags objectAtIndex:x] objectForKey:@"name"],
																																			[NSString stringWithFormat:@"%i",([[[userTags objectAtIndex:x] objectForKey:@"name"] intValue] + [[[newTopTags objectAtIndex:y] objectForKey:@"count"] intValue])],nil] forKeys:[NSArray arrayWithObjects:@"name", @"count",nil]]];
					[newTopTags removeObjectAtIndex:y];
					break;
				}
			}
			if(y == [newTopTags count])
				[newUserTags addObject:[userTags objectAtIndex:x]];
		}
		_allTags = [[[newTopTags arrayByAddingObjectsFromArray:newUserTags] sortedArrayUsingFunction:tagSort context:nil] retain];
		_tags = nil;
		[newUserTags release];
	}
	return self;
}

- (void)dealloc {
	TT_RELEASE_SAFELY(_delegates);
	TT_RELEASE_SAFELY(_allTags);
	TT_RELEASE_SAFELY(_tags);
	[super dealloc];
}


- (void)loadTags {
	TT_RELEASE_SAFELY(_tags);
	_tags = [_allTags mutableCopy];
}

- (void)search:(NSString*)text {
	[self cancel];
	
	self.tags = [NSMutableArray array];
	
	[_delegates makeObjectsPerformSelector:@selector(modelDidStartLoad:) withObject:self];
	
	if (text.length) {
		text = [text lowercaseString];
		for (NSDictionary *tag in _allTags) {
			if ([[[tag objectForKey:@"name"] lowercaseString] rangeOfString:text].location == 0) {
				[_tags addObject:tag];
			}
		}    
	}
	
	[_delegates makeObjectsPerformSelector:@selector(modelDidFinishLoad:) withObject:self];
}

#pragma mark -
#pragma mark TTModel methods

- (NSMutableArray *)delegates {
	if (!_delegates) {
		_delegates = TTCreateNonRetainingArray();
	}
	return _delegates;
}

- (BOOL)isLoadingMore {
	return NO;
}

- (BOOL)isOutdated {
	return NO;
}

- (BOOL)isLoaded {
	return !!_tags;
}

- (BOOL)isLoading {
	return NO;
}

- (BOOL)isEmpty {
	return !_tags.count;
}

- (void)load:(TTURLRequestCachePolicy)cachePolicy more:(BOOL)more {
}

- (void)invalidate:(BOOL)erase {
}

- (void)cancel {
}

@end

@implementation TagsDataSource

- (id)initWithTopTags:(NSArray *)topTags userTags:(NSArray *)userTags {
	if (self = [super init]) {
		_tags = [[TagsModel alloc] initWithTopTags:topTags userTags:userTags];
		[_tags loadTags];
		self.model = _tags;
	}
	return self;
}

- (void)dealloc {
	TT_RELEASE_SAFELY(_tags);
	[super dealloc];
}

#pragma mark -
#pragma mark TTTableViewDataSource methods

- (void)tableViewDidLoadModel:(UITableView*)tableView {
	self.items = [NSMutableArray array];
	self.sections = [NSMutableArray array];

	[self.sections addObject:@"Recommended Tags"];
	NSMutableArray *section = [NSMutableArray array];
	for (NSDictionary *tag in _tags.tags) {
		
		TTTableItem *item = [TTTableTextItem itemWithText:[tag objectForKey:@"name"] URL:nil];
		[section addObject:item];
	}
	[self.items addObject:section];
}

- (void)search:(NSString*)text {
	[_tags search:text];
}

@end


@implementation TagEditorViewController
@synthesize delegate;

- (id)initWithTopTags:(NSArray *)topTags userTags:(NSArray *)userTags {
	if (self = [super init]) {
		self.title = @"Tags";
		self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelButtonPressed:)] autorelease];
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneButtonPressed:)] autorelease];
		
		_tags = [[TagsDataSource alloc] initWithTopTags:topTags userTags:userTags];
		_cells = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)loadView {
	[super loadView];
	self.view.backgroundColor = TTSTYLEVAR(backgroundColor);

	UINavigationBar *bar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0,0,320,44)];
	[bar pushNavigationItem:self.navigationItem animated:NO];
	[self.view addSubview: bar];
	[bar release];
	
	UIScrollView *scrollView = [[[UIScrollView alloc] initWithFrame:CGRectMake(0,44,320,self.view.frame.size.height-44)] autorelease];
	scrollView.backgroundColor = TTSTYLEVAR(backgroundColor);
	scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
	scrollView.canCancelContentTouches = NO;
	scrollView.showsVerticalScrollIndicator = NO;
	scrollView.showsHorizontalScrollIndicator = NO;
	[self.view addSubview:scrollView];
	
	textField = [[[TTPickerTextField alloc] init] autorelease];
	textField.dataSource = _tags;
	textField.autocorrectionType = UITextAutocorrectionTypeNo;
	textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
	textField.rightViewMode = UITextFieldViewModeAlways;
	textField.delegate = self;
	textField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[textField sizeToFit];
	[textField becomeFirstResponder];
	
	[scrollView addSubview:textField];
	
	CGFloat y = 0;
	
	for (UIView *view in scrollView.subviews) {
		view.frame = CGRectMake(0, y, self.view.frame.size.width, view.frame.size.height);
		y += view.frame.size.height;
	}
	
	scrollView.contentSize = CGSizeMake(scrollView.frame.size.width, y);
}

- (BOOL)textFieldShouldReturn:(UITextField *)txtField {
	if([[txtField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length]) {
		TTTableItem *item = [TTTableTextItem itemWithText:[txtField.text stringByTrimmingCharactersInSet:
																											 [NSCharacterSet whitespaceAndNewlineCharacterSet]] URL:nil];
		[textField addCellWithObject: item];
	}
	return NO;
}
- (IBAction)cancelButtonPressed:(id)sender {
	[delegate tagEditorDidCancel];
}
- (IBAction)doneButtonPressed:(id)sender {
	NSMutableArray *tags = [NSMutableArray array];
	
	for(NSString *tag in tagActions) {
		if([[tagActions objectForKey:tag] intValue] == 1)
			[tags addObject:tag];
	}
	
	[delegate tagEditorAddTags:tags];
	
	[tags removeAllObjects];
	
	for(NSString *tag in tagActions) {
		if([[tagActions objectForKey:tag] intValue] == -1)
			[tags addObject:tag];
	}

	[delegate tagEditorRemoveTags:tags];
}
- (void)setTags:(NSArray *)tags {
	[tagActions release];
	tagActions = [[NSMutableDictionary alloc] init];
	for(NSDictionary *tag in tags) {
		TTTableItem *item = [TTTableTextItem itemWithText:[tag objectForKey:@"name"] URL:nil];
		[textField addCellWithObject: item];
		[tagActions setObject:[NSNumber numberWithInteger:0] forKey:[tag objectForKey:@"name"]];
	}
}
- (void)textField:(TTPickerTextField*)txtField didAddCellAtIndex:(NSInteger)index {
	[_cells addObject:[textField.cells lastObject]];
	NSString *tag = ((TTTableTextItem *)[_cells lastObject]).text;

	if([tagActions objectForKey:tag])
		[tagActions setObject:[NSNumber numberWithInt:[[tagActions objectForKey:tag] intValue]+1] forKey:tag];
	else
		[tagActions setObject:[NSNumber numberWithInt:1] forKey:tag];
}
- (void)textField:(TTPickerTextField*)txtField didRemoveCellAtIndex:(NSInteger)index {
	NSString *tag = ((TTTableTextItem *)[_cells objectAtIndex:index]).text;
	[_cells removeObjectAtIndex:index];

	[tagActions setObject:[NSNumber numberWithInt:[[tagActions objectForKey:tag] intValue]-1] forKey:tag];
}
- (void)dealloc {
	[tagActions release];
	[_cells release];
	[_tags release];
	[super dealloc];
}
@end
