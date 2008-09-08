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
- (void)_updateTags {
	int x=4,y=4,height=0;

	[self scrollRectToVisible:[lastTag frame] animated:YES];
	[lastTag release];
	lastTag = nil;
	
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration: 0.5];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationDidStopSelector:@selector(_animationStopped)];
	
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
	[UIView commitAnimations];
	self.contentSize = CGSizeMake(320,y+height+2);
}
- (void)addTag:(NSString *)tag {
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
	[self _updateTags];
}
- (void)removeTag:(TagView *)tag {
	[tags removeObject:tag];
	[tag removeFromSuperview];
	[self _updateTags];
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
- (void)dealloc {
	[tags release];
	[super dealloc];
}
@end

@implementation TagEditorViewController
@synthesize myTags, topTags, delegate;

- (NSArray *)tags {
	return [tagEditorView tags];
}
- (void)setTags:(NSArray *)tags {
	for(NSString *tag in tags) {
		[tagEditorView addTag: tag];
	}
}
- (void)reload {
	[table reloadData];
}
- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item {
	[table reloadData];
}
- (void)viewDidLoad {
	tabBar.selectedItem = [tabBar.items objectAtIndex:0];
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
	[tagEditorView addTag:[tableView cellForRowAtIndexPath:newIndexPath].text];
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
		[tagEditorView addTag:textField.text];
		textField.text = @"";
	}
}
- (IBAction)cancelButtonPressed:(id)sender {
	[delegate tagEditorDidCancel];
}
- (IBAction)doneButtonPressed:(id)sender {
	NSMutableArray *tags = [[NSMutableArray alloc] init];
	for(TagView *tagView in [tagEditorView tags]) {
		[tags addObject:tagView.tag];
	}
	[delegate tagEditorCommitTags:[NSArray arrayWithArray:tags]];
	[tags release];
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
	[super dealloc];
}


@end
