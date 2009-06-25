/* LastFMRadio.m - Stream music from Last.FM
 * 
 * Copyright 2009 Last.fm Ltd.
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
#import "LastFMRadio.h"
#import "LastFMService.h"
#import "NSString+MD5.h"
#import "NSString+URLEscaped.h"
#import "MobileLastFMApplicationDelegate.h"
#include "version.h"
#import "Beacon.h"

void interruptionListener(void *inClientData,	UInt32 inInterruptionState) {
	if(inInterruptionState == kAudioSessionBeginInterruption) {
		NSLog(@"interruption detected! stopping playback/recording\n");
		//the queue will stop itself on an interruption, we just need to update the AI
		[LastFMRadio sharedInstance].playbackWasInterrupted = YES;
		[[LastFMRadio sharedInstance] stop];
	}	else if ((inInterruptionState == kAudioSessionEndInterruption) && [LastFMRadio sharedInstance].playbackWasInterrupted) {
		// we were playing back when we were interrupted, so reset and resume now
		[[LastFMRadio sharedInstance] skip];
	}
}

static void AQBufferCallback(void *in, AudioQueueRef inQ, AudioQueueBufferRef outQB) {
	((LastFMTrack *)in).audioBufferDataSize = ((LastFMTrack *)in).audioBufferDataSize - outQB->mAudioDataByteSize;
	AudioQueueFreeBuffer(inQ, outQB);
	[(LastFMTrack *)in performSelectorOnMainThread:@selector(bufferDequeued) withObject:nil waitUntilDone:NO];
}

void packetCallback(void *in, UInt32 inNumberBytes, UInt32 inNumberPackets, const void *inInputData, AudioStreamPacketDescription *inPacketDescriptions) {
	LastFMTrack *track = in;
	AudioQueueBufferRef buf;
	
	OSStatus error = AudioQueueAllocateBufferWithPacketDescriptions(track.queue, inNumberBytes, inNumberPackets, &buf);
	if(error) {
		NSLog(@"Unable to allocate buffer, discarding packet");
	} else {
		buf->mAudioDataByteSize = inNumberBytes;
		memcpy(buf->mAudioData, inInputData, inNumberBytes);
		AudioQueueEnqueueBuffer(track.queue, buf, inNumberPackets, inPacketDescriptions);
		track.audioBufferDataSize = track.audioBufferDataSize + inNumberBytes;
		[track bufferEnqueued];
	}
}

void propCallback(void *in,	AudioFileStreamID inAudioFileStream, AudioFileStreamPropertyID inPropertyID, UInt32 *ioFlags) {
	LastFMTrack *track = in;
	AudioStreamBasicDescription dataFormat;
	AudioQueueRef queue;
	
	switch(inPropertyID) {
		case kAudioFileStreamProperty_DataFormat:
			NSLog(@"Got data format\n");
			UInt32 len = sizeof(dataFormat);
			AudioFileStreamGetProperty(inAudioFileStream, inPropertyID, &len, &dataFormat);
			track.dataFormat = dataFormat;
			break;
		case kAudioFileStreamProperty_ReadyToProducePackets:
			NSLog(@"Ready to produce packets (hi laurie!)\n");
			dataFormat = track.dataFormat;
			OSStatus error = AudioQueueNewOutput(&dataFormat, AQBufferCallback, track, NULL, kCFRunLoopCommonModes, 0, &queue);
			if(error) {
				NSLog(@"Unable to create audio queue!\n");
			} else {
				track.queue = queue;
			}
			[[NSNotificationCenter defaultCenter] postNotificationName:kTrackDidBecomeAvailable object:track];
			break;
	}
}

NSString *kTrackDidBecomeAvailable = @"LastFMRadio_TrackDidBecomeAvailable";
NSString *kTrackDidFinishLoading = @"LastFMRadio_TrackDidFinishLoading";
NSString *kTrackDidFinishPlaying = @"LastFMRadio_TrackDidFinishPlaying";
NSString *kTrackDidChange = @"LastFMRadio_TrackDidChange";
NSString *kTrackDidFailToStream = @"LastFMRadio_TrackDidFailToStream";

@implementation LastFMTrack

@synthesize parser, queue, dataFormat, audioBufferDataSize;

- (void)_prefetchSimilarArtists {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[[LastFMService sharedInstance] artistsSimilarTo:[_trackInfo objectForKey:@"creator"]];
	[pool release];
}	
- (void)_prefetchTags {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[[LastFMService sharedInstance] topTagsForTrack:[_trackInfo objectForKey:@"title"] byArtist:[_trackInfo objectForKey:@"creator"]];
	[pool release];
}	
- (void)_prefetchEvents {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[[LastFMService sharedInstance] eventsForUser:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]];
	[[LastFMService sharedInstance] eventsForArtist:[_trackInfo objectForKey:@"creator"]];
	[pool release];
}
- (void)_prefetchArtistBio {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[[LastFMService sharedInstance] metadataForArtist:[_trackInfo objectForKey:@"creator"] inLanguage:[[[NSUserDefaults standardUserDefaults] objectForKey: @"AppleLanguages"] objectAtIndex:0]];
	[pool release];
}	
- (void)_prefetchArtwork {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[_trackInfo retain];
	NSDictionary *albumData = [[LastFMService sharedInstance] metadataForAlbum:[_trackInfo objectForKey:@"album"] byArtist:[_trackInfo objectForKey:@"creator"] inLanguage:[[[NSUserDefaults standardUserDefaults] objectForKey: @"AppleLanguages"] objectAtIndex:0]];
	NSString *artworkURL = nil;
	
	if([[albumData objectForKey:@"image"] length]) {
		artworkURL = [NSString stringWithString:[albumData objectForKey:@"image"]];
	} else if([[_trackInfo objectForKey:@"image"] length]) {
		artworkURL = [NSString stringWithString:[_trackInfo objectForKey:@"image"]];
	}
	
	if(!artworkURL || [artworkURL isEqualToString:@"http://cdn.last.fm/depth/catalogue/noimage/cover_med.gif"] || [artworkURL isEqualToString:@"http://cdn.last.fm/depth/catalogue/noimage/cover_large.gif"]) {
		NSDictionary *artistData = [[LastFMService sharedInstance] metadataForArtist:[_trackInfo objectForKey:@"creator"] inLanguage:[[[NSUserDefaults standardUserDefaults] objectForKey: @"AppleLanguages"] objectAtIndex:0]];
		if([artistData objectForKey:@"image"])
			artworkURL = [NSString stringWithString:[artistData objectForKey:@"image"]];
	}

	if([artworkURL rangeOfString:@"amazon.com"].location != NSNotFound) {
		artworkURL = [artworkURL stringByReplacingOccurrencesOfString:@"MZZZ" withString:@"LZZZ"];
	}
	
	if(artworkURL && ![artworkURL isEqualToString:@"http://cdn.last.fm/depth/catalogue/noimage/cover_med.gif"] && ![artworkURL isEqualToString:@"http://cdn.last.fm/depth/catalogue/noimage/cover_large.gif"]) {
		[NSData dataWithContentsOfURL:[NSURL URLWithString: artworkURL]];
	}
	[_trackInfo release];
	[pool release];
}	

-(id)initWithTrackInfo:(NSDictionary *)trackInfo {
	if(self = [super init]) {
		_trackInfo = [trackInfo retain];
		_audioBufferCountLock = [[NSLock alloc] init];
		_bufferLock = [[NSLock alloc] init];
		NSURL *trackURL = [NSURL URLWithString:[_trackInfo objectForKey:@"location"]];
		NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:trackURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) hasWiFiConnection]?40:60];
		[theRequest setValue:kUserAgent forHTTPHeaderField:@"User-Agent"];

		_connection= [[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
		if(_connection) {
			_receivedData = [[NSMutableData alloc] init];
			_audioBufferCount = 0;
			_peakBufferCount = 0;
			_state = TRACK_BUFFERING;
			queue = nil;
			AudioFileStreamOpen(self, propCallback, packetCallback, kAudioFileMP3Type, &parser);
			[NSThread detachNewThreadSelector:@selector(_prefetchArtwork) toTarget:self withObject:nil];
			[NSThread detachNewThreadSelector:@selector(_prefetchArtistBio) toTarget:self withObject:nil];
			[NSThread detachNewThreadSelector:@selector(_prefetchSimilarArtists) toTarget:self withObject:nil];
			[NSThread detachNewThreadSelector:@selector(_prefetchTags) toTarget:self withObject:nil];
			[NSThread detachNewThreadSelector:@selector(_prefetchEvents) toTarget:self withObject:nil];
		} else {
			[self release];
			return nil;
		}
	}
	return self;
}
-(void)dealloc {
	if(queue) {
		AudioQueueFlush(queue);
		AudioQueueDispose(queue, true);
		AudioFileStreamClose(parser);
	}
	[_trackInfo release];
	[_connection release];
	[_receivedData release];
	[_audioBufferCountLock release];
	[_bufferLock release];
	[super dealloc];
}
-(void)_waitForPlaybackToFinish {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	UInt32 isRunning = 0;
	UInt32 size = sizeof(isRunning);
	
	@synchronized(self) {
		OSStatus error = AudioQueueGetProperty(queue, kAudioQueueProperty_IsRunning, &isRunning, &size);
		if(!error && isRunning && queue) {
			if(queue) {
				AudioQueueFlush(queue);
				AudioQueueStop(queue, false);
			}
			NSLog(@"Waiting for stream to finish\n");
			do {
				CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.25, false);
				error = AudioQueueGetProperty(queue, kAudioQueueProperty_IsRunning, &isRunning, &size);
			} while(!error && isRunning && queue);
			NSLog(@"Done!");
		}
		if([LastFMRadio sharedInstance].state == TRACK_PLAYING)
			[self performSelectorOnMainThread:@selector(_notifyTrackFinishedPlaying) withObject:nil waitUntilDone:NO];
	}
	[pool release];
}
-(void)_notifyTrackFinishedLoading {
	[[NSNotificationCenter defaultCenter] postNotificationName:kTrackDidFinishLoading object:self userInfo:nil];
}
-(void)_notifyTrackFinishedPlaying {
	[[NSNotificationCenter defaultCenter] postNotificationName:kTrackDidFinishPlaying object:self userInfo:nil];
}
-(void)_notifyTrackFailed {
	[[NSNotificationCenter defaultCenter] postNotificationName:kTrackDidFailToStream object:self userInfo:nil];
}
-(BOOL)play {
	if(queue) {
		_startTime = [[NSDate date] timeIntervalSince1970];
		UInt32 category = kAudioSessionCategory_MediaPlayback;
		AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(category), &category);
		AudioSessionSetActive(true);
		[LastFMRadio sharedInstance].playbackWasInterrupted = NO;
		if([[[NSUserDefaults standardUserDefaults] objectForKey:@"disableautolock"] isEqualToString:@"YES"])
			[UIApplication sharedApplication].idleTimerDisabled = YES;
	} else {
		_state = TRACK_BUFFERING;
		if(!_connection)
			[self connection:nil didReceiveData:nil];
	}
	return YES;
}
-(void)stop {
	if(queue) {
		@synchronized(self) {
			AudioQueueDispose(queue, true);
			AudioFileStreamClose(parser);
			queue = nil;
		}
	}
	[_connection cancel];
	[UIApplication sharedApplication].idleTimerDisabled = NO;
}
- (void)_pushDataChunk {
	NSData *extraData = nil;
	[_bufferLock lock];
	if([_receivedData length] > 16384) {
		extraData = [[NSData alloc] initWithBytes:[_receivedData bytes]+16384 length:[_receivedData length]-16384];
		[_receivedData setLength: 16384];
	}
	OSStatus error = AudioFileStreamParseBytes(parser, [_receivedData length], [_receivedData bytes], 0);
	if(error) {
		NSLog(@"Got an error pushing the data! :(");
	} else {
		[_receivedData setLength:0];
	}
	if(extraData) {
		[_receivedData appendData:extraData];
		[extraData release];
		extraData = nil;
	}
	[_bufferLock unlock];
}
-(void)bufferEnqueued {
	[_audioBufferCountLock lock];
	_audioBufferCount++;
	[_audioBufferCountLock unlock];
	if(_audioBufferCount > _peakBufferCount) _peakBufferCount = _audioBufferCount;
	if(_state == TRACK_BUFFERING) {
		NSLog(@"Starting queue");
		AudioQueueStart(queue, NULL);
		_state = TRACK_PLAYING;
	}
}
-(void)bufferDequeued {
	[_audioBufferCountLock lock];
	_audioBufferCount--;
	[_audioBufferCountLock unlock];	
	if(_state == TRACK_PLAYING && [_receivedData length] && _audioBufferCount < 32) {
		[self _pushDataChunk];
	}
	if(_state == TRACK_PLAYING && _peakBufferCount > 4) {
		if(_audioBufferCount < 1 && [_receivedData length] < 8192) {
			if(_fileDidFinishLoading) {
				[NSThread detachNewThreadSelector:@selector(_waitForPlaybackToFinish) toTarget:self withObject:nil];
			} else {
				[self pause];
				_state = TRACK_BUFFERING;
				NSLog(@"Buffer underrun detected, peak buffers this cycle was %i.\n", _peakBufferCount);
				_peakBufferCount = 0;
			}
		}
	}
}
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	[_connection release];
	_connection = nil;
	if([_receivedData length] == 0 && _state == TRACK_BUFFERING) {
		[self performSelectorOnMainThread:@selector(_notifyTrackFailed) withObject:self waitUntilDone:NO];
	} else {
		_fileDidFinishLoading = YES;
		if(_state != TRACK_PAUSED) {
			[self performSelectorOnMainThread:@selector(_notifyTrackFinishedLoading) withObject:self waitUntilDone:NO];
		}
	}
}
- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse {
	NSLog(@"Streaming: %@", [request URL]);
	return request;
}
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response {
	[_receivedData setLength:0];
	NSLog(@"HTTP status code: %i\n", [response statusCode]);
	if([response statusCode] != 200) {
		NSLog(@"HTTP headers: %@", [response allHeaderFields]);
		[[NSNotificationCenter defaultCenter] postNotificationName:kTrackDidFailToStream object:self userInfo:nil];
	}
}
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	if(data) {
		[_bufferLock lock];
		[_receivedData appendData:data];
		[_bufferLock unlock];
	}
	if(_state != TRACK_PAUSED && ([_receivedData length] > 98304 && _state == TRACK_BUFFERING) || _state == TRACK_PLAYING) {
		while(_audioBufferCount < 6 && [_receivedData length] > 8192)
			[self _pushDataChunk];
	}
}
-(void)pause {
	if(queue) {
		NSLog(@"Pausing audio queue");
		AudioQueuePause(queue);
	}
	_state = TRACK_PAUSED;
}
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	[[NSNotificationCenter defaultCenter] postNotificationName:kTrackDidFailToStream object:self userInfo:nil];
	NSLog(@"%@", error);
}
-(BOOL)isPlaying {
	UInt32 isRunning = 0;
	UInt32 size = sizeof(isRunning);
	
	OSStatus error = AudioQueueGetProperty(queue, kAudioQueueProperty_IsRunning, &isRunning, &size);
	if(!error)
		return isRunning;
	else
		return NO;
}
-(float)bufferProgress {
	if(_state == TRACK_BUFFERING && [_receivedData length] < 98304)
		return ((float)[_receivedData length]) / 98304.0f;
	else
		return 1;
}
-(NSTimeInterval)startTime {
	return _startTime;
}
-(int)state {
	return _state;
}
-(NSDictionary *)trackInfo {
	return [[_trackInfo copy] autorelease];
}
-(int)trackPosition {
	AudioTimeStamp t;
	Boolean b;
	
	if(!(_state == TRACK_PLAYING || _state == TRACK_BUFFERING) || AudioQueueGetCurrentTime(queue, NULL, &t, &b) < 0)
		return 0;
	else
		return t.mSampleTime / dataFormat.mSampleRate;
}
-(int)audioBufferCount {
	return _audioBufferCount;
}
-(int)httpBufferSize {
	return [_receivedData length];
}
@end


@implementation LastFMRadio

@synthesize playbackWasInterrupted;

+ (LastFMRadio *)sharedInstance {
  static LastFMRadio *sharedInstance;
	
  @synchronized(self) {
    if(!sharedInstance)
      sharedInstance = [[LastFMRadio alloc] init];
		
    return sharedInstance;
  }
	return nil;
}
-(LastFMTrack *)currentTrack {
	if([_tracks count])
		return [_tracks objectAtIndex:0];
	else
		return nil;
}
-(float)bufferProgress {
	if([_tracks count])
		return [[_tracks objectAtIndex:0] bufferProgress];
	else
		return 0;
}
-(NSTimeInterval)startTime {
	if([_tracks count])
		return [[_tracks objectAtIndex:0] startTime];
	else
		return 0;
}
-(NSDictionary *)trackInfo {
	if([_tracks count])
		return [[_tracks objectAtIndex:0] trackInfo];
	else
		return nil;
}
-(int)state {
	if([_tracks count])
		return [[_tracks objectAtIndex:0] state];
	else
		return RADIO_IDLE;
}
-(NSString *)station {
	if(_station)
		return [_station stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
	else
		return @"";
}
-(NSString *)stationURL {
	return _stationURL;
}
-(int)trackPosition {
	if([_tracks count])
		return [[_tracks objectAtIndex:0] trackPosition];
	else
		return 0;
}
-(id)init {
	self = [super init];
	
	_db = [[PLSqliteDatabase databaseWithPath:CACHE_FILE(@"recent.db")] retain];
	if (![_db open]) {
    NSLog(@"Could not open recent db.");
	}
	
	[_db executeUpdate:@"create table recent_radio (timestamp integer, url text, name text)", nil];
	
	_busyLock = [[NSLock alloc] init];
	_tracks = [[NSMutableArray alloc] init];
	AudioSessionInitialize(NULL, NULL, interruptionListener, self);
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidBecomeAvailable:) name:kTrackDidBecomeAvailable object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidFinishPlaying:) name:kTrackDidFinishPlaying object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidFinishLoading:) name:kTrackDidFinishLoading object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidFail:) name:kTrackDidFailToStream object:nil];
	return self;
}
-(void)_trackDidBecomeAvailable:(NSNotification *)notification {
	NSLog(@"Track did become available");
	if(notification.object == [_tracks objectAtIndex:0]) {
		[notification.object play];
		_errorSkipCounter = 0;
	}
}
-(void)_trackDidFinishPlaying:(NSNotification *)notification {
	NSLog(@"Track did finish playing");
	[_busyLock lock];
	//For some reason [_tracks removeObjectAtIndex:0] doesn't deallocate us properly, so we'll do it ourselves
	LastFMTrack *t = [[_tracks objectAtIndex: 0] retain];
	[_tracks removeObjectAtIndex:0];
	[t release];
	if([_tracks count]) {
		[[_tracks objectAtIndex:0] play];
		[[NSNotificationCenter defaultCenter] postNotificationName:kTrackDidChange object:self userInfo:[self trackInfo]];
	} else {
		[self play];
	}
	[_busyLock unlock];
}
-(void)_softSkip:(NSTimer *)timer {
	NSLog(@"Soft skipping to prebuffer next track");
	_softSkipTimer = nil;
	[_playlist removeObjectAtIndex:0];
	[self play];
	[[_tracks lastObject] pause];
}
-(void)_trackDidFinishLoading:(NSNotification *)notification {
	NSLog(@"Track did finish loading");
	[_busyLock lock];
	if(notification.object == [_tracks objectAtIndex:0]) {
		float duration = [[[notification.object trackInfo] objectForKey:@"duration"] floatValue]/1000.0f;
		float elapsed = [notification.object trackPosition];
		if(duration-elapsed < 30) {
			[self _softSkip:nil];
		} else {
			if(_softSkipTimer)
				[_softSkipTimer invalidate];
			_softSkipTimer = [NSTimer scheduledTimerWithTimeInterval:(duration-elapsed-30)
																												target:self
																											selector:@selector(_softSkip:)
																											userInfo:nil
																											 repeats:NO];
		}
	}
	[_busyLock unlock];
}
-(void)_trackDidFail:(NSNotification *)notification {
	NSLog(@"Track did fail");
	if(notification.object == [_tracks objectAtIndex:0]) {
		if(_errorSkipCounter++ > 3) {
			 [(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate displayError:NSLocalizedString(@"ERROR_PLAYBACK_FAILED", @"Playback failure error") withTitle:NSLocalizedString(@"ERROR_PLAYBACK_FAILED_TITLE", @"Playback failed error title")];
			 [self stop];
		 } else {
			 [_playlist release];
			 _playlist = nil;
			 [NSThread sleepForTimeInterval:2];
			 [self skip];
		 }
	}
	[_tracks removeObject:notification.object];
}
-(void)purgeRecentURLs {
	[_db executeUpdate:@"delete from recent_radio", nil];
}
-(void)removeRecentURL:(NSString *)url {
	[_db executeUpdate:@"delete from recent_radio where url = ?", url, nil];
}
-(NSArray *)recentURLs {
	NSMutableArray *URLs = [[NSMutableArray alloc] init];
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease]];
	[formatter setDateFormat:@"dd MMM yyyy, HH:mm"];
	PLSqliteResultSet *rs = (PLSqliteResultSet *)[_db executeQuery:@"select * from recent_radio order by timestamp desc limit 10",  nil];
	
	while([rs next]) {
		[URLs addObject:[NSDictionary dictionaryWithObjectsAndKeys:
										 [rs stringForColumn:@"url"], @"url",
										 [rs stringForColumn:@"name"], @"name",
										 [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:[rs intForColumn:@"timestamp"]]], @"date",
										 nil]];
	}
	[formatter release];
	return [URLs autorelease];
}
-(BOOL)selectStation:(NSString *)station {
	int x;
	NSDictionary *tune;
	[self removeRecentURL: station];
	NSLog(@"Selecting station: %@\n", station);
	NSLog(@"Network connection type: %@\n", [(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate hasWiFiConnection]?@"WiFi":@"EDGE");
	for(x=0; x<5; x++) {
		tune = [[LastFMService sharedInstance] tuneRadioStation:station];
		if((![LastFMService sharedInstance].error) || [LastFMService sharedInstance].error.code != 8 || [LastFMService sharedInstance].error.code != 16)
			break;
		else
			NSLog(@"Server busy, retrying...\n");
	}
	if([LastFMService sharedInstance].error) {
		[_playlist release];
		[_stationURL release];
		[_station release];
		_playlist = nil;
		_stationURL = nil;
		_station = nil;
	} else {
		[_playlist release];
		_playlist = nil;
		[_stationURL release];
		_stationURL = [station retain];
		[_station release];
		_station = [[tune objectForKey:@"name"] retain];
		_errorSkipCounter = 0;
		[_db executeUpdate:@"insert into recent_radio (timestamp, url, name) values (?, ?, ?)",
		 [NSString stringWithFormat:@"%qu", (u_int64_t)CFAbsoluteTimeGetCurrent()], _stationURL, [[_station stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"] capitalizedString], nil];
		if([_stationURL hasPrefix:@"lastfm://globaltags/"]) {
			_radioType = @"global tags";
		} else if([_stationURL hasPrefix:@"lastfm://usertags/"]) {
			_radioType = @"user tags";
		} else if([_stationURL hasPrefix:@"lastfm://artist/"]) {
			_radioType = @"artist";
		} else if([_stationURL hasSuffix:@"/personal"]) {
			_radioType = @"library";
		} else if([_stationURL hasSuffix:@"/recommended"]) {
			_radioType = @"recs";
		} else if([_stationURL hasSuffix:@"/neighbours"]) {
			_radioType = @"neighborhood";
		} else if([_stationURL hasSuffix:@"/loved"]) {
			_radioType = @"loved tracks";
		} else {
			_radioType = @"radio";
		}
		[[Beacon shared] startSubBeaconWithName:_radioType timeSession:YES];
		return TRUE;
	}
	return FALSE;
}
-(BOOL)play {
	int x;
	if(_softSkipTimer)
		[_softSkipTimer invalidate];
	_softSkipTimer = nil;
	
	if(!_playlist || [_playlist count] < 1 || _station == nil) {
		NSLog(@"Fetching playlist");
		for(x=0; x<10; x++) {
			NSDictionary *playlist = [[LastFMService sharedInstance] getPlaylist];
			if([[playlist objectForKey:@"playlist"] count]) {
				if(!_playlist) {
					_playlist = [[NSMutableArray alloc] initWithArray:[playlist objectForKey:@"playlist"]];
				} else {
					[_playlist addObjectsFromArray:[playlist objectForKey:@"playlist"]];
				}
				break;
			} else {
				if([LastFMService sharedInstance].error && [[LastFMService sharedInstance].error.domain isEqualToString:LastFMServiceErrorDomain] && !([LastFMService sharedInstance].error.code == 8 || [LastFMService sharedInstance].error.code == 16))
					break;
				else {
					NSLog(@"Server busy, retrying...\n");
					[NSThread sleepForTimeInterval:2];
				}
			}
		}
	}
	if(![_playlist count]) {
		[self removeRecentURL: _stationURL];
		if([LastFMService sharedInstance].error)
			[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate reportError:[LastFMService sharedInstance].error];
		else
			[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate displayError:NSLocalizedString(@"ERROR_INSUFFICIENT_CONTENT", @"Not enough content error") withTitle:NSLocalizedString(@"ERROR_INSUFFICIENT_CONTENT_TITLE", @"Not enough content title")];
		[[Beacon shared] startSubBeaconWithName:@"NEC error" timeSession:NO];
		[self stop];
		return FALSE;
	}

	LastFMTrack *track = [[[LastFMTrack alloc] initWithTrackInfo:[_playlist objectAtIndex:0]] autorelease];
	
	if(track) {
		[[UIApplication sharedApplication] setUsesBackgroundNetwork:YES];
		[_tracks addObject:track];
		if([_tracks count] == 1)
			[[NSNotificationCenter defaultCenter] postNotificationName:kTrackDidChange object:self userInfo:[self trackInfo]];
		return TRUE;
	} else {
		return FALSE;
	}
}
-(void)dealloc {
	if([_tracks count]) {
		[self stop];
	}
	[_tracks release];
	[_playlist release];
	[_busyLock release];
	[super dealloc];
}
-(void)stop {
	[_busyLock lock];
	[[Beacon shared] endSubBeaconWithName:_radioType];
	NSLog(@"Stopping playback\n");
	if([_tracks count]) {
		[[_tracks objectAtIndex: 0] stop];
		[_tracks removeAllObjects];
		AudioSessionSetActive(FALSE);
	}
	NSLog(@"Playback stopped");
	[[UIApplication sharedApplication] setUsesBackgroundNetwork:NO];
	[_busyLock unlock];
}
-(void)skip {
	[_busyLock lock];
	NSLog(@"Skipping to next track\n");
	if([_tracks count]) {
		[[_tracks objectAtIndex: 0] stop];
		[_tracks removeObjectAtIndex: 0];
	}
	if([_tracks count]) {
		[[_tracks objectAtIndex:0] play];
		[[NSNotificationCenter defaultCenter] postNotificationName:kTrackDidChange object:self userInfo:[self trackInfo]];
	} else {
		if([_playlist count])
			[_playlist removeObjectAtIndex:0];
		[self play];
	}
	[_busyLock unlock];
}
@end
