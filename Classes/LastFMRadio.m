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

/*@interface SystemNowPlayingController : NSObject
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

@end*/

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

void propListener(	void *                  inClientData,
									AudioSessionPropertyID	inID,
									UInt32                  inDataSize,
									const void *            inData)
{
	if (inID == kAudioSessionProperty_AudioRouteChange)
	{
		CFDictionaryRef routeDictionary = (CFDictionaryRef)inData;			
		CFShow(routeDictionary);
		CFNumberRef reason = (CFNumberRef)CFDictionaryGetValue(routeDictionary, CFSTR(kAudioSession_AudioRouteChangeKey_Reason));
		SInt32 reasonVal;
		CFNumberGetValue(reason, kCFNumberSInt32Type, &reasonVal);
		if (reasonVal != kAudioSessionRouteChangeReason_PolicyChange)
		{
			CFStringRef oldRoute = (CFStringRef)CFDictionaryGetValue(routeDictionary, CFSTR(kAudioSession_AudioRouteChangeKey_OldRoute));
			 if (oldRoute)	
			 {
			 printf("old route:\n");
			 CFShow(oldRoute);
			 }
			 else 
			 printf("ERROR GETTING OLD AUDIO ROUTE!\n");
			 
			 CFStringRef newRoute;
			 UInt32 size; size = sizeof(CFStringRef);
			 OSStatus error = AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &size, &newRoute);
			 if (error) printf("ERROR GETTING NEW AUDIO ROUTE! %d\n", error);
			 else
			 {
			 printf("new route:\n");
			 CFShow(newRoute);
			 }
			
			if (reasonVal == kAudioSessionRouteChangeReason_OldDeviceUnavailable)
			{			
				/*if (THIS->_player->IsRunning()) {
					[THIS stopPlayQueue];
				}	*/	
			}
		}	
	}
}

typedef struct AQCallbackStruct {
	AudioFileStreamID parser;
	AudioQueueRef queue;
	AudioStreamBasicDescription mDataFormat;
	BOOL decodeComplete;
	LastFMRadio *radio;
	int enqueuedBufferCount;
} AQCallbackStruct;

AQCallbackStruct in;

static void AQBufferCallback(void *in, AudioQueueRef inQ, AudioQueueBufferRef outQB) {
	AudioQueueFreeBuffer(inQ, outQB);
	[[LastFMRadio sharedInstance] bufferDequeued];
}

void packetCallback(void *in,
										 UInt32 inNumberBytes,
										 UInt32 inNumberPackets,
										 const void *inInputData,
										 AudioStreamPacketDescription *inPacketDescriptions) {
	AQCallbackStruct *inData = in;
	AudioQueueBufferRef buf;
	
	AudioQueueAllocateBufferWithPacketDescriptions(inData->queue, inNumberBytes, inNumberPackets, &buf);
	buf->mAudioDataByteSize = inNumberBytes;
	memcpy(buf->mAudioData, inInputData, inNumberBytes);
	AudioQueueEnqueueBuffer(inData->queue, buf, inNumberPackets, inPacketDescriptions);
	[[LastFMRadio sharedInstance] bufferEnqueued];
}

void propCallback(void *in,
									AudioFileStreamID inAudioFileStream,
									AudioFileStreamPropertyID inPropertyID,
									UInt32 *ioFlags) {
	AQCallbackStruct *inData = in;
	
	switch(inPropertyID) {
		case kAudioFileStreamProperty_DataFormat:
			NSLog(@"Got data format\n");
			UInt32 len = sizeof(inData->mDataFormat);
			AudioFileStreamGetProperty(inAudioFileStream, inPropertyID, &len, &inData->mDataFormat);
			break;
		case kAudioFileStreamProperty_ReadyToProducePackets:
			NSLog(@"Ready to produce packets\n");
			OSStatus error = AudioQueueNewOutput(&inData->mDataFormat,
													AQBufferCallback,
													inData,
													NULL,
													kCFRunLoopCommonModes,
													0,
													&inData->queue);
			if(error) {
				NSLog(@"Unable to create audio queue!  Retrying...\n");
				error = AudioQueueNewOutput(&inData->mDataFormat,
																						 AQBufferCallback,
																						 inData,
																						 NULL,
																						 kCFRunLoopCommonModes,
																						 0,
																						 &inData->queue);
				if(error) {
					NSLog(@"Second attempt failed too, bailing out!\n");
					[inData->radio stop];
					return;
				}
			}
			/*NSLog(@"Starting audio queue");
			error = AudioQueueStart(inData->queue, NULL);
			if(error) {
				NSLog(@"Unable to start audio queue, retrying...\n");
				error = AudioQueueStart(inData->queue, NULL);
				if(error) {
					NSLog(@"Second attempt failed too, bailing out!\n");
					[inData->radio stop];
					return;
				}
			}*/
		break;
	}
}

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
	if(_state == RADIO_BUFFERING)
		return ((float)[_receivedData length]) / (float)(16384 * _bufferDistance);
	else
		return 1;
}
-(NSTimeInterval)startTime {
	return _startTime;
}
-(NSDictionary *)trackInfo {
	return [_playlist objectAtIndex:0];
}
-(int)state {
	return _state;
}
-(NSString *)station {
	return _station;
}
-(NSString *)stationURL {
	return _stationURL;
}
-(int)trackPosition {
	if(_state == RADIO_IDLE) return 0;
	AudioTimeStamp t;
	Boolean b;
	
	if(AudioQueueGetCurrentTime(in.queue, NULL, &t, &b) < 0)
		return 0;
	else
		return t.mSampleTime / in.mDataFormat.mSampleRate;
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
	_audioBufferCountLock = [[NSLock alloc] init];
	OSStatus error = AudioSessionInitialize(NULL, NULL, interruptionListener, self);
	if (error) printf("ERROR INITIALIZING AUDIO SESSION! %d\n", error);
	else 
	{										
		error = AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, propListener, self);
		if (error) printf("ERROR ADDING AUDIO SESSION PROP LISTENER! %d\n", error);
	}
	return self;
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
	CFDateFormatterRef dateFormatter = CFDateFormatterCreate(NULL, CFLocaleCopyCurrent(), kCFDateFormatterShortStyle, kCFDateFormatterNoStyle);
	CFDateFormatterSetFormat(dateFormatter, (CFStringRef)@"dd MMM yyyy, HH:mm");
	[_db open];
	FMResultSet *rs = [_db executeQuery:@"select * from recent_radio order by timestamp desc",  nil];
	
	while([rs next]) {
		CFDateRef d = CFDateCreate(NULL,[rs doubleForColumn:@"timestamp"]);
		NSString *date = (NSString *)CFDateFormatterCreateStringWithDate(NULL, dateFormatter, d);
		
		[URLs addObject:[NSDictionary dictionaryWithObjectsAndKeys:
										 [rs stringForColumn:@"url"], @"url",
										 [rs stringForColumn:@"name"], @"name",
										 date, @"date",
										 nil]];
		
		CFRelease(date);
		CFRelease(d);
	}
	[_db close];
	CFRelease(dateFormatter);
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
		_bufferDistance = [(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate hasWiFiConnection] ? 16 : 64;
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
			_state = RADIO_IDLE;
			if([LastFMService sharedInstance].error)
				[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate reportError:[LastFMService sharedInstance].error];
			else
				[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate displayError:NSLocalizedString(@"ERROR_INSUFFICIENT_CONTENT", @"Not enough content error") withTitle:NSLocalizedString(@"ERROR_INSUFFICIENT_CONTENT_TITLE", @"Not enough content title")];
			return FALSE;
		}
	}

	NSURL *trackURL = [NSURL URLWithString:[[_playlist objectAtIndex:0] objectForKey:@"location"]];
	NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:trackURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) hasWiFiConnection]?40:60];
	[theRequest setValue:kUserAgent forHTTPHeaderField:@"User-Agent"];
	NSLog(@"Streaming: %@\n", trackURL);
	if(_connection) [_connection release];
	_connection=[[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
	if(_receivedData) [_receivedData release];
	_receivedData = [[NSMutableData alloc] init];

	if (_connection) {
		[[_playlist objectAtIndex:0] setObject:[NSString stringWithFormat:@"%i", (long)[[NSDate date] timeIntervalSince1970]] forKey:@"startTime"];
		_state = RADIO_BUFFERING;
		_fileDidFinishLoading = NO;
		_audioBufferCount = 0;
		_peakBufferCount = 0;
		_startTime = [[NSDate date] timeIntervalSince1970];
		in.decodeComplete = FALSE;
		in.radio = self;
		in.queue = nil;
		UInt32 category = kAudioSessionCategory_MediaPlayback;
		OSStatus result = AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(category), &category);
		if (result) printf("ERROR SETTING AUDIO CATEGORY!\n");
		
		result = AudioSessionSetActive(true);
		if (result) printf("ERROR SETTING AUDIO SESSION ACTIVE!\n");
		self.playbackWasInterrupted = NO;
		AudioFileStreamOpen (&in,
												 propCallback,
												 packetCallback,
												 kAudioFileMP3Type,
												 &in.parser);
		[self removeRecentURL: _stationURL];
		[_db open];
		[_db executeUpdate:@"insert into recent_radio (timestamp, url, name) values (?, ?, ?)",
		 [NSString stringWithFormat:@"%qu", (u_int64_t)CFAbsoluteTimeGetCurrent()], _stationURL, [_station capitalizedString], nil];
		[_db close];
		[[NSNotificationCenter defaultCenter] postNotificationName:kLastFMRadio_TrackDidChange object:self userInfo:[_playlist objectAtIndex:0]];
		/*[[SystemNowPlayingController sharedInstance] postNowPlayingInfoForSongWithPath:nil
																																						 title:[[_playlist objectAtIndex:0] objectForKey:@"title"]
																																						artist:[[_playlist objectAtIndex:0] objectForKey:@"creator"]
																																						 album:[[_playlist objectAtIndex:0] objectForKey:@"album"]
																																				 isPlaying:YES
																																			hasImageData:NO
																																		additionalInfo:nil];*/
		[[UIApplication sharedApplication] setUsesBackgroundNetwork:YES];
		return TRUE;
	} else {
		_state = RADIO_IDLE;
		return FALSE;
	}
}
-(void)dealloc {
	if(_state != RADIO_IDLE) {
		[self stop];
	}
	[_playlist release];
	[_connection release];
	[_receivedData release];
	[_busyLock release];
	[_audioBufferCountLock release];
	[super dealloc];
}
-(void)stop {
	[_busyLock lock];
	
	NSLog(@"Stopping playback\n");
	if(_state != RADIO_IDLE) {
		if(in.queue) {
			AudioQueueDispose(in.queue, true);
			AudioFileStreamClose(in.parser);
			AudioSessionSetActive(FALSE);
			in.queue = nil;
		}
		_state = RADIO_IDLE;
		[_connection cancel];
		[_connection release];
		_connection = nil;
		[_receivedData release];
		_receivedData = nil;
	}
	/*[[SystemNowPlayingController sharedInstance] postNowPlayingInfoForSongWithPath:nil
																																					 title:nil
																																					artist:nil
																																					 album:nil
																																			 isPlaying:NO
																																		hasImageData:NO
																																	additionalInfo:nil];*/
	[[UIApplication sharedApplication] setUsesBackgroundNetwork:NO];
	NSLog(@"Playback stopped");
	[_busyLock unlock];
}
-(void)skip {
	[_busyLock lock];
	
	NSLog(@"Skipping to next track\n");
	if(in.queue) {
		AudioQueueDispose(in.queue, true);
		AudioFileStreamClose(in.parser);
		in.queue = nil;
	}
	[_connection cancel];
	[_connection release];
	_connection = nil;
	[_receivedData release];
	_receivedData = nil;
	[_playlist removeObjectAtIndex:0];
	[_busyLock unlock];
	[self play];
}
-(void)bufferEnqueued {
	[_audioBufferCountLock lock];
	_audioBufferCount++;
	if(_audioBufferCount > _peakBufferCount) _peakBufferCount = _audioBufferCount;
	[_audioBufferCountLock unlock];	
	if(_state == RADIO_BUFFERING)
		[self restart];
}
-(void)bufferDequeued {
	[_audioBufferCountLock lock];
	_audioBufferCount--;
	if(_state == RADIO_PLAYING && _peakBufferCount > 10) {
		if(_audioBufferCount < 1 && !_fileDidFinishLoading) {
			_state = RADIO_BUFFERING;
			[self pause];
			_bufferDistance += 8;
			NSLog(@"Buffer underrun detected, increased buffer distance to: %i. Peak buffers this cycle was %i.\n", _bufferDistance, _peakBufferCount);
			_peakBufferCount = 0;
		}
	}
	[_audioBufferCountLock unlock];	
}
- (void)_skipWhenReady {
	UInt32 isRunning = 0;
	UInt32 size = sizeof(isRunning);

	OSStatus error = AudioQueueGetProperty(in.queue, kAudioQueueProperty_IsRunning, &isRunning, &size);
	if(!error && isRunning && in.queue) {
		[_busyLock lock];
		if(in.queue) {
			AudioQueueFlush(in.queue);
			AudioQueueStop(in.queue, false);
		}
		[_busyLock unlock];
		NSLog(@"Waiting for stream to finish\n");
		do {
			CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.25, false);
			error = AudioQueueGetProperty(in.queue, kAudioQueueProperty_IsRunning, &isRunning, &size);
		} while(!error && isRunning && in.queue);
		if(_state == RADIO_PLAYING && in.queue) {
			NSLog(@"Preparing to skip\n");
			[self performSelectorOnMainThread:@selector(skip) withObject:nil waitUntilDone:NO];
		} else {
			NSLog(@"Not skipping\n");
		}
	}
}	
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	_fileDidFinishLoading = YES;
	if([_receivedData length] == 0 && _state == RADIO_BUFFERING) {
		if(_errorSkipCounter++) {
			[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate displayError:NSLocalizedString(@"ERROR_PLAYBACK_FAILED", @"Playback failure error") withTitle:NSLocalizedString(@"ERROR_PLAYBACK_FAILED_TITLE", @"Playback failed error title")];
			[self stop];
		} else {
			[self skip];
		}
	} else {
		_errorSkipCounter = 0;
		[NSThread detachNewThreadSelector:@selector(_skipWhenReady) toTarget:self withObject:nil];
	}
}
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	[_receivedData setLength:0];
}
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	[_receivedData appendData:data];
	if([_receivedData length] > (16384 * _bufferDistance) || _state == RADIO_PLAYING) {
		OSStatus error = AudioFileStreamParseBytes(in.parser, [_receivedData length], [_receivedData bytes], 0);
		if(error) {
			NSLog(@"Got an error pushing the data! :(");
		} else {
			[_receivedData setLength:0];
			_state = RADIO_PLAYING;
		}
	}
}
-(void)pause {
	NSLog(@"Pausing audio queue");
	AudioQueuePause(in.queue);
}
-(void)restart {
	NSLog(@"Restarting audio queue");
	AudioQueueStart(in.queue, NULL);
	_state = RADIO_PLAYING;
	self.playbackWasInterrupted = NO;
}
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	if(_errorSkipCounter++) {
		[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate displayError:NSLocalizedString(@"ERROR_PLAYBACK_FAILED", @"Playback failure error") withTitle:NSLocalizedString(@"ERROR_PLAYBACK_FAILED_TITLE", @"Playback failed error title")];
		[self stop];
	} else {
		[self skip];
	}
}
@end
