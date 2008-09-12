/* LastFMRadio.h - Stream music from Last.FM
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

#import <Foundation/Foundation.h>
#include <AudioToolbox/AudioToolbox.h>
#import "CXMLDocument.h"
#import "PlausibleDatabase.h"

#define RADIO_IDLE 0
#define TRACK_BUFFERING 1
#define TRACK_READY 2
#define TRACK_PLAYING 3
#define TRACK_PAUSED 4

NSString *kTrackDidBecomeAvailable;
NSString *kTrackDidFinishLoading;
NSString *kTrackDidFinishPlaying;
NSString *kTrackDidChange;
NSString *kTrackDidFailToStream;

@interface LastFMTrack : NSObject {
	NSDictionary *_trackInfo;
	NSURLConnection *_connection;
	NSMutableData *_receivedData;
	BOOL _fileDidFinishLoading;
	NSLock *_audioBufferCountLock;
	NSLock *_bufferLock;
	int _audioBufferCount;
	int _peakBufferCount;
	AudioFileStreamID parser;
	AudioQueueRef queue;
	AudioStreamBasicDescription dataFormat;
	int _state;
	NSTimeInterval _startTime;
}

@property AudioFileStreamID parser;
@property AudioQueueRef queue;
@property AudioStreamBasicDescription dataFormat;

-(id)initWithTrackInfo:(NSDictionary *)trackInfo;
-(BOOL)play;
-(void)pause;
-(void)stop;
-(BOOL)isPlaying;
-(int)trackPosition;
-(void)bufferEnqueued;
-(void)bufferDequeued;
-(float)bufferProgress;
-(int)state;
-(NSDictionary *)trackInfo;
@end

@interface LastFMRadio : NSObject {
	NSString *_station;
	NSString *_stationURL;
	NSMutableArray *_playlist;
	NSMutableArray *_tracks;
	PLSqliteDatabase *_db;
	NSLock *_busyLock;
	BOOL playbackWasInterrupted;
	NSTimeInterval _startTime;
	int _errorSkipCounter;
}

@property BOOL playbackWasInterrupted;

+(LastFMRadio *)sharedInstance;
-(void)purgeRecentURLs;
-(void)removeRecentURL:(NSString *)url;
-(NSArray *)recentURLs;
-(BOOL)selectStation:(NSString *)station;
-(BOOL)play;
-(void)stop;
-(void)skip;
-(NSDictionary *)trackInfo;
-(int)trackPosition;
-(int)state;
-(NSString *)station;
-(NSString *)stationURL;
-(NSTimeInterval)startTime;
-(float)bufferProgress;
@end

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

