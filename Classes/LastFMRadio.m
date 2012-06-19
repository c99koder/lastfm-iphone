/* LastFMRadio.m - Stream music from Last.FM
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
#import <MediaPlayer/MediaPlayer.h>
#import "LastFMRadio.h"
#import "LastFMService.h"
#import "NSString+MD5.h"
#import "NSString+URLEscaped.h"
#import "MobileLastFMApplicationDelegate.h"
#include "version.h"
#if !(TARGET_IPHONE_SIMULATOR)
#import "FlurryAnalytics.h"
#endif

#define STARTING_BUFFER_SIZE 65392
#define MAX_AUDIO_BUFFERS 12
#define MAX_HTTP_BUFFER 2097152

void audioRouteChangeListenerCallback(void *inUserData, AudioSessionPropertyID inPropertyID, UInt32 inPropertyValueSize, const void *inPropertyValue) {
	if (inPropertyID != kAudioSessionProperty_AudioRouteChange)
		return;
	
	if ([[LastFMRadio sharedInstance] state] == RADIO_IDLE) {
		return;
	} else {
		CFDictionaryRef routeChangeDictionary = inPropertyValue;
		CFNumberRef routeChangeReasonRef = CFDictionaryGetValue(routeChangeDictionary, CFSTR(kAudioSession_AudioRouteChangeKey_Reason));
		
		SInt32 routeChangeReason;
		CFNumberGetValue(routeChangeReasonRef, kCFNumberSInt32Type, &routeChangeReason);
		
		if (routeChangeReason == kAudioSessionRouteChangeReason_OldDeviceUnavailable && [[[NSUserDefaults standardUserDefaults] objectForKey:@"headsetinterrupt"] isEqualToString:@"YES"]) {
			[[LastFMRadio sharedInstance] pause];
		}
	}
}

void interruptionListener(void *inClientData,	UInt32 inInterruptionState) {
	if(inInterruptionState == kAudioSessionBeginInterruption) {
		NSLog(@"interruption detected! stopping playback/recording\n");
		//the queue will stop itself on an interruption, we just need to update the AI
		if([[LastFMRadio sharedInstance] state] != TRACK_PAUSED) {
			[LastFMRadio sharedInstance].playbackWasInterrupted = YES;
			[[LastFMRadio sharedInstance] pause];
		}
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
            //Pump up the jam
            NSLog(@"Volume boost: %@", [[NSUserDefaults standardUserDefaults] objectForKey:@"volumeBoost"]);
            AudioQueueSetParameter(queue, kAudioQueueParam_Volume, [[[NSUserDefaults standardUserDefaults] objectForKey:@"volumeBoost"] floatValue]);
			[[NSNotificationCenter defaultCenter] postNotificationName:kTrackDidBecomeAvailable object:track];
			break;
	}
}

NSString *kTrackDidBecomeAvailable = @"LastFMRadio_TrackDidBecomeAvailable";
NSString *kArtworkDidBecomeAvailable = @"LastFMRadio_ArtworkDidBecomeAvailable";
NSString *kTrackDidFinishLoading = @"LastFMRadio_TrackDidFinishLoading";
NSString *kTrackDidFinishPlaying = @"LastFMRadio_TrackDidFinishPlaying";
NSString *kTrackDidChange = @"LastFMRadio_TrackDidChange";
NSString *kTrackDidFailToStream = @"LastFMRadio_TrackDidFailToStream";
NSString *kTrackDidPause = @"LastFMRadio_TrackDidPause";
NSString *kTrackDidResume = @"LastFMRadio_TrackDidResume";

@implementation LastFMTrack

@synthesize parser, queue, dataFormat, audioBufferDataSize;

-(id)initWithTrackInfo:(NSDictionary *)trackInfo {
	if(self = [super init]) {
		_trackInfo = [trackInfo retain];
		_audioBufferCountLock = [[NSLock alloc] init];
		_bufferLock = [[NSLock alloc] init];
        _artwork = nil;
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
            [NSThread detachNewThreadSelector:@selector(_fetchArtwork) toTarget:self withObject:nil];
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
#if !(TARGET_IPHONE_SIMULATOR)
	UIBackgroundTaskIdentifier bgTask = 0;
	UIDevice* device = [UIDevice currentDevice];
	BOOL backgroundSupported = NO;
	if ([device respondsToSelector:@selector(isMultitaskingSupported)]) {
		backgroundSupported = device.multitaskingSupported;
        bgTask = UIBackgroundTaskInvalid;
    }
	
	if(backgroundSupported && bgTask == UIBackgroundTaskInvalid) {
		bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
			[[UIApplication sharedApplication] endBackgroundTask:bgTask];
		}];
	}
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
		if(backgroundSupported && bgTask == UIBackgroundTaskInvalid) {
			[[UIApplication sharedApplication] endBackgroundTask:bgTask];
			bgTask = UIBackgroundTaskInvalid;
		}
	}
#else
	if(queue) {
		AudioQueueFlush(queue);
		AudioQueueStop(queue, false);
	}
	if([LastFMRadio sharedInstance].state == TRACK_PLAYING)
		[self performSelectorOnMainThread:@selector(_notifyTrackFinishedPlaying) withObject:nil waitUntilDone:NO];
#endif
	[pool release];
}
-(void)_notifyTrackFinishedLoading {
	[[NSNotificationCenter defaultCenter] postNotificationName:kTrackDidFinishLoading object:self userInfo:nil];
}
-(void)_notifyArtworkDidBecomeAvailable {
	[[NSNotificationCenter defaultCenter] postNotificationName:kArtworkDidBecomeAvailable object:self userInfo:nil];
    if([[LastFMRadio sharedInstance] currentTrack] == self && NSClassFromString(@"MPNowPlayingInfoCenter")) {
        if(_artwork != nil)
            [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                                                     [_trackInfo objectForKey:@"creator"],MPMediaItemPropertyArtist, 
                                                                     [_trackInfo objectForKey:@"title"],MPMediaItemPropertyTitle,
                                                                     [NSNumber numberWithFloat:[[_trackInfo objectForKey:@"duration"] floatValue] / 1000.0f],MPMediaItemPropertyPlaybackDuration,
                                                                     [_trackInfo objectForKey:@"album"],MPMediaItemPropertyAlbumTitle,
                                                                     [[[MPMediaItemArtwork alloc] initWithImage:_artwork] autorelease], MPMediaItemPropertyArtwork, 
                                                                     nil];
        else
            [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                                                     [_trackInfo objectForKey:@"creator"],MPMediaItemPropertyArtist, 
                                                                     [_trackInfo objectForKey:@"title"],MPMediaItemPropertyTitle,
                                                                     [NSNumber numberWithFloat:[[_trackInfo objectForKey:@"duration"] floatValue] / 1000.0f],MPMediaItemPropertyPlaybackDuration,
                                                                     [_trackInfo objectForKey:@"album"],MPMediaItemPropertyAlbumTitle,
                                                                     nil];
    }
}
-(void)_notifyTrackFinishedPlaying {
	[[NSNotificationCenter defaultCenter] postNotificationName:kTrackDidFinishPlaying object:self userInfo:nil];
}
-(void)_notifyTrackFailed {
	[[NSNotificationCenter defaultCenter] postNotificationName:kTrackDidFailToStream object:self userInfo:nil];
}
-(void)_notifyTrackPaused {
	[[NSNotificationCenter defaultCenter] postNotificationName:kTrackDidPause object:self userInfo:nil];
}
-(void)_notifyTrackResumed {
	[[NSNotificationCenter defaultCenter] postNotificationName:kTrackDidResume object:self userInfo:nil];
}
- (void)_pushDataChunk {
	NSData *extraData = nil;
	[_bufferLock lock];
	if([_receivedData length] > (8192*4)) {
		extraData = [[NSData alloc] initWithBytes:[_receivedData bytes]+(8192*4) length:[_receivedData length]-(8192*4)];
		[_receivedData setLength: (8192*4)];
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
		if(_fileDidFinishLoading)
			[self performSelectorOnMainThread:@selector(_notifyTrackFinishedLoading) withObject:self waitUntilDone:NO];
	}
}
-(void)bufferDequeued {
	[_audioBufferCountLock lock];
	_audioBufferCount--;
	[_audioBufferCountLock unlock];	
	if(_state == TRACK_PLAYING && [_receivedData length] && (_audioBufferCount < MAX_AUDIO_BUFFERS || [_receivedData length] > MAX_HTTP_BUFFER)) {
		[self _pushDataChunk];
	}
	if(_state == TRACK_PLAYING && _peakBufferCount > 4) {
		if(_audioBufferCount < 1 && [_receivedData length] < 16384) {
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
- (void)_fetchArtwork {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSDictionary *albumData = [[LastFMService sharedInstance] metadataForAlbum:[_trackInfo objectForKey:@"album"] byArtist:[_trackInfo objectForKey:@"creator"] inLanguage:[[[NSUserDefaults standardUserDefaults] objectForKey: @"AppleLanguages"] objectAtIndex:0]];
	NSString *artworkURL = nil;
	UIImage *artworkImage;
	
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
	
	if(artworkURL && [artworkURL rangeOfString:@"amazon.com"].location != NSNotFound) {
		artworkURL = [artworkURL stringByReplacingOccurrencesOfString:@"MZZZ" withString:@"LZZZ"];
	}
	
	NSLog(@"Loading artwork: %@\n", artworkURL);
	[UIView beginAnimations:nil context:nil];
	[_artwork release];
	_artwork = [[UIImage imageNamed:@"noartplaceholder.png"] retain];
	[UIView commitAnimations];
	if(artworkURL && ![artworkURL isEqualToString:@"http://cdn.last.fm/depth/catalogue/noimage/cover_med.gif"] && ![artworkURL isEqualToString:@"http://cdn.last.fm/depth/catalogue/noimage/cover_large.gif"]) {
        NSData *imageData = [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString: artworkURL]];
		artworkImage = [[UIImage alloc] initWithData:imageData];
		[imageData release];
	} else {
		artworkImage = nil;
	}
		
	[_artwork release];
	_artwork = artworkImage;
	[self performSelectorOnMainThread:@selector(_notifyArtworkDidBecomeAvailable) withObject:self waitUntilDone:NO];
	[pool release];
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
	if(_state != TRACK_PAUSED && (([_receivedData length] > STARTING_BUFFER_SIZE && _state == TRACK_BUFFERING) || _state == TRACK_PLAYING)) {
		while(_audioBufferCount < 3) {
			[self _pushDataChunk];
		}
	}
}
-(BOOL)play {
    if(NSClassFromString(@"MPNowPlayingInfoCenter")) {
        if(_artwork != nil)
            [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                                                 [_trackInfo objectForKey:@"creator"],MPMediaItemPropertyArtist, 
                                                                 [_trackInfo objectForKey:@"title"],MPMediaItemPropertyTitle,
                                                                 [NSNumber numberWithFloat:[[_trackInfo objectForKey:@"duration"] floatValue] / 1000.0f],MPMediaItemPropertyPlaybackDuration,
                                                                 [_trackInfo objectForKey:@"album"],MPMediaItemPropertyAlbumTitle,
                                                                     [[[MPMediaItemArtwork alloc] initWithImage:_artwork] autorelease], MPMediaItemPropertyArtwork, 
                                                                     nil];
        else
            [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                                                     [_trackInfo objectForKey:@"creator"],MPMediaItemPropertyArtist, 
                                                                     [_trackInfo objectForKey:@"title"],MPMediaItemPropertyTitle,
                                                                     [NSNumber numberWithFloat:[[_trackInfo objectForKey:@"duration"] floatValue] / 1000.0f],MPMediaItemPropertyPlaybackDuration,
                                                                     [_trackInfo objectForKey:@"album"],MPMediaItemPropertyAlbumTitle,
                                                                     nil];
    }
	if(queue) {
		_startTime = [[NSDate date] timeIntervalSince1970];
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
	[_receivedData setLength:0];
	[UIApplication sharedApplication].idleTimerDisabled = NO;
}
-(void)pause {
	if(queue) {
		NSLog(@"Pausing audio queue");
		AudioQueuePause(queue);
	}
	_state = TRACK_PAUSED;
#if !(TARGET_IPHONE_SIMULATOR)
	[FlurryAnalytics logEvent:@"pause"];
#endif
	[self performSelectorOnMainThread:@selector(_notifyTrackPaused) withObject:nil waitUntilDone:NO];
}
-(void)resume {
	if(_state == TRACK_PAUSED) {
		NSLog(@"Resuming queue");
		if(_receivedData == nil) {
			_receivedData = [[NSMutableData alloc] initWithContentsOfFile:CACHE_FILE(@"trackdata")];
		}
		AudioQueueStart(queue, NULL);
		_state = TRACK_PLAYING;
#if !(TARGET_IPHONE_SIMULATOR)
		[FlurryAnalytics logEvent:@"resume"];
#endif
	}
	[self performSelectorOnMainThread:@selector(_notifyTrackResumed) withObject:nil waitUntilDone:NO];
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
	if(_state == TRACK_BUFFERING && [_receivedData length] < STARTING_BUFFER_SIZE)
		return ((float)[_receivedData length]) / (float)STARTING_BUFFER_SIZE;
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
	
	if(!(_state == TRACK_PLAYING || _state == TRACK_BUFFERING || _state == TRACK_PAUSED) || AudioQueueGetCurrentTime(queue, NULL, &t, &b) < 0)
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
-(BOOL)didFinishLoading {
	return _fileDidFinishLoading;
}
-(BOOL)lowOnMemory {
	if(_fileDidFinishLoading) {
		[_receivedData writeToFile:CACHE_FILE(@"trackdata") atomically:YES];
		[_receivedData release];
		_receivedData = nil;
		return YES;
	} else {
		return NO;
	}
}
-(UIImage *)artwork {
    return _artwork;
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
-(UIImage *)artwork {
	if([_tracks count])
		return [[_tracks objectAtIndex:0] artwork];
	else
		return nil;
}
-(NSDictionary *)trackInfo {
	if([_tracks count])
		return [[_tracks objectAtIndex:0] trackInfo];
	else
		return nil;
}
-(int)state {
	if([_tracks count])
		return [(LastFMTrack *)[_tracks objectAtIndex:0] state];
	else if(tuning)
		return RADIO_TUNING;
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
	
	[_db executeUpdate:@"create table if not exists recent_radio (timestamp integer, url text, name text)", nil];
	
	_busyLock = [[NSLock alloc] init];
	_tracks = [[NSMutableArray alloc] init];
	softskipping = NO;
	UIDevice* device = [UIDevice currentDevice];
	BOOL backgroundSupported = NO;
	if ([device respondsToSelector:@selector(isMultitaskingSupported)])
		backgroundSupported = device.multitaskingSupported;
	
	if(backgroundSupported && bgTask == UIBackgroundTaskInvalid) {
		bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
			[[UIApplication sharedApplication] endBackgroundTask:bgTask];
			bgTask = UIBackgroundTaskInvalid;
		}];
	}
	if(backgroundSupported)
		bgTask = UIBackgroundTaskInvalid;
	AudioSessionInitialize(NULL, NULL, interruptionListener, self);
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidBecomeAvailable:) name:kTrackDidBecomeAvailable object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidFinishPlaying:) name:kTrackDidFinishPlaying object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidFinishLoading:) name:kTrackDidFinishLoading object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidResume:) name:kTrackDidResume object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidFail:) name:kTrackDidFailToStream object:nil];
	return self;
}
-(void)_trackDidBecomeAvailable:(NSNotification *)notification {
	NSLog(@"Track did become available");
	if(notification.object == [_tracks objectAtIndex:0]) {
		UIDevice* device = [UIDevice currentDevice];
		BOOL backgroundSupported = NO;
		if ([device respondsToSelector:@selector(isMultitaskingSupported)])
			backgroundSupported = device.multitaskingSupported;
		if(backgroundSupported && bgTask != UIBackgroundTaskInvalid) {
			[[UIApplication sharedApplication] endBackgroundTask:bgTask];
			bgTask = UIBackgroundTaskInvalid;
		}
		[(LastFMTrack *)notification.object play];
		_errorSkipCounter = 0;
		if([[[NSUserDefaults standardUserDefaults] objectForKey:@"trial_enabled"] isEqualToString:@"1"]) {
			if([[[NSUserDefaults standardUserDefaults] objectForKey:@"trial_playsleft"] intValue] <= 5 && ![[[NSUserDefaults standardUserDefaults] objectForKey:@"trial_almost_over_warning"] isEqualToString:@"1"]) {
				[[NSUserDefaults standardUserDefaults] setObject:@"1" forKey:@"trial_almost_over_warning"];
				[[NSUserDefaults standardUserDefaults] synchronize];
				UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"Free Trial Almost Over" message:[NSString stringWithFormat:@"You have just %@ tracks left of your free trial. Learn more about your Last.fm subscription at http://last.fm/subscribe.", [[NSUserDefaults standardUserDefaults] objectForKey:@"trial_playsleft"]] delegate:[UIApplication sharedApplication].delegate cancelButtonTitle:NSLocalizedString(@"OK", @"OK") otherButtonTitles:nil] autorelease];
				[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:YES];
			}
		}
		if(backgroundSupported && bgTask == UIBackgroundTaskInvalid) {
			[[UIApplication sharedApplication] endBackgroundTask:bgTask];
			bgTask = UIBackgroundTaskInvalid;
		}
	}
}
-(void)_trackDidFinishPlaying:(NSNotification *)notification {
	NSLog(@"Track did finish playing");
	if([[[NSUserDefaults standardUserDefaults] objectForKey:@"trial_enabled"] isEqualToString:@"1"]) {
		int playsleft = [[[NSUserDefaults standardUserDefaults] objectForKey:@"trial_playsleft"] intValue];
		if(playsleft == 0) {
			[[NSUserDefaults standardUserDefaults] setObject:@"1" forKey:@"trial_expired"];
			[[NSUserDefaults standardUserDefaults] synchronize];
			UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"Your Free Trial Is Over" message:
														 [NSString stringWithFormat:@"Your free trial of Last.fm radio is over.  Subscribe now to get personalized radio on your %@ at http://last.fm/subscribe", [UIDevice currentDevice].model]
																											delegate:[UIApplication sharedApplication].delegate cancelButtonTitle:@"Ok" otherButtonTitles:nil] autorelease];
			[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:YES];
			[self stop];
			return;
		}
	}
	[_busyLock lock];
	if([_tracks count])
		[_tracks removeObjectAtIndex:0];
	[_busyLock unlock];
	if([_tracks count]) {
		[(LastFMTrack *)[_tracks objectAtIndex:0] play];
		[[NSNotificationCenter defaultCenter] postNotificationName:kTrackDidChange object:self userInfo:[self trackInfo]];
		prebuffering = NO;
	} else {
		[self play];
	}
}
-(void)_softSkip:(NSTimer *)timer {
	NSLog(@"Soft skipping to prebuffer next track");
	softskipping = YES;
	_softSkipTimer = nil;
	if([_playlist count])
		[_playlist removeObjectAtIndex:0];
	if([self play]) {
		[[_tracks lastObject] pause];
		prebuffering = YES;
	}
	softskipping = NO;
}
-(BOOL)cancelPrebuffering {
	[_softSkipTimer invalidate];
	_softSkipTimer = nil;
	if(prebuffering && [_tracks count] > 1) {
		[[_tracks objectAtIndex: 1] stop];
		[_tracks removeObjectAtIndex:1];
		prebuffering = NO;
		return YES;
	} else {
		return NO;
	}
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
	if([notification.name isEqualToString:kTrackDidFinishLoading] && [[[NSUserDefaults standardUserDefaults] objectForKey:@"trial_enabled"] isEqualToString:@"1"]) {
		int playsleft = [[[NSUserDefaults standardUserDefaults] objectForKey:@"trial_playsleft"] intValue];
		if(playsleft > 0) {
			playsleft--;
			[[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithFormat:@"%i", playsleft] forKey:@"trial_playsleft"];
			[[NSUserDefaults standardUserDefaults] synchronize];
		}
	}
	[_busyLock unlock];
}
-(void)_trackDidResume:(NSNotification *)notification {
	if(notification.object == [_tracks objectAtIndex:0] && [[_tracks objectAtIndex:0] didFinishLoading])
		[self _trackDidFinishLoading:notification];
}
-(void)_trackDidFail:(NSNotification *)notification {
	NSLog(@"Track did fail");
	if([_tracks count]) {
		if(notification.object == [_tracks objectAtIndex:0]) {
			if(_errorSkipCounter++ > 3) {
				 [(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate displayError:NSLocalizedString(@"ERROR_PLAYBACK_FAILED", @"Playback failure error") withTitle:NSLocalizedString(@"ERROR_PLAYBACK_FAILED_TITLE", @"Playback failed error title")];
				 [self stop];
			 } else if([(LastFMTrack *)[_tracks objectAtIndex:0] state] == TRACK_PAUSED) {
				 [self stop];
			 } else {
				 tuning = YES;
				 [_tracks removeAllObjects];
				 [_playlist release];
				 _playlist = nil;
				 [self skip];
			 }
		}
		[_tracks removeObject:notification.object];
	}
}
-(void)purgeRecentURLs {
	[_db close];
	[_db release];
	_db = nil;
	
	[[NSFileManager defaultManager] removeItemAtPath:CACHE_FILE(@"recent.db") error:nil];
	
	_db = [[PLSqliteDatabase databaseWithPath:CACHE_FILE(@"recent.db")] retain];
	if (![_db open]) {
		NSLog(@"Could not open recent db.");
	}
	
	[_db executeUpdate:@"create table if not exists recent_radio (timestamp integer, url text, name text)", nil];
}
-(void)removeRecentURL:(NSString *)url {
	[_db executeUpdate:@"delete from recent_radio where url = ?", url, nil];
}
-(NSArray *)recentURLs {
	NSMutableArray *URLs = [[NSMutableArray alloc] init];
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease]];
	[formatter setDateFormat:@"dd MMM yyyy, HH:mm"];
	
	@try {
		PLSqliteResultSet *rs = (PLSqliteResultSet *)[_db executeQuery:@"select * from recent_radio order by timestamp desc limit 10",  nil];
		
		while([rs next]) {
			NSString *url = [rs stringForColumn:@"url"];
			
			if([url hasSuffix:@"/loved"] && [[[NSUserDefaults standardUserDefaults] objectForKey:@"removeLovedTracks"] isEqualToString:@"YES"])
				continue;
			
			if([url hasPrefix:@"lastfm://playlist/"] && [[[NSUserDefaults standardUserDefaults] objectForKey:@"removePlaylists"] isEqualToString:@"YES"])
				continue;

			if([url hasPrefix:@"lastfm://usertags/"] && [[[NSUserDefaults standardUserDefaults] objectForKey:@"removeUserTags"] isEqualToString:@"YES"])
				continue;

			[URLs addObject:[NSDictionary dictionaryWithObjectsAndKeys:
											 [rs stringForColumn:@"url"], @"url",
											 [rs stringForColumn:@"name"], @"name",
											 [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:[rs intForColumn:@"timestamp"]]], @"date",
											 nil]];
		}
		[formatter release];
		return [URLs autorelease];
	} @catch(NSException *e) {
		NSLog(@"Problem with the station db (%@), re-creating...", [e description]);
		_db = nil;
		
		[[NSFileManager defaultManager] removeItemAtPath:CACHE_FILE(@"recent.db") error:nil];

		_db = [[PLSqliteDatabase databaseWithPath:CACHE_FILE(@"recent.db")] retain];
		if (![_db open]) {
			NSLog(@"Could not open recent db.");
		}
		
		[_db executeUpdate:@"create table if not exists recent_radio (timestamp integer, url text, name text)", nil];
		return nil;
	}
}
-(void)fetchRecentURLs {
	NSArray *stations = [[LastFMService sharedInstance] recentStationsForUser:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]];
	if([stations count]) {
		int i = 0;
		[self purgeRecentURLs];
		for(NSDictionary *station in stations) {
			[_db executeUpdate:@"insert into recent_radio (timestamp, url, name) values (?, ?, ?)",
			 [NSString stringWithFormat:@"%qu", (u_int64_t)CFAbsoluteTimeGetCurrent() - i++], [station objectForKey:@"url"], [station objectForKey:@"name"], nil];
		}
	}
}
-(NSArray *)suggestions {
	return _suggestions;
}
-(BOOL)selectStation:(NSString *)station {
	NSDictionary *tune;
	[self removeRecentURL: station];
	[self cancelPrebuffering];
	NSLog(@"Selecting station: %@\n", station);
	NSLog(@"Network connection type: %@\n", [(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate hasWiFiConnection]?@"WiFi":@"EDGE");
	tune = [[LastFMService sharedInstance] tuneRadioStation:station];
	if(!tune || [LastFMService sharedInstance].error) {
		return FALSE;
	} else {
		[_suggestions release];
		NSRange range = [station rangeOfString:@"/tag/"];
		if(range.location != NSNotFound) {
			NSString *url = [station substringToIndex:range.location];
			_suggestions = [[[LastFMService sharedInstance] suggestedTagsForStation:url] retain];
		} else {
			_suggestions = [[[LastFMService sharedInstance] suggestedTagsForStation:station] retain];
		}
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
		} else if([_stationURL hasSuffix:@"/mix"]) {
			_radioType = @"mix";
		} else {
			_radioType = @"radio";
		}
		tuning = YES;
#if !(TARGET_IPHONE_SIMULATOR)
		[FlurryAnalytics logEvent:_radioType timed:YES];
#endif
		return TRUE;
	}
	return FALSE;
}
-(BOOL)play {
	int x;
	if(_softSkipTimer)
		[_softSkipTimer invalidate];
	_softSkipTimer = nil;
	
	if([_tracks count] && [(LastFMTrack *)[_tracks objectAtIndex:0] state] == TRACK_PAUSED) {
		[[_tracks objectAtIndex:0] resume];
		NSLog(@"Playback resumed");
		return YES;
	}
	
	if([_playlistExpiration compare:[NSDate date]] == NSOrderedAscending) {
		NSLog(@"Playlist has expired!");
		tuning = YES;
		[_playlist release];
		_playlist = nil;
		if([_tracks count] > 1)
			[_tracks removeObjectAtIndex:1];
	}
	
	if(!_playlist || [_playlist count] < 1 || _station == nil) {
		NSLog(@"Fetching playlist");
		for(x=0; x<2; x++) {
			NSDictionary *playlist = [[LastFMService sharedInstance] getPlaylist];
			if([[playlist objectForKey:@"playlist"] count]) {
				NSLog(@"Playlist expires in %@ seconds", [playlist objectForKey:@"expiry"]);
				[_playlistExpiration release];
				_playlistExpiration = [[NSDate dateWithTimeIntervalSinceNow:[[playlist objectForKey:@"expiry"] intValue]] retain];
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
		if(!softskipping) {
			[self removeRecentURL: _stationURL];
			if([LastFMService sharedInstance].error)
				[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate reportError:[LastFMService sharedInstance].error];
			else
				[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate displayError:NSLocalizedString(@"ERROR_INSUFFICIENT_CONTENT", @"Not enough content error") withTitle:NSLocalizedString(@"ERROR_INSUFFICIENT_CONTENT_TITLE", @"Not enough content title")];
#if !(TARGET_IPHONE_SIMULATOR)
			[FlurryAnalytics logEvent:@"NEC error"];
#endif
			[self stop];
		}
		return FALSE;
	}

	LastFMTrack *track = [[[LastFMTrack alloc] initWithTrackInfo:[_playlist objectAtIndex:0]] autorelease];
	
	if(track) {
		AudioSessionSetActive(true);
		UInt32 category = kAudioSessionCategory_MediaPlayback;
		AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(category), &category);
		AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange,audioRouteChangeListenerCallback,nil);
		if( [[UIApplication sharedApplication] respondsToSelector: @selector(beginReceivingRemoteControlEvents)] )
			[[UIApplication sharedApplication] beginReceivingRemoteControlEvents];

		[_tracks addObject:track];
		if([_tracks count] == 1)
			[[NSNotificationCenter defaultCenter] postNotificationName:kTrackDidChange object:self userInfo:[self trackInfo]];
		prebuffering = NO;
		tuning = NO;
		return TRUE;
	} else {
		return FALSE;
	}
}
-(void)dealloc {
	if([_tracks count]) {
		[self stop];
	}
	[_playlistExpiration release];
	[_tracks release];
	[_playlist release];
	[_busyLock release];
	[super dealloc];
}
-(void)pause {
	[_busyLock lock];
	if([_tracks count]) {
		[[_tracks objectAtIndex: 0] pause];
	}
	[self cancelPrebuffering];
	NSLog(@"Playback paused");
	[_busyLock unlock];
}
-(void)stop {
	[_busyLock lock];
#if !(TARGET_IPHONE_SIMULATOR)
	[FlurryAnalytics endTimedEvent:_radioType withParameters:nil];
#endif
	NSLog(@"Stopping playback\n");
	if([_tracks count]) {
		[[_tracks objectAtIndex: 0] stop];
		[_tracks removeAllObjects];
		AudioSessionSetActive(FALSE);
	}
	tuning = NO;
	prebuffering = NO;
	[_softSkipTimer invalidate];
	_softSkipTimer = nil;
    if(NSClassFromString(@"MPNowPlayingInfoCenter")) {
        [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nil;
    }
	NSLog(@"Playback stopped");
	[_busyLock unlock];
}
-(void)skip {
	UIDevice* device = [UIDevice currentDevice];
	BOOL backgroundSupported = NO;
	if ([device respondsToSelector:@selector(isMultitaskingSupported)])
		backgroundSupported = device.multitaskingSupported;
	
	if(backgroundSupported && bgTask == UIBackgroundTaskInvalid) {
		bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
			[[UIApplication sharedApplication] endBackgroundTask:bgTask];
			bgTask = UIBackgroundTaskInvalid;
		}];
	}
	[_busyLock lock];
	NSLog(@"Skipping to next track\n");
	if([_tracks count]) {
		[[_tracks objectAtIndex: 0] stop];
		[_tracks removeObjectAtIndex: 0];
	}
	if([_tracks count] && [_playlistExpiration compare:[NSDate date]] == NSOrderedDescending) {
		[(LastFMTrack *)[_tracks objectAtIndex:0] play];
		[[NSNotificationCenter defaultCenter] postNotificationName:kTrackDidChange object:self userInfo:[self trackInfo]];
	} else {
		if([_playlist count])
			[_playlist removeObjectAtIndex:0];
		[_busyLock unlock];
		[self play];
		[_busyLock lock];
	}
	[_softSkipTimer invalidate];
	_softSkipTimer = nil;
	[_busyLock unlock];
	if(backgroundSupported && bgTask == UIBackgroundTaskInvalid) {
		[[UIApplication sharedApplication] endBackgroundTask:bgTask];
		bgTask = UIBackgroundTaskInvalid;
	}
}
-(void)lowOnMemory {
	if([self cancelPrebuffering])
		NSLog(@"Cancelled prebuffering due to low memory");
	if([self state] == TRACK_PAUSED) {
		if([_tracks count]) {
			if([(LastFMTrack *)[_tracks objectAtIndex: 0] lowOnMemory]) {
				NSLog(@"Caching paused track data");
			} else {
				NSLog(@"Unable to cache paused data, stopping...");
				[self stop];
			}
		}
	}
}
@end
