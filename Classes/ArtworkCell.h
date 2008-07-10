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

#import <UIKit/UIKit.h>

@interface UIViewController (DynamicContent)
- (void)loadContentForCells:(NSArray *)cells;
@end

@interface ArtworkCell : UITableViewCell {
	UIImageView *_artwork;
	UILabel *title;
	UILabel *subtitle;
	UIView *_bar;
	double _maxCacheAge;
	float barWidth;
	NSString *imageURL;
	BOOL _imageLoaded;
	BOOL shouldCacheArtwork;
}
@property (nonatomic, retain) UILabel *title;
@property (nonatomic, retain) UILabel *subtitle;
@property (nonatomic, retain) NSString *imageURL;
@property float barWidth;
@property BOOL shouldCacheArtwork;
-(void)fetchImage;
-(void)addStreamIcon;
@end
