/* Scrobbler.m - AudioScrobbler client class
 * Copyright (C) 2007 Sam Steele
 *
 * This file is part of MobileScrobbler.
 *
 * MobileScrobbler is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2
 * as published by the Free Software Foundation.
 *
 * MobileScrobbler is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA
 */
#import <Foundation/NSCharacterSet.h>
#import "NSString+MD5.h"
#import "Scrobbler.h"
#include "version.h"
#import "NSString+URLEscaped.h"
#import "LastFMRadio.h"

#ifdef SCROBBLED
#import "ScrobblerApp.h"
#define APP_CLASS ScrobblerApp
#else
#import "MobileLastFMApplicationDelegate.h"
#define APP_CLASS MobileLastFMApplicationDelegate
#endif

@implementation Scrobbler
- (id)init {
	self = [super init];
	_sess = nil;
	_nowPlayingURL = nil;
	_scrobbleURL = nil;
	_queue = [[NSMutableArray alloc] initWithCapacity:250];
	_queueTimer = nil;
	_scrobblerState = SCROBBLER_OFFLINE;
	_scrobblerResult = NSLocalizedString(@"Offline", @"Offline");
	_queueTimerInterval = 60;
	_totalScrobbled = [[NSUserDefaults standardUserDefaults] integerForKey:@"totalScrobbled"];
	_maxSubmissionCount = 50;
	_connection = nil;
	_submitted = NO;
	_sentNowPlaying = NO;
	_oldNetworkType = 0;
	[self loadQueue];
	_timer = [NSTimer scheduledTimerWithTimeInterval:1
																						target:self
																					selector:@selector(update:)
																					userInfo:NULL
																					 repeats:NO];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(flushQueue:) name:kLastFMRadio_TrackDidChange object:nil];
	return self;
}
- (void)loadQueue {
	NSArray *savedQueue = [NSKeyedUnarchiver unarchiveObjectWithFile:CACHE_FILE(@"queue.plist")];
	if(savedQueue != nil) {
		[_queue addObjectsFromArray:savedQueue];
		NSLog(@"Loaded queue with %i items\n", [_queue count]);
	}
}
- (void)saveQueue {
	[NSKeyedArchiver archiveRootObject:_queue toFile:CACHE_FILE(@"queue.plist")];
}
- (void)update:(NSTimer *)timer {
	int networkType;
	[[NSUserDefaults standardUserDefaults] setObject:_sess forKey: @"session"];
	[[NSUserDefaults standardUserDefaults] setObject:_nowPlayingURL forKey: @"nowPlayingURL"];
	[[NSUserDefaults standardUserDefaults] setObject:_scrobbleURL forKey: @"scrobbleURL"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	if([(APP_CLASS *)[UIApplication sharedApplication].delegate hasWiFiConnection]) {
		networkType = 2;
	} else if([(APP_CLASS *)[UIApplication sharedApplication].delegate hasNetworkConnection:([_queue count] > 0)]) {
		networkType = 1;
	} else {
		networkType = 0;
	}
	
	if(networkType != _oldNetworkType && [(APP_CLASS *)[UIApplication sharedApplication].delegate hasNetworkConnection]) {
		NSLog(@"Network connection changed, handshaking\n");
		[self handshake];
	}
	if(_oldNetworkType>0 && networkType == 0) {
		NSLog(@"Lost network connection\n");
	}
	_oldNetworkType = networkType;
	
	if(_scrobblerState != SCROBBLER_SCROBBLING && _scrobblerState != SCROBBLER_NOWPLAYING && [(APP_CLASS *)[UIApplication sharedApplication].delegate isPlaying]) {
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
					[self nowPlayingTrack:[track objectForKey:@"title"] byArtist:[track objectForKey:@"creator"] onAlbum:[track objectForKey:@"album"] withDuration:[[track objectForKey:@"duration"] intValue]];
					_sentNowPlaying = TRUE;
				}
			} else {
				_sentNowPlaying = FALSE;
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
- (void)handshake {
	NSString *timestamp = [NSString stringWithFormat:@"%qu", (u_int64_t)[[NSDate date] timeIntervalSince1970]];
	NSString *auth = [[NSString stringWithFormat:@"%s%@", API_SECRET, timestamp] md5sum];
	NSString *authURL = [NSString stringWithFormat:@"http://post.audioscrobbler.com/?hs=true&p=1.2.1&c=%@&v=%@&u=%@&t=%@&a=%@&api_key=%s&sk=%@",
											 SCROBBLER_ID,
											 SCROBBLER_VERSION,
											 [[[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] lowercaseString] URLEscaped],
											 timestamp,
											 auth,
											 API_KEY,
											 [[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_session"]];

	NSURL *theURL = [NSURL URLWithString:authURL];
	NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:theURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:30];

	if(_connection) {
		return;
	}
	
	if([(APP_CLASS *)[UIApplication sharedApplication].delegate hasNetworkConnection]) {
		NSLog(@"Authenticating...\n");
		_scrobblerState = SCROBBLER_AUTHENTICATING;
		_connection=[[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
	}
	if (_connection) {
		_receivedData=[[NSMutableData alloc] init];
	} else {
		_scrobblerState = SCROBBLER_OFFLINE;
	}	
}
- (void)rateTrack:(NSString *)title byArtist:(NSString *)artist onAlbum:(NSString *)album withStartTime:(int)startTime withDuration:(int)duration fromSource:(NSString *)source rating:(NSString *)rating {
	for(NSMutableDictionary *track in _queue) {
		if([[track objectForKey:@"title"] isEqualToString:(title==nil)?@"":title] &&
			 [[track objectForKey:@"artist"] isEqualToString:(artist==nil)?@"":artist] &&
			 [[track objectForKey:@"album"] isEqualToString:(album==nil)?@"":album]) {
			[track setObject:rating forKey:@"rating"];
			return;
		}
	}
	//If we got here, there was no match. Queue it and repeat!
	if([self scrobbleTrack:title byArtist:artist onAlbum:album withStartTime:startTime withDuration:duration fromSource:source])
		[self rateTrack:title byArtist:artist onAlbum:album withStartTime:startTime withDuration:duration fromSource:source rating:rating];	
}
- (BOOL)scrobbleTrack:(NSString *)title byArtist:(NSString *)artist onAlbum:(NSString *)album withStartTime:(int)startTime withDuration:(int)duration fromSource:(NSString *)source {
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
- (void)doQueueTimer {
	if(_queueTimer == nil && _scrobblerState != SCROBBLER_OFFLINE) {
		_queueTimer = [NSTimer scheduledTimerWithTimeInterval:_queueTimerInterval
																								target:self
																							selector:@selector(flushQueue:)
																							userInfo:NULL
																							 repeats:NO];
		NSLog(@"Queue scheduled to be flushed in %i seconds\n", _queueTimerInterval);
		_queueTimerInterval *= 2;
		if(_queueTimerInterval < 60) {
			_queueTimerInterval = 60;
		} else if(_queueTimerInterval > 240) {
			_sess = nil;
		}
		if(_queueTimerInterval > 7200) _queueTimerInterval = 7200;
	}
}
- (void)nowPlayingTrack:(NSString *)title byArtist:(NSString *)artist onAlbum:(NSString *)album withDuration:(int)duration {
	if(_sess == nil || _connection) {
		return;
	}	
	
	NSMutableData *postData=[[NSMutableData alloc] init];
	[postData appendData:[[NSString stringWithFormat:@"s=%@",_sess] dataUsingEncoding:NSUTF8StringEncoding]];
	[postData appendData:[[NSString stringWithFormat:@"&a=%@&t=%@&b=%@&l=%i&n=&m=",
								[artist URLEscaped],
								[title URLEscaped],
								[album URLEscaped],
								(duration/1000)
								] dataUsingEncoding:NSUTF8StringEncoding]];

	NSLog(@"Sending currently playing track to %@", _nowPlayingURL);

	NSURL *theURL = [NSURL URLWithString:_nowPlayingURL];
	NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:theURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:30];
	
	[theRequest setHTTPMethod:@"POST"];
	[theRequest setHTTPBody:postData];
	[postData release];
	
	if([(APP_CLASS *)[UIApplication sharedApplication].delegate hasNetworkConnection]) {
		_scrobblerState = SCROBBLER_NOWPLAYING;
		_connection=[[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
	}	
	if (_connection) {
    _receivedData=[[NSMutableData alloc] init];
	}	
}
- (void)flushQueue:(NSTimer *)theTimer {
	NSEnumerator *enumerator = [_queue objectEnumerator];
	NSString *trackStr;
	int i=0;
	id track;
	
	if([_queue count] < 1)
		return;
	
	if(_connection) {
		_queueTimerInterval = 30;
		[self doQueueTimer];
		return;
	}	
	
	if(_queueTimer != nil) {
		[_queueTimer invalidate];
		_queueTimer = nil;
	}

	if(_sess == nil) {
		[self handshake];
		return;
	}	
	
	if(![(APP_CLASS *)[UIApplication sharedApplication].delegate hasNetworkConnection]) {
		_scrobblerState = SCROBBLER_OFFLINE;
		return;
	}
	
	NSMutableData *postData=[[NSMutableData alloc] init];
	[postData appendData:[[NSString stringWithFormat:@"s=%@",_sess] dataUsingEncoding:NSUTF8StringEncoding]];
	_submissionCount = 0;
	
	while((track = [enumerator nextObject]) && i < _maxSubmissionCount) {
		trackStr = [NSString stringWithFormat:@"&a[%i]=%@&t[%i]=%@&i[%i]=%@&o[%i]=%@&r[%i]=%@&l[%i]=%@&b[%i]=%@&n[%i]=&m[%i]=",
								i, [[track objectForKey:@"artist"] URLEscaped],
								i, [[track objectForKey:@"title"] URLEscaped],
								i, [track objectForKey:@"startTime"],
								i, [track objectForKey:@"source"] ? [track objectForKey:@"source"] : @"P",
								i, [track objectForKey:@"rating"] ? [track objectForKey:@"rating"] : @"",
								i, [track objectForKey:@"duration"],
								i, [[track objectForKey:@"album"] URLEscaped],
								i, i
								];
		[postData appendData:[trackStr dataUsingEncoding:NSUTF8StringEncoding]];
		i++;
	}
	_submissionCount = i;
	NSLog(@"Sending %i / %i tracks...\n", i, [_queue count]);

	NSURL *theURL = [NSURL URLWithString:_scrobbleURL];
	NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:theURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:30];
	
	[theRequest setHTTPMethod:@"POST"];
	[theRequest setHTTPBody:postData];
	[postData release];
	
	_connection=[[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
	if (_connection) {
		_scrobblerState = SCROBBLER_SCROBBLING;
    _receivedData=[[NSMutableData alloc] init];
	} else {
		[self doQueueTimer];
	}
}
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	NSString *theResponseString = [[NSString alloc] initWithData:_receivedData encoding:NSASCIIStringEncoding];
	NSArray *list = [theResponseString componentsSeparatedByString:@"\n"];
	int i;
	[_connection release];
	_connection = nil;
	[_receivedData release];
	_receivedData = nil;
	
	[_scrobblerResult release];	
	_scrobblerResult = [[list objectAtIndex: 0] retain];
	NSLog(@"Server response: %@\n", _scrobblerResult);
	
	switch(_scrobblerState) {
		case SCROBBLER_AUTHENTICATING:
			if([_scrobblerResult isEqualToString:@"OK"]) {
				[_sess release];
				_sess = [[list objectAtIndex: 1] retain];
				[_nowPlayingURL release];
				_nowPlayingURL = [[list objectAtIndex: 2] retain];
				[_scrobbleURL release];
				_scrobbleURL = [[list objectAtIndex: 3] retain];
				_scrobblerState = SCROBBLER_READY;
				NSLog(@"Authenticated. Session: %@\n", _sess);
				_queueTimerInterval = 5;
			} else {
				[_sess release];
				_sess = nil;
				[_nowPlayingURL release];
				_nowPlayingURL = nil;
				[_scrobbleURL release];
				_scrobbleURL = nil;
				_scrobblerState = SCROBBLER_OFFLINE;
			}
			break;
		case SCROBBLER_SCROBBLING:
			if([_scrobblerResult isEqualToString:@"OK"]) {
				NSLog(@"Scrobble succeeded!\n");
				_queueTimerInterval = 5;
				for(i=0; [_queue count] > 0 && i < _submissionCount; i++) {
					NSDictionary *track = [_queue objectAtIndex: 0];
					if([[track objectForKey:@"rating"] isEqualToString:@"L"]) {
						[[LastFMService sharedInstance] loveTrack:[track objectForKey:@"title"] byArtist:[track objectForKey:@"artist"]];
					}
					if([[track objectForKey:@"rating"] isEqualToString:@"B"]) {
						[[LastFMService sharedInstance] banTrack:[track objectForKey:@"title"] byArtist:[track objectForKey:@"artist"]];
					}
					[_queue removeObjectAtIndex:0];
					_totalScrobbled++;
				}
				_maxSubmissionCount = 50;
			} else {
				NSLog(@"Error: \"%@\"\n", _scrobblerResult);
				if([_scrobblerResult isEqualToString:@"BADSESSION"]) {
					[self handshake];
				} else {
					_maxSubmissionCount /= 4;
					if(_maxSubmissionCount < 1) _maxSubmissionCount = 1;
				}
			}
			[self saveQueue];
			break;
	}
	if(_scrobblerState != SCROBBLER_OFFLINE) {
		if(_scrobblerState != SCROBBLER_NOWPLAYING && [_queue count]) {
			_scrobblerState = SCROBBLER_READY;
			[self doQueueTimer];
		} else {
			_scrobblerState = SCROBBLER_READY;
		}
	}
	[theResponseString release];
}
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	[_receivedData setLength:0];
}
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	[_receivedData appendData:data];
}
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	// release the connection, and the data object
	[_connection release];
	_connection = nil;
	
	// receivedData is declared as a method instance elsewhere
	[_receivedData release];
	_receivedData = nil;
	
	// inform the user
	NSLog(@"Connection failed! Error - %@ %@",
				[error localizedDescription],
				[[error userInfo] objectForKey:NSErrorFailingURLStringKey]);
	
	_scrobblerResult = [error localizedDescription];
	
	if(_scrobblerState == SCROBBLER_SCROBBLING) {
		_scrobblerState = SCROBBLER_READY;
	} else {
		_scrobblerState = SCROBBLER_OFFLINE;
	}
	
	[self doQueueTimer];
}
- (void)cancelTimer {
	[_timer invalidate];
}
- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_sess release];
	[_nowPlayingURL release];
	[_scrobbleURL release];
	[_connection release];
	[_receivedData release];
	[_queue release];
	[_queueTimer release];
	[_scrobblerResult release];
	[super dealloc];
}
@end
