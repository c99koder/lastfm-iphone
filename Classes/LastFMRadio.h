/* LastFMRadio.h - Stream music from Last.FM
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

#import <Foundation/Foundation.h>
#include <AudioToolbox/AudioToolbox.h>
#import "CXMLDocument.h"
#import "PlausibleDatabase.h"

#define RADIO_IDLE 0
#define RADIO_TUNING 1
#define TRACK_BUFFERING 2
#define TRACK_READY 3
#define TRACK_PLAYING 4
#define TRACK_PAUSED 5

NSString *kTrackDidBecomeAvailable;
NSString *kTrackDidFinishLoading;
NSString *kTrackDidFinishPlaying;
NSString *kTrackDidChange;
NSString *kTrackDidFailToStream;
NSString *kTrackDidPause;
NSString *kTrackDidResume;
NSString *kArtworkDidBecomeAvailable;

@interface LastFMTrack : NSObject {
	NSDictionary *_trackInfo;
	NSURLConnection *_connection;
	NSMutableData *_receivedData;
	BOOL _fileDidFinishLoading;
	NSLock *_audioBufferCountLock;
	NSLock *_bufferLock;
	int _audioBufferCount;
	int _peakBufferCount;
	int audioBufferDataSize;
	AudioFileStreamID parser;
	AudioQueueRef queue;
	AudioStreamBasicDescription dataFormat;
	int _state;
	NSTimeInterval _startTime;
    UIImage *_artwork;
}

@property AudioFileStreamID parser;
@property AudioQueueRef queue;
@property AudioStreamBasicDescription dataFormat;
@property int audioBufferDataSize;

-(id)initWithTrackInfo:(NSDictionary *)trackInfo;
-(BOOL)play;
-(void)pause;
-(void)resume;
-(void)stop;
-(BOOL)isPlaying;
-(int)trackPosition;
-(void)bufferEnqueued;
-(void)bufferDequeued;
-(float)bufferProgress;
-(int)state;
-(NSDictionary *)trackInfo;
-(int)audioBufferCount;
-(int)httpBufferSize;
-(BOOL)lowOnMemory;
-(BOOL)didFinishLoading;
-(UIImage *)artwork;
@end

@interface LastFMRadio : NSObject {
	NSString *_station;
	NSString *_stationURL;
	NSString *_radioType;
	NSMutableArray *_playlist;
	NSMutableArray *_tracks;
	NSDate *_playlistExpiration;
	PLSqliteDatabase *_db;
	NSLock *_busyLock;
	BOOL playbackWasInterrupted;
	NSTimeInterval _startTime;
	int _errorSkipCounter;
	NSTimer *_softSkipTimer;
	BOOL prebuffering;
	BOOL softskipping;
	BOOL tuning;
	NSArray *_suggestions;
	UIBackgroundTaskIdentifier bgTask;
}

@property BOOL playbackWasInterrupted;

+(LastFMRadio *)sharedInstance;
-(void)purgeRecentURLs;
-(void)removeRecentURL:(NSString *)url;
-(NSArray *)recentURLs;
-(void)fetchRecentURLs;
-(BOOL)selectStation:(NSString *)station;
-(BOOL)play;
-(void)stop;
-(void)pause;
-(void)skip;
-(NSDictionary *)trackInfo;
-(int)trackPosition;
-(int)state;
-(NSString *)station;
-(NSString *)stationURL;
-(NSTimeInterval)startTime;
-(float)bufferProgress;
-(LastFMTrack *)currentTrack;
-(BOOL)cancelPrebuffering;
-(NSArray *)suggestions;
-(void)lowOnMemory;
-(UIImage *)artwork;
@end
