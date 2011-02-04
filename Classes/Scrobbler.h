/* Scrobbler.h - AudioScrobbler client class
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
#import <UIKit/UIKit.h>

#define SCROBBLER_OFFLINE 0
#define SCROBBLER_AUTHENTICATING 1
#define SCROBBLER_READY 2
#define SCROBBLER_SCROBBLING 3
#define SCROBBLER_NOWPLAYING 4

@interface Scrobbler : NSObject {
	int _scrobblerState;
	int _scrobblerError;
	NSMutableArray *_queue;
	NSTimer *_queueTimer;
	int _queueTimerInterval;
	NSTimer *_timer;
	BOOL _submitted;
	BOOL _sentNowPlaying;
	int _oldNetworkType;
}
- (BOOL)scrobbleTrack:(NSString *)title byArtist:(NSString *)artist onAlbum:(NSString *)album withStartTime:(int)startTime withDuration:(int)duration fromSource:(NSString *)source;
- (void)nowPlayingTrack:(NSString *)title byArtist:(NSString *)artist onAlbum:(NSString *)album withDuration:(int)duration;
- (void)rateTrack:(NSString *)title byArtist:(NSString *)artist onAlbum:(NSString *)album withStartTime:(int)startTime withDuration:(int)duration fromSource:(NSString *)source rating:(NSString *)rating;
- (void)flushQueue:(NSTimer *)theTimer;
- (void)doQueueTimer;
- (void)loadQueue;
- (void)saveQueue;
- (void)update:(NSTimer *)theTimer;
- (void)cancelTimer;
@end
