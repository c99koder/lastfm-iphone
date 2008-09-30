/* TagEditorViewController.h - Displays and manages a modal tag editor view
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

#import "TagEditorViewController.h"

@implementation TagView
@synthesize tag;

- (id)initWithTag:(NSString *)t {
	CGSize size = [t sizeWithFont:[UIFont boldSystemFontOfSize:20]];
	if(size.width > 272)
		size.width = 272;
	if(self = [super initWithFrame:CGRectMake(0,0,size.width + 19 + 18 + 2,size.height+4)]) {
		self.image = [[UIImage imageNamed:@"tag-bg.png"] stretchableImageWithLeftCapWidth:18 topCapHeight:0];
		tag = [t retain];
		UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(16,2,size.width,size.height)];
		l.textColor = [UIColor whiteColor];
		l.backgroundColor = [UIColor clearColor];
		l.font = [UIFont boldSystemFontOfSize:20];
		l.text = t;
		[self addSubview: l];
		[l release];
		UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
		[b setImage:[UIImage imageNamed:@"remove.png"] forState:UIControlStateNormal];
		[b addTarget:self action:@selector(_deleteButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
		b.frame = CGRectMake(size.width + 16, 2+((size.height - 20)/2), 21, 20);
		[self addSubview: b];
		self.backgroundColor = [UIColor clearColor];
		self.userInteractionEnabled = YES;
	}
	return self;	
}
- (void)_deleteButtonPressed:(id)sender {
	[(TagEditorView *)[self superview] removeTag:self];
}
@end

int tagViewSort(TagView *tag1, TagView *tag2, void *ctx) {
	return [tag1.tag localizedCaseInsensitiveCompare:tag2.tag];
}

@implementation TagEditorView

- (id)initWithCoder:(NSCoder *)coder {
	if(self = [super initWithCoder:coder]) {
		tags = [[NSMutableArray alloc] init];
		self.directionalLockEnabled = YES;
	}
	return self;
}
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	[super touchesEnded:touches withEvent:event];
	[textField resignFirstResponder];
}
- (void)_updateTags:(BOOL)animated {
	int x=4,y=4,height=0;

	[self scrollRectToVisible:[lastTag frame] animated:YES];
	[lastTag release];
	lastTag = nil;
	
	if(animated)
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration: 0.5];
	
	for(TagView *tag in tags) {
		CGSize size = tag.frame.size;
		height = tag.frame.size.height;
		if(x + size.width > self.frame.size.width) {
			x = 4;
			y += size.height + 4;
		}
		tag.frame = CGRectMake(x,y,size.width,size.height);
		tag.alpha = 1;
		x += size.width + 4;
	}
	if([tags count])
		instructions.alpha = 0;
	else
		instructions.alpha = 1;
	if(animated)
		[UIView commitAnimations];
	self.contentSize = CGSizeMake(320,y+height+2);
}
- (void)addTag:(NSString *)tag animated:(BOOL)animated {
	int x=4,y=4;
	CGSize size;
	TagView *t;
	for(t in tags) {
		if([t.tag isEqualToString:tag])
			return;
	}
	t = [[TagView alloc] initWithTag:tag];
	[tags addObject:t];
	[self addSubview:t];
	[tags sortUsingFunction:tagViewSort context:nil];
	for(TagView *tag in tags) {
		size = tag.frame.size;
		if(x + size.width > self.frame.size.width) {
			x = 4;
			y += size.height + 4;
		}
		if(tag == t)
			break;
		x += size.width + 4;
	}
	t.frame = CGRectMake(x, y, size.width, size.height);
	t.alpha = 0;
	[lastTag release];
	lastTag = t;
	if(animated) {
		[(TagEditorViewController *)(self.delegate) tagAdded:tag];
		[self _updateTags:animated];
	}
}
- (void)removeTag:(TagView *)tag {
	[(TagEditorViewController *)(self.delegate) tagRemoved:tag.tag];
	[tags removeObject:tag];
	[tag removeFromSuperview];
	[self _updateTags:YES];
	[(TagEditorViewController *)(self.delegate) reload];
}
- (BOOL)hasTag:(NSString *)tag {
	for(TagView *t in tags) {
		if([t.tag isEqualToString:tag])
			return YES;
	}
	return NO;
}
- (NSArray *)tags {
	return [NSArray arrayWithArray:tags];
}
- (void)setTags:(NSArray *)newTags {
	[tags makeObjectsPerformSelector:@selector(removeFromSuperview)];
	[tags removeAllObjects];
	for(NSString *tag in newTags) {
		[self addTag:tag animated:NO];
	}
	[self _updateTags:NO];
}
- (void)dealloc {
	[tags release];
	[super dealloc];
}
@end

@implementation TagEditorViewController
@synthesize myTags, artistTopTags, albumTopTags, trackTopTags, delegate;

- (void)tagAdded:(NSString *)tag {
	if([tagActions objectForKey:tag])
		[tagActions setObject:[NSNumber numberWithInt:[[tagActions objectForKey:tag] intValue]+1] forKey:tag];
	else
		[tagActions setObject:[NSNumber numberWithInt:1] forKey:tag];
}
- (void)tagRemoved:(NSString *)tag {
	[tagActions setObject:[NSNumber numberWithInt:[[tagActions objectForKey:tag] intValue]-1] forKey:tag];
}
- (void)reload {
	[table reloadData];
}
- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item {
	[table reloadData];
}
- (void)viewDidLoad {
	tabBar.selectedItem = [tabBar.items objectAtIndex:0];
	tagType.tintColor = [UIColor grayColor];
	[self tagTypeChanged:tagType];
}
- (void)tagTypeChanged:(id)sender {
	switch(tagType.selectedSegmentIndex) {
		case 0:
			topTags = trackTopTags;
			tagActions = trackTagActions;
			break;
		case 1:
			topTags = artistTopTags;
			tagActions = artistTagActions;
			break;
		case 2:
			topTags = albumTopTags;
			tagActions = albumTagActions;
			break;
	}
	NSMutableArray *tags = [NSMutableArray array];
	for(NSString *tag in tagActions) {
		if([[tagActions objectForKey:tag] intValue] > -1)
			[tags addObject:tag];
	}
	[tagEditorView setTags:tags];
	[table reloadData];
}
- (void)setAlbumTags:(NSArray *)tags {
	[albumTagActions release];
	albumTagActions = [[NSMutableDictionary alloc] init];
	for(NSDictionary *tag in tags) {
		[albumTagActions setObject:[NSNumber numberWithInteger:0] forKey:[tag objectForKey:@"name"]];
	}
}
- (void)setArtistTags:(NSArray *)tags {
	[artistTagActions release];
	artistTagActions = [[NSMutableDictionary alloc] init];
	for(NSDictionary *tag in tags) {
		[artistTagActions setObject:[NSNumber numberWithInteger:0] forKey:[tag objectForKey:@"name"]];
	}
}
- (void)setTrackTags:(NSArray *)tags {
	[trackTagActions release];
	trackTagActions = [[NSMutableDictionary alloc] init];
	for(NSDictionary *tag in tags) {
		[trackTagActions setObject:[NSNumber numberWithInteger:0] forKey:[tag objectForKey:@"name"]];
	}
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if(tabBar.selectedItem.tag == 0)
		return [topTags count];
	else
		return [myTags count];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	[tableView deselectRowAtIndexPath:newIndexPath animated:YES];
	[tagEditorView addTag:[tableView cellForRowAtIndexPath:newIndexPath].text animated:YES];
	[tableView reloadData];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SimpleCell"];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"SimpleCell"];
	if(tabBar.selectedItem.tag == 0)
		cell.text = [[topTags objectAtIndex:[indexPath row]] objectForKey:@"name"];
	else
		cell.text = [[myTags objectAtIndex:[indexPath row]] objectForKey:@"name"];
	if([tagEditorView hasTag:cell.text])
		cell.textColor = [UIColor grayColor];
	else
		cell.textColor = [UIColor blackColor];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	return cell;
}
- (IBAction)tagButtonPressed:(id)sender {
	if([textField.text length]) {
		[tagEditorView addTag:textField.text animated:YES];
		textField.text = @"";
	}
}
- (IBAction)cancelButtonPressed:(id)sender {
	[delegate tagEditorDidCancel];
}
- (IBAction)doneButtonPressed:(id)sender {
	NSMutableArray *albumtags = [NSMutableArray array];
	NSMutableArray *artisttags = [NSMutableArray array];
	NSMutableArray *tracktags = [NSMutableArray array];
	
	for(NSString *tag in albumTagActions) {
		if([[albumTagActions objectForKey:tag] intValue] == 1)
			[albumtags addObject:tag];
	}
	for(NSString *tag in artistTagActions) {
		if([[artistTagActions objectForKey:tag] intValue] == 1)
			[artisttags addObject:tag];
	}
	for(NSString *tag in trackTagActions) {
		if([[trackTagActions objectForKey:tag] intValue] == 1)
			[tracktags addObject:tag];
	}

	[delegate tagEditorAddArtistTags:artisttags albumTags:albumtags trackTags:tracktags];
	
	[albumtags removeAllObjects];
	[artisttags removeAllObjects];
	[tracktags removeAllObjects];

	for(NSString *tag in albumTagActions) {
		if([[albumTagActions objectForKey:tag] intValue] == -1)
			[albumtags addObject:tag];
	}
	for(NSString *tag in artistTagActions) {
		if([[artistTagActions objectForKey:tag] intValue] == -1)
			[artisttags addObject:tag];
	}
	for(NSString *tag in trackTagActions) {
		if([[trackTagActions objectForKey:tag] intValue] == -1)
			[tracktags addObject:tag];
	}
	
	[delegate tagEditorRemoveArtistTags:artisttags albumTags:albumtags trackTags:tracktags];
}
- (BOOL)textFieldShouldReturn:(UITextField *)t {
	[self tagButtonPressed:t];
	return NO;
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	// Return YES for supported orientations
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
	// Release anything that's not essential, such as cached data
}


- (void)dealloc {
	[topTags release];
	[myTags release];
	[super dealloc];
}


@end
