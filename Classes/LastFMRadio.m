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

@implementation LastFMTrack

@synthesize parser, queue, dataFormat;

-(id)initWithTrackInfo:(NSDictionary *)trackInfo {
	if(self = [super init]) {
		_trackInfo = [trackInfo retain];
		_audioBufferCountLock = [[NSLock alloc] init];
		NSURL *trackURL = [NSURL URLWithString:[_trackInfo objectForKey:@"location"]];
		NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:trackURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) hasWiFiConnection]?40:60];
		[theRequest setValue:kUserAgent forHTTPHeaderField:@"User-Agent"];
		NSLog(@"Streaming: %@\n", trackURL);
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
	[super dealloc];
	if(queue) {
		AudioQueueDispose(queue, true);
		AudioFileStreamClose(parser);
	}
	[_trackInfo release];
	[_connection release];
	[_receivedData release];
	[_audioBufferCountLock release];
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
		[[NSNotificationCenter defaultCenter] postNotificationName:kTrackDidChange object:self userInfo:_trackInfo];
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
	} else {
		_state = TRACK_BUFFERING;
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
		if(_audioBufferCount < 1) {
			if(_fileDidFinishLoading) {
				[_audioBufferCountLock unlock];
				[[NSNotificationCenter defaultCenter] postNotificationName:kTrackDidFinishPlaying object:self userInfo:nil];
				return;
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
	if([_receivedData length] == 0 && _state == TRACK_BUFFERING) {
		/*if(_errorSkipCounter++) {
			[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate displayError:NSLocalizedString(@"ERROR_PLAYBACK_FAILED", @"Playback failure error") withTitle:NSLocalizedString(@"ERROR_PLAYBACK_FAILED_TITLE", @"Playback failed error title")];
			[self stop];
		} else {
			[self skip];
		}*/
		[[NSNotificationCenter defaultCenter] postNotificationName:kTrackDidFailToStream object:self userInfo:nil];
	} else {
		_fileDidFinishLoading = YES;
		[[NSNotificationCenter defaultCenter] postNotificationName:kTrackDidFinishLoading object:self userInfo:nil];
	}
}
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	[_receivedData setLength:0];
}
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	[_receivedData appendData:data];
	if(_state != TRACK_PAUSED && ([_receivedData length] > 196608 || _state == TRACK_PLAYING)) {
		OSStatus error = AudioFileStreamParseBytes(parser, [_receivedData length], [_receivedData bytes], 0);
		if(error) {
			NSLog(@"Got an error pushing the data! :(");
		} else {
			[_receivedData setLength:0];
		}
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
	if(_state == TRACK_BUFFERING)
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
	return _trackInfo;
}
-(int)trackPosition {
	AudioTimeStamp t;
	Boolean b;
	
	if(_state != TRACK_PLAYING || AudioQueueGetCurrentTime(queue, NULL, &t, &b) < 0)
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
	
	_db = [[FMDatabase databaseWithPath:CACHE_FILE(@"recent.db")] retain];
	if (![_db open]) {
    NSLog(@"Could not open recent db.");
	}
	
	[_db executeUpdate:@"create table recent_radio (timestamp integer, url text, name text)", nil];

	FMResultSet *rs = [_db executeQuery:@"select * from recent_radio order by timestamp desc limit 1",  nil];
						
	if([rs next]) _stationURL = [[rs stringForColumn:@"url"] retain];
	
	[rs close];
	[_db close];
	
	_busyLock = [[NSLock alloc] init];
	_tracks = [[NSMutableArray alloc] init];
	AudioSessionInitialize(NULL, NULL, interruptionListener, self);
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidBecomeAvailable:) name:kTrackDidBecomeAvailable object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidFinishPlaying:) name:kTrackDidFinishPlaying object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidFinishLoading:) name:kTrackDidFinishLoading object:nil];
	return self;
}
-(void)_trackDidBecomeAvailable:(NSNotification *)notification {
	if(notification.object == [_tracks objectAtIndex:0]) {
		[notification.object play];
	}
}
-(void)_trackDidFinishPlaying:(NSNotification *)notification {
	[_tracks removeObject:notification.object];
	if([_tracks count]) {
		[[_tracks objectAtIndex:0] play];
	} else {
		[self play];
	}
}
-(void)_trackDidFinishLoading:(NSNotification *)notification {
	if(notification.object == [_tracks objectAtIndex:0]) {
		[_playlist removeObjectAtIndex:0];
		[self play];
		[[_tracks lastObject] pause];
	}
}
-(void)purgeRecentURLs {
	[_db open];
	[_db executeUpdate:@"delete from recent_radio", nil];
	[_db close];
}
-(void)removeRecentURL:(NSString *)url {
	[_db open];
	[_db executeUpdate:@"delete from recent_radio where url = ?", url, nil];
	[_db close];
}
-(NSArray *)recentURLs {
	NSMutableArray *URLs = [[NSMutableArray alloc] init];
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateFormat:@"dd MMM yyyy, HH:mm"];
	[_db open];
	FMResultSet *rs = [_db executeQuery:@"select * from recent_radio order by timestamp desc",  nil];
	
	while([rs next]) {
		[URLs addObject:[NSDictionary dictionaryWithObjectsAndKeys:
										 [rs stringForColumn:@"url"], @"url",
										 [rs stringForColumn:@"name"], @"name",
										 [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:[rs doubleForColumn:@"timestamp"]]], @"date",
										 nil]];
	}
	[_db close];
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

	LastFMTrack *track = [[LastFMTrack alloc] initWithTrackInfo:[_playlist objectAtIndex:0]];
	
	if(track) {
		[_tracks addObject:track];
		[[_playlist objectAtIndex:0] setObject:[NSString stringWithFormat:@"%i", (long)[[NSDate date] timeIntervalSince1970]] forKey:@"startTime"];
		[self removeRecentURL: _stationURL];
		[_db open];
		[_db executeUpdate:@"insert into recent_radio (timestamp, url, name) values (?, ?, ?)",
		 [NSString stringWithFormat:@"%qu", (u_int64_t)CFAbsoluteTimeGetCurrent()], _stationURL, [[_station stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"] capitalizedString], nil];
		[_db close];
		[track release];
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
	[_busyLock unlock];
	if([_tracks count]) {
		[[_tracks objectAtIndex:0] play];
	} else {
		[_playlist removeObjectAtIndex:0];
		[self play];
	}
}
@end
