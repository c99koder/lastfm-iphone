/* Scrobbler.m - AudioScrobbler client class
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

#import <Foundation/NSCharacterSet.h>
#import "NSString+MD5.h"
#import "Scrobbler.h"
#include "version.h"
#import "NSString+URLEscaped.h"
#import "LastFMRadio.h"
#if !(TARGET_IPHONE_SIMULATOR)
#import "FlurryAnalytics.h"
#endif

#ifdef SCROBBLED
#import "ScrobblerApp.h"
#define APP_CLASS ScrobblerApp
#else
#import "MobileLastFMApplicationDelegate.h"
#define APP_CLASS MobileLastFMApplicationDelegate
#endif

@implementation Scrobbler
- (void)_trackDidChange {
	if(_queueTimer == nil)
		[self doQueueTimer];
}
- (void)_removeNowPlayingTrack {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSDictionary *track = [(APP_CLASS *)[UIApplication sharedApplication].delegate trackInfo];
	NSLog(@"Clearing now playing");
	[[LastFMService sharedInstance] removeNowPlayingTrack:[track objectForKey:@"title"] byArtist:[track objectForKey:@"creator"] onAlbum:[track objectForKey:@"album"]];
	_sentNowPlaying = FALSE;
	[pool release];
}
- (void)_trackDidPause {
	if(_sentNowPlaying && [LastFMRadio sharedInstance].state == TRACK_PAUSED) {
		[self performSelectorInBackground:@selector(_removeNowPlayingTrack) withObject:nil];
	}
}
- (void)_trackDidResume {
	[_timer invalidate];
	_timer = [NSTimer scheduledTimerWithTimeInterval:1
																						target:self
																					selector:@selector(update:)
																					userInfo:NULL
																					 repeats:NO];
}
- (id)init {
	self = [super init];
	_queue = [[NSMutableArray alloc] initWithCapacity:250];
	_queueTimer = nil;
	_scrobblerState = SCROBBLER_READY;
	_queueTimerInterval = 2;
	_submitted = NO;
	_sentNowPlaying = NO;
	_oldNetworkType = 0;
	[self loadQueue];
	_timer = [NSTimer scheduledTimerWithTimeInterval:1
																						target:self
																					selector:@selector(update:)
																					userInfo:NULL
																					 repeats:NO];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidChange) name:kTrackDidChange object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidPause) name:kTrackDidPause object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidResume) name:kTrackDidResume object:nil];
	return self;
}
- (void)loadQueue {
	@synchronized(_queue) {
		NSArray *savedQueue = [NSKeyedUnarchiver unarchiveObjectWithFile:CACHE_FILE(@"queue.plist")];
		if(savedQueue != nil) {
			[_queue addObjectsFromArray:savedQueue];
			NSLog(@"Loaded queue with %i items\n", [_queue count]);
			[self doQueueTimer];
		}
	}
}
- (void)saveQueue {
	@synchronized(_queue) {
		[NSKeyedArchiver archiveRootObject:_queue toFile:CACHE_FILE(@"queue.plist")];
	}
}
- (void)update:(NSTimer *)timer {
	int networkType;
	
	if(![[[NSUserDefaults standardUserDefaults] objectForKey:@"scrobbling"] isKindOfClass:[NSString class]])
		[[NSUserDefaults standardUserDefaults] setObject:@"YES" forKey:@"scrobbling"];
	
	if([[[NSUserDefaults standardUserDefaults] objectForKey:@"scrobbling"] isEqualToString:@"YES"]) {
		if([(APP_CLASS *)[UIApplication sharedApplication].delegate hasWiFiConnection]) {
			networkType = 2;
		} else if([(APP_CLASS *)[UIApplication sharedApplication].delegate hasNetworkConnection]) {
			networkType = 1;
		} else {
			networkType = 0;
		}
		
		_oldNetworkType = networkType;
		
		if(_scrobblerState != SCROBBLER_SCROBBLING && _scrobblerState != SCROBBLER_NOWPLAYING && [(APP_CLASS *)[UIApplication sharedApplication].delegate isPlaying] && ![(APP_CLASS *)[UIApplication sharedApplication].delegate isPaused]) {
			NSDictionary *track = [(APP_CLASS *)[UIApplication sharedApplication].delegate trackInfo];
			if(track != nil) {
				if([(APP_CLASS *)[UIApplication sharedApplication].delegate trackPosition] > 240 || (([(APP_CLASS *)[UIApplication sharedApplication].delegate trackPosition] * 1000.0f) / [[track objectForKey:@"duration"] floatValue]) > 0.5) {
					if(!_submitted) {
						[self scrobbleTrack:[track objectForKey:@"title"]
											 byArtist:[track objectForKey:@"creator"]
												onAlbum:[track objectForKey:@"album"]
									withStartTime:[[track objectForKey:@"startTime"] intValue]
									 withDuration:[[track objectForKey:@"duration"] intValue]
										 fromSource:[track objectForKey:@"source"]];
						_submitted = TRUE;
					}
				} else {
					_submitted = FALSE;
				}
				if([(APP_CLASS *)[UIApplication sharedApplication].delegate trackPosition] > 10) {
					if(!_sentNowPlaying && [(APP_CLASS *)[UIApplication sharedApplication].delegate hasNetworkConnection]) {
						NSLog(@"Sending now playing");
						[self nowPlayingTrack:[track objectForKey:@"title"] byArtist:[track objectForKey:@"creator"] onAlbum:[track objectForKey:@"album"] withDuration:[[track objectForKey:@"duration"] intValue]];
						_sentNowPlaying = TRUE;
					}
				} else {
					_sentNowPlaying = FALSE;
				}
			}
		}
	}
	if([(APP_CLASS *)[UIApplication sharedApplication].delegate isPlaying]) {
		_timer = [NSTimer scheduledTimerWithTimeInterval:10
																							target:self
																						selector:@selector(update:)
																						userInfo:NULL
																						 repeats:NO];
	} else {
		_timer = [NSTimer scheduledTimerWithTimeInterval:30
																							target:self
																						selector:@selector(update:)
																						userInfo:NULL
																						 repeats:NO];
	}
}
- (void)rateTrack:(NSString *)title byArtist:(NSString *)artist onAlbum:(NSString *)album withStartTime:(int)startTime withDuration:(int)duration fromSource:(NSString *)source rating:(NSString *)rating {
	@synchronized(_queue) {
		for(NSMutableDictionary *track in _queue) {
			if([[track objectForKey:@"title"] isEqualToString:(title==nil)?@"":title] &&
				 [[track objectForKey:@"artist"] isEqualToString:(artist==nil)?@"":artist] &&
				 [[track objectForKey:@"album"] isEqualToString:(album==nil)?@"":album]) {
				if(![rating isEqualToString:@"S"])
					[track setObject:rating forKey:@"rating"];
				return;
			}
		}
		//If we got here, there was no match. Queue it and repeat!
		if([self scrobbleTrack:title byArtist:artist onAlbum:album withStartTime:startTime withDuration:duration fromSource:source])
		{
			for(NSMutableDictionary *track in _queue) {
				if([[track objectForKey:@"title"] isEqualToString:(title==nil)?@"":title] &&
					 [[track objectForKey:@"artist"] isEqualToString:(artist==nil)?@"":artist] &&
					 [[track objectForKey:@"album"] isEqualToString:(album==nil)?@"":album]) {
					[track setObject:rating forKey:@"rating"];
					return;
				}
			}
		}
	}
}
- (BOOL)scrobbleTrack:(NSString *)title byArtist:(NSString *)artist onAlbum:(NSString *)album withStartTime:(int)startTime withDuration:(int)duration fromSource:(NSString *)source {
	@synchronized(_queue) {
		if([[[[NSUserDefaults standardUserDefaults] objectForKey:@"lastScrobble"] objectForKey:@"startTime"] intValue] != startTime ||
			 ![[[[NSUserDefaults standardUserDefaults] objectForKey:@"lastScrobble"] objectForKey:@"title"] isEqualToString:title] ||
			 ![[[[NSUserDefaults standardUserDefaults] objectForKey:@"lastScrobble"] objectForKey:@"artist"] isEqualToString:artist]) {
			NSMutableDictionary *track = [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:(artist==nil)?@"":artist,(title==nil)?@"":title,[NSString stringWithFormat:@"%i",startTime],[NSString stringWithFormat:@"%i",duration],(album==nil)?@"":album,(source==nil)?@"":source, nil]
																																			forKeys:[NSArray arrayWithObjects:@"artist", @"title", @"startTime", @"duration", @"album", @"source", nil]];
			NSLog(@"Queueing %@ - %@ - %@ for submission\n", artist, album, title);
			[[NSUserDefaults standardUserDefaults] setObject:track forKey:@"lastScrobble"];
			[[NSUserDefaults standardUserDefaults] synchronize];
			[_queue addObject:track];
			[self saveQueue];
			return TRUE;
		} else {
			NSLog(@"Ignoring duplicate %@ - %@ - %@\n", artist, album, title);
		}
		return FALSE;
	}
}
- (void)doQueueTimer {
	if(![[[NSUserDefaults standardUserDefaults] objectForKey:@"scrobbling"] isKindOfClass:[NSString class]])
		[[NSUserDefaults standardUserDefaults] setObject:@"YES" forKey:@"scrobbling"];
	
	if(_queueTimer == nil && _scrobblerState != SCROBBLER_OFFLINE && [[[NSUserDefaults standardUserDefaults] objectForKey:@"scrobbling"] isEqualToString:@"YES"]) {
		_queueTimer = [NSTimer scheduledTimerWithTimeInterval:_queueTimerInterval
																								target:self
																							selector:@selector(flushQueue:)
																							userInfo:NULL
																							 repeats:NO];
		NSLog(@"Queue scheduled to be flushed in %i seconds\n", _queueTimerInterval);
		_queueTimerInterval *= 2;
		if(_queueTimerInterval < 2) {
			_queueTimerInterval = 2;
		}
		if(_queueTimerInterval > 7200) _queueTimerInterval = 7200;
	}
}
- (void)nowPlayingTrack:(NSString *)title byArtist:(NSString *)artist onAlbum:(NSString *)album withDuration:(int)duration {
	_scrobblerState = SCROBBLER_NOWPLAYING;
	[[LastFMService sharedInstance] nowPlayingTrack:title byArtist:artist onAlbum:album withDuration:duration/1000];
	_scrobblerState = SCROBBLER_READY;
}
- (void)_flushQueue {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	@synchronized(_queue) {
		NSEnumerator *enumerator = [[[_queue copy] autorelease] objectEnumerator];
		id track;
		
		while((track = [enumerator nextObject])) {
			if([[track objectForKey:@"rating"] isEqualToString:@"L"]) {
				[[LastFMService sharedInstance] loveTrack:[track objectForKey:@"title"] byArtist:[track objectForKey:@"artist"]];
			}
			if([[track objectForKey:@"rating"] isEqualToString:@"B"]) {
				[[LastFMService sharedInstance] banTrack:[track objectForKey:@"title"] byArtist:[track objectForKey:@"artist"]];
			} else {
                [[LastFMService sharedInstance] scrobbleTrack:[track objectForKey:@"title"] byArtist:[track objectForKey:@"artist"] onAlbum:[track objectForKey:@"album"] withDuration:[[track objectForKey:@"duration"] intValue]/1000 timestamp:[[track objectForKey:@"startTime"] intValue] streamId:[track objectForKey:@"source"]];
            }
			if([LastFMService sharedInstance].error == nil || [[LastFMService sharedInstance].error.domain isEqualToString:LastFMServiceErrorDomain]) {
#if !(TARGET_IPHONE_SIMULATOR)
				[FlurryAnalytics logEvent:@"scrobble"];
#endif
				[_queue removeObject:track];
				[self saveQueue];
			} else {
				break;
			}
		}
		_queueTimerInterval = 2;
		_scrobblerState = SCROBBLER_READY;
	}
	[pool release];
}
- (void)flushQueue:(NSTimer *)theTimer {
	if([[[NSUserDefaults standardUserDefaults] objectForKey:@"scrobbling"] isEqualToString:@"YES"]) {
		if(_queueTimer != nil) {
			[_queueTimer invalidate];
			_queueTimer = nil;
		}
		
		if([_queue count] < 1) {
			_queueTimerInterval = 2;
			return;
		}
		
		if(![(APP_CLASS *)[UIApplication sharedApplication].delegate hasNetworkConnection]) {
			_scrobblerState = SCROBBLER_OFFLINE;
			return;
		}
		
		_scrobblerState = SCROBBLER_SCROBBLING;
		[self performSelectorInBackground:@selector(_flushQueue) withObject:nil];
	}
}
- (void)cancelTimer {
	[_timer invalidate];
}
- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_queue release];
	[_queueTimer release];
	[super dealloc];
}
@end
