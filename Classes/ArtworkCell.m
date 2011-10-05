/* ArtworkCell.m - A table cell that can fetch its image in the background
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

#import <QuartzCore/QuartzCore.h>
#import "ArtworkCell.h"
#import "NSString+MD5.h"

@implementation UISearchDisplayController (DynamicContent)
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

@synthesize title, subtitle, barWidth, shouldCacheArtwork, shouldFillHeight, Yoffset, detailAtBottom;

-(void)setShouldRoundTop:(BOOL)round {
	shouldRoundTop = round;
	_artwork.image = [self roundedImage:_artwork.image];
}
-(BOOL)shouldRoundTop {
	return shouldRoundTop;
}
-(void)setShouldRoundBottom:(BOOL)round {
	shouldRoundBottom = round;
	_artwork.image = [self roundedImage:_artwork.image];
}
-(BOOL)shouldRoundBottom {
	return shouldRoundBottom;
}
-(void)setPlaceholder:(NSString *)name {
	[placeholder release];
	placeholder = [name retain];
	_artwork.image = [UIImage imageNamed:placeholder];
}
-(NSString *)placeholder {
	return placeholder;
}
-(void)setImageURL:(NSString *)url {
	if(imageURL) {
		[imageURL release];
		imageURL = nil;
	}
	self.noArtwork = NO;
	imageURL = [url retain];
	NSData *imageData;
	
	if(shouldUseCache(CACHE_FILE([imageURL md5sum]), 1*HOURS) || [imageURL hasPrefix:@"/"]) {
		if([imageURL hasPrefix:@"/"])
			imageData = [[NSData alloc] initWithContentsOfFile:imageURL];
		else
			imageData = [[NSData alloc] initWithContentsOfFile:CACHE_FILE([imageURL md5sum])];
			
		UIImage *image = [UIImage imageWithData:imageData];
		if(shouldRoundTop || shouldRoundBottom) {
			image = [self roundedImage:image];
		}
		[self performSelectorOnMainThread:@selector(setImage:) withObject:image waitUntilDone:YES];
		[imageData release];
		_imageLoaded = YES;
	}
}
-(NSString *)imageURL {
	return imageURL;
}
-(UIImage *)reflectionImage:(UIImage *)image {
	UIImage *img = image;
	int w = self.contentView.bounds.size.height;
	int h = self.contentView.bounds.size.height;

	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(NULL, w, h, 8, 4 * w, colorSpace, kCGImageAlphaPremultipliedFirst);
	
	CGRect rect = CGRectMake(0, 0, w, h);
	CGContextDrawImage(context, rect, img.CGImage);
	
	CGImageRef imageMasked = CGBitmapContextCreateImage(context);
	CGContextRelease(context);
	CGColorSpaceRelease(colorSpace);
	
	img = [UIImage imageWithCGImage:imageMasked];
	CFRelease(imageMasked);
	return img;
}
-(UIImage *)roundedImage:(UIImage *)image {
	UIImage *img = image;
	float scale = 1.0f;
	if([[UIScreen mainScreen] respondsToSelector:@selector(scale)])
		scale = [[UIScreen mainScreen] scale];
	int w = self.contentView.bounds.size.height * scale;
	int h = self.contentView.bounds.size.height * scale;
	
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(NULL, w, h, 8, 4 * w, colorSpace, kCGImageAlphaPremultipliedFirst);
	
	CGRect rect = CGRectMake(0, 0, w, h);
	float radius = 8.0f * scale;
	
	if(shouldRoundTop) {
		CGContextBeginPath(context);
		CGContextMoveToPoint(context, rect.origin.x, rect.origin.y + radius);
		CGContextAddLineToPoint(context, rect.origin.x, rect.origin.y + rect.size.height - radius);
		CGContextAddArc(context, rect.origin.x + radius, rect.origin.y + rect.size.height - radius, 
										radius, M_PI / 4, M_PI / 2, 1);
		CGContextAddLineToPoint(context, rect.origin.x + rect.size.width, 
														rect.origin.y + rect.size.height);
		CGContextAddLineToPoint(context, rect.origin.x + rect.size.width, rect.origin.y);
		CGContextAddLineToPoint(context, rect.origin.x, rect.origin.y);
		CGContextClosePath(context);
		CGContextClip(context);
	}

	if(shouldRoundBottom) {
		CGContextBeginPath(context);
		CGContextMoveToPoint(context, rect.origin.x, rect.origin.y);
		CGContextAddLineToPoint(context, rect.origin.x, rect.origin.y + rect.size.height);
		CGContextAddLineToPoint(context, rect.origin.x + rect.size.width, 
														rect.origin.y + rect.size.height);
		CGContextAddLineToPoint(context, rect.origin.x + rect.size.width, rect.origin.y);
		CGContextAddLineToPoint(context, rect.origin.x + radius, rect.origin.y);
		CGContextAddArc(context, rect.origin.x + radius, rect.origin.y + radius, radius, 
										-M_PI / 2, M_PI, 1);
		CGContextClosePath(context);
		CGContextClip(context);
	}
	
	CGContextDrawImage(context, rect, img.CGImage);
	
	CGImageRef imageMasked = CGBitmapContextCreateImage(context);
	CGContextRelease(context);
	CGColorSpaceRelease(colorSpace);
	
	img = [UIImage imageWithCGImage:imageMasked];
	CFRelease(imageMasked);
	return img;
}

-(void)addBorder {
	[self addBorderWithColor: [UIColor blackColor]];
}
-(void)addBorderWithColor:(UIColor*)color {
	[_artwork.layer setBorderColor: [color CGColor]];
	[_artwork.layer setBorderWidth: 1.0];
	[_reflectedArtwork.layer setBorderColor:[color CGColor]];
	[_reflectedArtwork.layer setBorderWidth: 1.0];
}
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
	if (self = [super initWithStyle:style reuseIdentifier:identifier]) {
		self.contentView.bounds = CGRectMake(0,0,52,52);
		_style = style;
		
		_bar = [[UIView alloc] init];
		[self.contentView addSubview:_bar];

		placeholder = @"noimage_user.png";
		
		_artwork = [[UIImageView alloc] initWithImage:[UIImage imageNamed:placeholder]];
		_artwork.contentMode = UIViewContentModeScaleAspectFill;
		_artwork.clipsToBounds = YES;
		_artwork.opaque = NO;
		_artwork.alpha = 0.4;
		[self.contentView addSubview:_artwork];
		
		title = [[UILabel alloc] init];
		title.textColor = [UIColor blackColor];
		title.highlightedTextColor = [UIColor whiteColor];
		title.backgroundColor = [UIColor clearColor];
		title.font = [UIFont boldSystemFontOfSize:16];
		title.lineBreakMode = UILineBreakModeTailTruncation;
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
		detailAtBottom = NO;
		Yoffset = 6;
	}
	return self;
}
- (void)addReflection:(NSString *)maskName {
	_reflectedArtwork = [[UIImageView alloc] initWithFrame:CGRectZero];
	_reflectedArtwork.contentMode = UIViewContentModeBottom;
	_reflectedArtwork.clipsToBounds = YES;
	_reflectedArtwork.opaque = NO;
	_reflectedArtwork.alpha = 0.4;
	_reflectedArtwork.transform = CGAffineTransformMake(1.0f, 0.0f, 0.0f, -1.0f, 0.0f, 0.0f);
	[self.contentView addSubview:_reflectedArtwork];
	
	_reflectionMask = [[UIImageView alloc] initWithImage:[UIImage imageNamed:maskName]];
	_reflectionMask.contentMode = UIViewContentModeTop;
	_reflectionMask.clipsToBounds = YES;
	_reflectionMask.opaque = NO;
	_reflectionMask.backgroundColor = [UIColor clearColor];
	[self.contentView addSubview:_reflectionMask];
}
- (void)layoutSubviews {
	[super layoutSubviews];
	
	CGRect frame = [self.contentView bounds];
	if(self.accessoryView != nil)
		frame.size.width = frame.size.width - [self.accessoryView bounds].size.width;
	
	float detailWidth = 0;
	if([self.detailTextLabel.text length] && _style == UITableViewCellStyleValue1) {
		detailWidth = [self.detailTextLabel.text sizeWithFont:self.detailTextLabel.font].width;
		if(detailWidth > (frame.size.width - _artwork.frame.size.width) * 0.5f)
			detailWidth = (frame.size.width - _artwork.frame.size.width) * 0.5f;
	}
	
	if( noArtwork ) {
		_artwork.frame = CGRectMake(_artwork.frame.origin.x, _artwork.frame.origin.y, 5.0f, _artwork.frame.size.height);
	}
	
	if(!noArtwork && !_artwork.hidden) {
		if(shouldRoundTop || shouldRoundBottom || shouldFillHeight)
			_artwork.frame = CGRectMake(frame.origin.x, frame.origin.y, frame.size.height, frame.size.height);
		else
			_artwork.frame = CGRectMake(frame.origin.x+4, frame.origin.y+4, frame.size.height-8, frame.size.height-8);
	}
	
	_artwork.image = [self roundedImage:_artwork.image];
	
	if(_reflectedArtwork) {
		CGRect artframe = CGRectMake(_artwork.frame.origin.x , _artwork.frame.origin.y + _artwork.frame.size.height - _artwork.layer.borderWidth, _artwork.frame.size.width, 20);
		_reflectedArtwork.frame = artframe;
		artframe = CGRectMake(_artwork.frame.origin.x , _artwork.frame.origin.y + _artwork.frame.size.height, _artwork.frame.size.width, 20);
		_reflectionMask.frame = artframe;
	}
	
	if([subtitle.text length]) {
		if( detailAtBottom ) 
			title.frame = CGRectMake(_artwork.frame.origin.x + _artwork.frame.size.width + 6, frame.origin.y + Yoffset, frame.size.width - _artwork.frame.size.width - 20, 22);
		else
			title.frame = CGRectMake(_artwork.frame.origin.x + _artwork.frame.size.width + 6, frame.origin.y + Yoffset, frame.size.width - _artwork.frame.size.width - 20 - detailWidth, 22);

		float height = 20;
		if(subtitle.numberOfLines != 1)
			height = [subtitle.text sizeWithFont:subtitle.font constrainedToSize:CGSizeMake(frame.size.width - _artwork.frame.size.width - 20, frame.size.height - 20 - (Yoffset * 2)) lineBreakMode:subtitle.lineBreakMode].height;
		if( detailAtBottom ) 
			subtitle.frame = CGRectMake(_artwork.frame.origin.x + _artwork.frame.size.width + 6, frame.origin.y + 20 + Yoffset, frame.size.width - _artwork.frame.size.width - detailWidth - 20, height);
		else
			subtitle.frame = CGRectMake(_artwork.frame.origin.x + _artwork.frame.size.width + 6, frame.origin.y + 20 + Yoffset, frame.size.width - _artwork.frame.size.width - 20, height);
	} else {
		title.font = [UIFont boldSystemFontOfSize:18];
		title.frame = CGRectMake(_artwork.frame.origin.x + _artwork.frame.size.width + 6, Yoffset, frame.size.width - _artwork.frame.size.width - 20 - detailWidth, frame.size.height - (Yoffset * 2));
		subtitle.frame = CGRectZero;
	}
	if([self.detailTextLabel.text length]) {
		if(_style == UITableViewCellStyleValue1) {
			if( detailAtBottom ) {
				CGSize textSize = [title.text sizeWithFont:title.font forWidth:title.bounds.size.width lineBreakMode:title.lineBreakMode];
				CGSize subtitleSize = [subtitle.text sizeWithFont:subtitle.font forWidth:subtitle.bounds.size.width lineBreakMode:subtitle.lineBreakMode];
				float detailX = subtitle.frame.origin.x + subtitleSize.width + 2;
				float detailY = frame.origin.y + frame.size.height - textSize.height - 5;
				self.detailTextLabel.frame = CGRectMake(detailX, detailY, frame.size.width - detailX, textSize.height);
			} else {
				CGSize detailSize = [title.text sizeWithFont:title.font forWidth:title.bounds.size.width lineBreakMode:title.lineBreakMode];
				float detailX = title.frame.origin.x + detailSize.width + 2;
				self.detailTextLabel.frame = CGRectMake(detailX, title.frame.origin.y + 1, frame.size.width - detailX, title.frame.size.height);
			}

		}
		if(_style == UITableViewCellStyleValue2) {
			float detailY = subtitle.frame.origin.y + subtitle.frame.size.height;
			self.detailTextLabel.frame = CGRectMake(_artwork.frame.origin.x + _artwork.frame.size.width + 6, detailY, frame.size.width - _artwork.frame.size.width - 6, 16);
		}
	}
	if(barWidth > 0) {
		_bar.frame = CGRectMake(0,0,barWidth*([self frame].size.width - 20),[self frame].size.height);
		_bar.backgroundColor = [UIColor colorWithWhite:0.8 alpha:0.4];
		_bar.opaque = NO;
	}
}
- (BOOL)noArtwork {
	return noArtwork;
}
- (void)setNoArtwork:(BOOL)hidden {
	CGRect frame = [self.contentView bounds];
	if(hidden) {
		_artwork.frame = CGRectMake(4, 0, 0, 0);
	} else {
		_artwork.frame = CGRectMake(frame.origin.x+4, frame.origin.y+4, frame.size.height-8, frame.size.height-8);
	}
	_artwork.hidden = hidden;
}
- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
	[super setSelected:selected animated:animated];
	if(self.selectionStyle != UITableViewCellSelectionStyleNone) {
		title.highlighted = selected;
		subtitle.highlighted = selected;
		if(selected) {
			_bar.alpha = 0;
		} else {
			_bar.alpha = 0;
			[UIView beginAnimations:nil context:nil];
			[UIView setAnimationDuration:0.4];
			_bar.alpha = 1;
			[UIView commitAnimations];
		}
	}
}
-(void)_fetchImage {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSData *imageData;
	
	if(shouldUseCache(CACHE_FILE([imageURL md5sum]), 1*HOURS)) {
		imageData = [[NSData alloc] initWithContentsOfFile:CACHE_FILE([imageURL md5sum])];
	} else {
		NSURL *url = [[NSURL alloc] initWithString:imageURL];
		imageData = [[NSData alloc] initWithContentsOfURL:url];
		[url release];
		if(shouldCacheArtwork)
			[imageData writeToFile:CACHE_FILE([imageURL md5sum]) atomically: YES];
	}
	UIImage *image = [UIImage imageWithData:imageData];
	if(shouldRoundTop || shouldRoundBottom) {
		image = [self roundedImage:image];
	}
	[self performSelectorOnMainThread:@selector(setImage:) withObject:image waitUntilDone:YES];
	[imageData release];
	_imageLoaded = YES;
	[pool release];
}
-(void)setImage:(UIImage *)image {
	_artwork.image = image;
	_artwork.alpha = 1;
	_artwork.opaque = YES;
	if(_reflectedArtwork) {
		_reflectedArtwork.image = [self reflectionImage: image];
		_reflectedArtwork.alpha = 1;
		_reflectedArtwork.opaque = YES;
	}
}
-(void)fetchImage {
	if(!_imageLoaded)
		if([imageURL length])
			[NSThread detachNewThreadSelector:@selector(_fetchImage) toTarget:self withObject:nil];
		else
			_artwork.alpha = 1;
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
	[_reflectedArtwork release];
	[_reflectionMask release];
	[super dealloc];
}
@end
