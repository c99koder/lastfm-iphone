//
//  TagEditorViewController.m
//  MobileLastFM
//
//  Created by Sam Steele on 8/13/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TagEditorViewController.h"

@implementation TagView
@synthesize tag;

- (id)initWithTag:(NSString *)t {
	CGSize size = [t sizeWithFont:[UIFont boldSystemFontOfSize:22]];
	if(self = [super initWithFrame:CGRectMake(0,0,size.width + size.height + 8,size.height)]) {
		tag = [t retain];
		UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(6,0,size.width,size.height)];
		l.textColor = [UIColor whiteColor];
		l.backgroundColor = [UIColor clearColor];
		l.font = [UIFont boldSystemFontOfSize:22];
		l.text = t;
		[self addSubview: l];
		[l release];
		UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
		[b setImage:[UIImage imageNamed:@"remove.png"] forState:UIControlStateNormal];
		[b addTarget:self action:@selector(_deleteButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
		b.frame = CGRectMake(size.width + 8, 2, size.height, size.height-4);
		[self addSubview: b];
		self.backgroundColor = [UIColor redColor];
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
- (id)initWithCoder:(NSCoder *)decoder {
	if(self = [super initWithCoder:decoder]) {
		tags = [[NSMutableArray alloc] init];
	}
	return self;
}
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	[textField resignFirstResponder];
}
- (void)_updateTags {
	[tags sortUsingFunction:tagViewSort context:nil];
	int x=4,y=4,height=0;
	
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
		x += size.width + 4;
	}
	[UIView commitAnimations];
}
- (void)addTag:(NSString *)tag {
	TagView *t;
	for(t in tags) {
		if([t.tag isEqualToString:tag])
			return;
	}
	t = [[TagView alloc] initWithTag:tag];
	[tags addObject:t];
	[self addSubview:t];
	CGRect frame = t.frame;
	frame.origin.x = 16;
	frame.origin.y = self.frame.size.height + textField.frame.origin.y + 4;
	t.frame = frame;
	[t release];
	[self _updateTags];
}
- (void)removeTag:(TagView *)tag {
	[tags removeObject:tag];
	[tag removeFromSuperview];
	[self _updateTags];
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
		return [myTags count];
	else
		return [topTags count];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	[tableView deselectRowAtIndexPath:newIndexPath animated:YES];
	[tagEditorView addTag:[tableView cellForRowAtIndexPath:newIndexPath].text];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SimpleCell"];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"SimpleCell"];
	if(tabBar.selectedItem.tag == 0)
		cell.text = [[myTags objectAtIndex:[indexPath row]] objectForKey:@"name"];
	else
		cell.text = [[topTags objectAtIndex:[indexPath row]] objectForKey:@"name"];		
	cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
	return cell;
}
- (IBAction)tagButtonPressed:(id)sender {
	[tagEditorView addTag:textField.text];
	textField.text = @"";
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
