//
//  TagListCell.m
//  MobileLastFM
//
//  Created by Jono Cole on 03/02/2011.
//  Copyright 2011 Last.fm. All rights reserved.
//

#import "TagListCell.h"
#import <Three20UI/TTPickerViewCell.h>

@implementation TagListCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code.
		_tagCells = [[NSArray alloc] init];
    }
    return self;
}


- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    
    [super setSelected:selected animated:animated];
    
    // Configure the view for the selected state.
}


- (void)dealloc {
    [super dealloc];
}

- (void)addTagWithName:(NSString*)name url:(NSString*)url {
	
}

@end
