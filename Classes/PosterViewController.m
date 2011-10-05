    //
//  PosterViewController.m
//  Festivals
//
//  Created by Sam Steele on 6/16/11.
//  Copyright 2011 Last.fm. All rights reserved.
//

#import "PosterViewController.h"
#import "LastFMService.h"

@implementation PosterViewController

// The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithEvent:(NSDictionary *)event {
    self = [super init];
    if (self) {
			_event = [event retain];
			self.hidesBottomBarWhenPushed = YES;
			self.title = [_event objectForKey:@"title"];
    }
    return self;
}

-(void)_fetchImage {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSData *imageData;
	NSString *imageURL = [_event objectForKey:@"megaimage"];
	if([imageURL length] == 0)
		imageURL = [_event objectForKey:@"extralargeimage"];
	
	NSLog(@"Loading poster: %@", imageURL);
	
	if(shouldUseCache(CACHE_FILE([imageURL md5sum]), 1*HOURS)) {
		imageData = [[NSData alloc] initWithContentsOfFile:CACHE_FILE([imageURL md5sum])];
	} else {
		NSURL *url = [[NSURL alloc] initWithString:imageURL];
		imageData = [[NSData alloc] initWithContentsOfURL:url];
		[url release];
		[imageData writeToFile:CACHE_FILE([imageURL md5sum]) atomically: YES];
	}
	UIImage *image = [UIImage imageWithData:imageData];
	//_poster.frame = CGRectMake(0,0,image.size.width,image.size.height);
	//_scrollView.contentSize = image.size;
	[_poster performSelectorOnMainThread:@selector(setImage:) withObject:image waitUntilDone:YES];
	[imageData release];
	NSLog(@"Done");
	[pool release];
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
  [super viewDidLoad];
	_scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0,0,320,416)];
	_scrollView.backgroundColor = [UIColor blackColor];
	_scrollView.maximumZoomScale = 4;
	_scrollView.minimumZoomScale = 1;
	_scrollView.delegate = self;
	self.view = _scrollView;
	_poster = [[UIImageView alloc] initWithFrame:CGRectMake(0,0,320,416)];
	_poster.contentMode = UIViewContentModeScaleAspectFit;
	[_scrollView addSubview:_poster];
	[NSThread detachNewThreadSelector:@selector(_fetchImage) toTarget:self withObject:nil];
}

-(UIView *) viewForZoomingInScrollView:(UIScrollView *)scrollView {
	return _poster;
}

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations.
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc. that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
	[_poster release];
	_poster = nil;
}


- (void)dealloc {
    [super dealloc];
}


@end
