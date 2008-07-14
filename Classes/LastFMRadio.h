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
#import "FMDatabase.h"

#define RADIO_IDLE 0
#define RADIO_BUFFERING 1
#define RADIO_PLAYING 2
#define RADIO_PAUSED 3

@interface LastFMRadio : NSObject {
	NSString *_station;
	NSString *_stationURL;
	NSMutableArray *_playlist;
	NSURLConnection *_connection;
	NSMutableData *_receivedData;
	int _state;
	FMDatabase *_db;
	NSLock *_busyLock;
	BOOL playbackWasInterrupted;
	BOOL _fileDidFinishLoading;
	NSLock *_audioBufferCountLock;
	int _audioBufferCount;
	int _peakBufferCount;
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
-(void)restart;
-(void)pause;
-(void)bufferEnqueued;
-(void)bufferDequeued;
-(NSTimeInterval)startTime;
-(float)bufferProgress;
@end

#define kLastFMRadio_TrackDidChange @"LastFMRadio_TrackDidChange"
