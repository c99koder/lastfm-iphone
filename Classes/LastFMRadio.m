/* LastFMRadio.m - Stream music from Last.FM
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

#import <Foundation/NSCharacterSet.h>
#import "LastFMRadio.h"
#import "LastFMService.h"
#import "NSString+MD5.h"
#import "NSString+URLEscaped.h"
#import "MobileLastFMApplicationDelegate.h"
#include "version.h"

@interface SystemNowPlayingController : NSObject
{
	int _disableHUDCount;
	BOOL _notifyEnableSystemHUDLastPostedState;
	int _notifyDisableSystemHUDToken;
}

+ (id)sharedInstance;
- (id)init;
- (id)_init;
- (void)dealloc;
- (void)_setEnableSBMediaHUD:(BOOL)fp8;
- (void)disableMediaHUD;
- (void)enableMediaHUD;
- (void)_postCurrentMedia:(BOOL)fp8 path:(id)fp12 title:(id)fp16 artist:(id)fp20 album:(id)fp24 isPlaying:(BOOL)fp28 playingToTVOut:(BOOL)fp32 hasImageData:(BOOL)fp36 additionalInfo:(id)fp40;
- (void)postNowPlayingInfoForMovieWithTitle:(id)fp8 artist:(id)fp12 album:(id)fp16 isPlaying:(BOOL)fp20 playingToTVOut:(BOOL)fp24;
- (void)postNowPlayingInfoForSongWithPath:(id)fp8 title:(id)fp12 artist:(id)fp16 album:(id)fp20 isPlaying:(BOOL)fp24 hasImageData:(BOOL)fp28 additionalInfo:(id)fp32;

@end

void interruptionListener(void *inClientData,	UInt32 inInterruptionState) {
	if(inInterruptionState == kAudioSessionBeginInterruption) {
		NSLog(@"interruption detected! stopping playback/recording\n");
		//the queue will stop itself on an interruption, we just need to update the AI
		[[LastFMRadio sharedInstance] stop];
		[LastFMRadio sharedInstance].playbackWasInterrupted = YES;
	}	else if ((inInterruptionState == kAudioSessionEndInterruption) && [LastFMRadio sharedInstance].playbackWasInterrupted) {
		// we were playing back when we were interrupted, so reset and resume now
		[[LastFMRadio sharedInstance] play];
	}
}

static void AQBufferCallback(void *in, AudioQueueRef inQ, AudioQueueBufferRef outQB) {
	AudioQueueFreeBuffer(inQ, outQB);
	[(LastFMTrack *)in performSelectorOnMainThread:@selector(bufferDequeued) withObject:nil waitUntilDone:NO];
}

void packetCallback(void *in, UInt32 inNumberBytes, UInt32 inNumberPackets, const void *inInputData, AudioStreamPacketDescription *inPacketDescriptions) {
	LastFMTrack *track = in;
	AudioQueueBufferRef buf;
	
	AudioQueueAllocateBufferWithPacketDescriptions(track.queue, inNumberBytes, inNumberPackets, &buf);
	buf->mAudioDataByteSize = inNumberBytes;
	memcpy(buf->mAudioData, inInputData, inNumberBytes);
	AudioQueueEnqueueBuffer(track.queue, buf, inNumberPackets, inPacketDescriptions);
	[track bufferEnqueued];
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
			NSLog(@"Ready to produce packets\n");
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

@synthesize parser, queue, dataFormat;

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
		} else {
			[self release];
			return nil;
		}
	}
	return self;
}
-(void)dealloc {
	if(queue) {
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
-(void)_notifyTrackChange {
	[[NSNotificationCenter defaultCenter] postNotificationName:kTrackDidChange object:self userInfo:_trackInfo];
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
	OSStatus error;
	
	if(queue) {
		NSLog(@"Starting playback");
		error = AudioQueueStart(queue, NULL);
		if(error)
			return NO;
		_startTime = [[NSDate date] timeIntervalSince1970];
		UInt32 category = kAudioSessionCategory_MediaPlayback;
		AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(category), &category);
		AudioSessionSetActive(true);
		[LastFMRadio sharedInstance].playbackWasInterrupted = NO;
		[[SystemNowPlayingController sharedInstance] postNowPlayingInfoForSongWithPath:nil
																																						 title:[_trackInfo objectForKey:@"title"]
																																						artist:[_trackInfo objectForKey:@"creator"]
																																						 album:[_trackInfo objectForKey:@"album"]
																																				 isPlaying:YES
																																			hasImageData:NO
																																		additionalInfo:nil];
		[[SystemNowPlayingController sharedInstance] disableMediaHUD];
		[[UIApplication sharedApplication] setUsesBackgroundNetwork:YES];
		[UIApplication sharedApplication].idleTimerDisabled = YES;
		_state = TRACK_PLAYING;
		[self performSelectorOnMainThread:@selector(_notifyTrackChange) withObject:nil waitUntilDone:NO];
	} else {
		_state = TRACK_BUFFERING;
		//kick start the audio stream
		if(!_connection)
			[self connection:nil didReceiveData:nil];
	}
	return YES;
}
-(void)stop {
	if(queue) {
		AudioQueueDispose(queue, true);
		AudioFileStreamClose(parser);
		queue = nil;
	}
	[_connection cancel];
	[[SystemNowPlayingController sharedInstance] postNowPlayingInfoForSongWithPath:nil
																																					 title:nil
																																					artist:nil
																																					 album:nil
																																			 isPlaying:NO
																																		hasImageData:NO
																																	additionalInfo:nil];
	[[UIApplication sharedApplication] setUsesBackgroundNetwork:NO];
	[UIApplication sharedApplication].idleTimerDisabled = NO;
}
-(void)bufferEnqueued {
	[_audioBufferCountLock lock];
	_audioBufferCount++;
	if(_audioBufferCount > _peakBufferCount) _peakBufferCount = _audioBufferCount;
	[_audioBufferCountLock unlock];
}
-(void)bufferDequeued {
	[_audioBufferCountLock lock];
	_audioBufferCount--;
	if(_state == TRACK_PLAYING && _peakBufferCount > 10) {
		if(_audioBufferCount < 1 && [_receivedData length] < 8192) {
			if(_fileDidFinishLoading) {
				[self performSelectorOnMainThread:@selector(_notifyTrackFinishedPlaying) withObject:nil waitUntilDone:NO];
			} else {
				[self pause];
				_state = TRACK_BUFFERING;
				NSLog(@"Buffer underrun detected, peak buffers this cycle was %i.\n", _peakBufferCount);
				_peakBufferCount = 0;
			}
		}
	}
	[_audioBufferCountLock unlock];	
}
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	[_connection release];
	_connection = nil;
	if([_receivedData length] == 0 && _state == TRACK_BUFFERING) {
		[self performSelectorOnMainThread:@selector(_notifyTrackFailed) withObject:self waitUntilDone:NO];
	} else {
		_fileDidFinishLoading = YES;
		if(_state != TRACK_PAUSED)
			[self performSelectorOnMainThread:@selector(_notifyTrackFinishedLoading) withObject:self waitUntilDone:NO];
	}
}
- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse {
	NSLog(@"Streaming: %@", [request URL]);
	return request;
}
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response {
	[_receivedData setLength:0];
	NSLog(@"HTTP status code: %i\n", [response statusCode]);
	if([response statusCode] != 200)
		NSLog(@"HTTP headers: %@", [response allHeaderFields]);
}
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	NSData *extraData = nil;
	[_bufferLock lock];
	
	if(data)
		[_receivedData appendData:data];
	if(_state != TRACK_PAUSED && ([_receivedData length] > 196608 || _state == TRACK_PLAYING)) {
		if(_state == TRACK_BUFFERING) {
			NSLog(@"Staring queue");
			AudioQueueStart(queue, NULL);
			_state = TRACK_PLAYING;
		}
		while([_receivedData length]) {
			if([_receivedData length] > 16384) {
				extraData = [NSData dataWithBytes:[_receivedData bytes]+16384 length:[_receivedData length]-16384];
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
				extraData = nil;
			}
		}
	}
	[_bufferLock unlock];
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
	if(_state == TRACK_BUFFERING && [_receivedData length] < 196608)
		return ((float)[_receivedData length]) / 196608.0f;
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
-(float)bufferProgress {
	return [[_tracks objectAtIndex:0] bufferProgress];
}
-(NSTimeInterval)startTime {
	return [[_tracks objectAtIndex:0] startTime];
}
-(NSDictionary *)trackInfo {
	return [[_tracks objectAtIndex:0] trackInfo];
}
-(int)state {
	if([_tracks count])
		return [[_tracks objectAtIndex:0] state];
	else
		return RADIO_IDLE;
}
-(NSString *)station {
	return [_station stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
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
	if(notification.object == [_tracks objectAtIndex:0]) {
		[notification.object play];
	}
}
-(void)_trackDidFinishPlaying:(NSNotification *)notification {
	[_busyLock lock];
	//For some reason [_tracks removeObjectAtIndex:0] doesn't deallocate us properly, so we'll do it ourselves
	LastFMTrack *t = [[_tracks objectAtIndex: 0] retain];
	[_tracks removeObjectAtIndex:0];
	[t release];
	if([_tracks count]) {
		[[_tracks objectAtIndex:0] play];
	} else {
		[self play];
	}
	[_busyLock unlock];
}
-(void)_softSkip {
	[_playlist removeObjectAtIndex:0];
	[self play];
	[[_tracks lastObject] pause];
}
-(void)_trackDidFinishLoading:(NSNotification *)notification {
	[_busyLock lock];
	if(notification.object == [_tracks objectAtIndex:0]) {
		float duration = [[[notification.object trackInfo] objectForKey:@"duration"] floatValue]/1000.0f;
		float elapsed = [notification.object trackPosition];
		if(duration-elapsed < 30) {
			[self _softSkip];
		} else {
			[self performSelector:@selector(_softSkip) withObject:nil afterDelay:(duration-elapsed-30)];
		}
	}
	[_busyLock unlock];
}
-(void)_trackDidFail:(NSNotification *)notification {
	if(notification.object == [_tracks objectAtIndex:0]) {
		if(_errorSkipCounter++) {
			 [(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate displayError:NSLocalizedString(@"ERROR_PLAYBACK_FAILED", @"Playback failure error") withTitle:NSLocalizedString(@"ERROR_PLAYBACK_FAILED_TITLE", @"Playback failed error title")];
			 [self stop];
		 } else {
			 [_playlist release];
			 _playlist = nil;
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
	PLSqliteResultSet *rs = (PLSqliteResultSet *)[_db executeQuery:@"select * from recent_radio order by timestamp desc",  nil];
	
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
	NSLog(@"Selecting station: %@\n", station);
	NSLog(@"Network connection type: %@\n", [(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate hasWiFiConnection]?@"WiFi":@"EDGE");
	NSDictionary *tune = [[LastFMService sharedInstance] tuneRadioStation:station];
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
		[self removeRecentURL: _stationURL];
		[_db executeUpdate:@"insert into recent_radio (timestamp, url, name) values (?, ?, ?)",
		 [NSString stringWithFormat:@"%qu", (u_int64_t)CFAbsoluteTimeGetCurrent()], _stationURL, [[_station stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"] capitalizedString], nil];
		return TRUE;
	}
	return FALSE;
}
-(BOOL)play {
	if(!_playlist || [_playlist count] < 3 || _station == nil) {
		NSDictionary *playlist = [[LastFMService sharedInstance] getPlaylist];
		if([[playlist objectForKey:@"playlist"] count]) {
			if(!_playlist) {
				_playlist = [[NSMutableArray alloc] initWithArray:[playlist objectForKey:@"playlist"]];
			} else {
				[_playlist addObjectsFromArray:[playlist objectForKey:@"playlist"]];
			}
		} else {
			if([LastFMService sharedInstance].error)
				[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate reportError:[LastFMService sharedInstance].error];
			else
				[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate displayError:NSLocalizedString(@"ERROR_INSUFFICIENT_CONTENT", @"Not enough content error") withTitle:NSLocalizedString(@"ERROR_INSUFFICIENT_CONTENT_TITLE", @"Not enough content title")];
			return FALSE;
		}
	}

	LastFMTrack *track = [[[LastFMTrack alloc] initWithTrackInfo:[_playlist objectAtIndex:0]] autorelease];
	
	if(track) {
		[_tracks addObject:track];
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
	NSLog(@"Stopping playback\n");
	if([_tracks count]) {
		[[_tracks objectAtIndex: 0] stop];
		[_tracks removeAllObjects];
		AudioSessionSetActive(FALSE);
	}
	NSLog(@"Playback stopped");
	[_busyLock unlock];
}
-(void)skip {
	[_busyLock lock];
	NSLog(@"Skipping to next track\n");
	[[_tracks objectAtIndex: 0] stop];
	[_tracks removeObjectAtIndex: 0];
	if([_tracks count]) {
		[[_tracks objectAtIndex:0] play];
	} else {
		[_playlist removeObjectAtIndex:0];
		[self play];
	}
	[_busyLock unlock];
}
@end
