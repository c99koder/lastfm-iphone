/* ArtworkCell.h - A table cell that can fetch its image in the background
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

#import "ArtworkCell.h"
#import "NSString+MD5.h"

@implementation UIViewController (DynamicContent)
- (void)loadContentForCells:(NSArray *)cells {
	if([cells count]) {
		[cells retain];
		for(UITableViewCell *cell in cells) {
			[cell retain];
			if ([cell isKindOfClass:[ArtworkCell class]])
				[(ArtworkCell *)cell fetchImage];
			[cell release];
			cell = nil;
		}
		[cells release];
	}
}
- (void)scrollViewDidEndDecelerating:(UITableView *)tableView {
	if([tableView isKindOfClass:[UITableView class]])
		 [self loadContentForCells: [tableView visibleCells]];
}
- (void)scrollViewDidEndDragging:(UITableView *)tableView willDecelerate:(BOOL)decelerate {
	if ([tableView isKindOfClass:[UITableView class]] && !decelerate) {
		[self loadContentForCells: [tableView visibleCells]];
	}
}
@end

@implementation ArtworkCell

@synthesize title, subtitle, barWidth, imageURL, shouldCacheArtwork;

- (id)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)identifier {
	if (self = [super initWithFrame:frame reuseIdentifier:identifier]) {
		_bar = [[UIView alloc] init];
		[self.contentView addSubview:_bar];
		
		_artwork = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"avatarplaceholder.png"]];
		_artwork.opaque = NO;
		_artwork.alpha = 0.4;
		[self.contentView addSubview:_artwork];
		
		title = [[UILabel alloc] init];
		title.textColor = [UIColor blackColor];
		title.highlightedTextColor = [UIColor whiteColor];
		title.backgroundColor = [UIColor clearColor];
		title.font = [UIFont boldSystemFontOfSize:16];
		[self.contentView addSubview:title];
		
		subtitle = [[UILabel alloc] init];
		subtitle.textColor = [UIColor grayColor];
		subtitle.highlightedTextColor = [UIColor whiteColor];
		subtitle.backgroundColor = [UIColor clearColor];
		subtitle.font = [UIFont systemFontOfSize:14];
		[self.contentView addSubview:subtitle];
		
		self.selectionStyle = UITableViewCellSelectionStyleBlue;
		_imageLoaded = NO;
		shouldCacheArtwork = NO;
	}
	return self;
}
- (void)layoutSubviews {
	[super layoutSubviews];
	
	CGRect frame = [self.contentView bounds];
	if(imageURL)
	_artwork.frame = CGRectMake(frame.origin.x, frame.origin.y, frame.size.height, frame.size.height);
	if([subtitle.text length]) {
		title.frame = CGRectMake(_artwork.frame.origin.x + _artwork.frame.size.width + 6, frame.origin.y + 6, frame.size.width - _artwork.frame.size.width - 6, 20);
		subtitle.frame = CGRectMake(_artwork.frame.origin.x + _artwork.frame.size.width + 6, frame.origin.y + 26, frame.size.width - _artwork.frame.size.width - 6, 20);
	} else {
		title.font = [UIFont boldSystemFontOfSize:18];
		title.frame = CGRectMake(_artwork.frame.origin.x + _artwork.frame.size.width + 6, _artwork.frame.size.height / 2 - 10, frame.size.width - _artwork.frame.size.width - 6, 20);
	}
	if(barWidth > 0) {
		_bar.frame = CGRectMake(_artwork.frame.size.width,0,barWidth*([self frame].size.width - _artwork.frame.size.width),[self frame].size.height);
		_bar.backgroundColor = [UIColor colorWithWhite:0.8 alpha:0.4];
	}
}
- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
	[super setSelected:selected animated:animated];
	title.highlighted = selected;
	subtitle.highlighted = selected;
}
-(void)_fetchImage {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSData *imageData;
	if(shouldUseCache(CACHE_FILE([imageURL md5sum]), 1*HOURS)) {
		imageData = [[NSData alloc] initWithContentsOfFile:CACHE_FILE([imageURL md5sum])];
	} else {
		imageData = [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString:imageURL]];
		if(shouldCacheArtwork)
			[imageData writeToFile:CACHE_FILE([imageURL md5sum]) atomically: YES];
	}
	UIImage *image = [[UIImage alloc] initWithData:imageData];
	[self performSelectorOnMainThread:@selector(setImage:) withObject:image waitUntilDone:YES];
	[image release];
	[imageData release];
	_imageLoaded = YES;
	[pool release];
}
-(void)setImage:(UIImage *)image {
	_artwork.image = image;
	_artwork.alpha = 1;
	_artwork.opaque = YES;
}
-(void)fetchImage {
	if(!_imageLoaded)
		[NSThread detachNewThreadSelector:@selector(_fetchImage) toTarget:self withObject:nil];
}
- (void)addStreamIcon {
	UIImageView *img = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"streaming.png"]];
	self.accessoryView = img;
	[img release];
}
- (void)dealloc {
	[title release];
	[subtitle release];
	[imageURL release];
	[_bar release];
	[_artwork release];
	[super dealloc];
}
@end
