/* ArtworkCell.h - A table cell that can fetch its image in the background
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

#import <UIKit/UIKit.h>

@interface UIViewController (DynamicContent)
- (void)loadContentForCells:(NSArray *)cells;
@end

@interface ArtworkCell : UITableViewCell {
	UIImageView *_artwork;
	UIImageView *_reflectedArtwork;
	UIImageView *_reflectionMask;
	UILabel *title;
	UILabel *subtitle;
	UIView *_bar;
	double _maxCacheAge;
	float barWidth;
	float Yoffset;
	NSString *imageURL;
	NSString *placeholder;
	BOOL _imageLoaded;
	BOOL shouldCacheArtwork;
	BOOL shouldRoundTop;
	BOOL shouldRoundBottom;
	BOOL shouldFillHeight;
	BOOL detailAtBottom;
	BOOL noArtwork;
	UITableViewCellStyle _style;
}
@property (nonatomic, retain) UILabel *title;
@property (nonatomic, retain) UILabel *subtitle;
@property (nonatomic, retain) NSString *imageURL;
@property (nonatomic, retain) NSString *placeholder;
@property float barWidth;
@property float Yoffset;
@property BOOL shouldCacheArtwork;
@property BOOL shouldRoundTop;
@property BOOL shouldRoundBottom;
@property BOOL shouldFillHeight;
@property BOOL detailAtBottom;
@property BOOL noArtwork;
-(void)fetchImage;
-(void)addStreamIcon;
-(void)addBorder;
-(void)addBorderWithColor:(UIColor*)color;
-(void)addReflection:(NSString *)maskName;
-(UIImage *)roundedImage:(UIImage *)image;
@end
