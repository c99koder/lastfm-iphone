/* Scrobbler.h - AudioScrobbler client class
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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define SCROBBLER_OFFLINE 0
#define SCROBBLER_AUTHENTICATING 1
#define SCROBBLER_READY 2
#define SCROBBLER_SCROBBLING 3
#define SCROBBLER_NOWPLAYING 4

@interface Scrobbler : NSObject {
	NSString *_sess;
	NSString *_nowPlayingURL;
	NSString *_scrobbleURL;
	NSURLConnection *_connection;
	NSMutableData *_receivedData;
	int _scrobblerState;
	int _scrobblerError;
	NSMutableArray *_queue;
	NSTimer *_queueTimer;
	int _queueTimerInterval;
	int _totalScrobbled;
	NSString *_scrobblerResult;
	int _submissionCount;
	int _maxSubmissionCount;
	NSTimer *_timer;
	BOOL _submitted;
	BOOL _sentNowPlaying;
	int _oldNetworkType;
}
- (BOOL)scrobbleTrack:(NSString *)title byArtist:(NSString *)artist onAlbum:(NSString *)album withStartTime:(int)startTime withDuration:(int)duration fromSource:(NSString *)source;
- (void)nowPlayingTrack:(NSString *)title byArtist:(NSString *)artist onAlbum:(NSString *)album withDuration:(int)duration;
- (void)rateTrack:(NSString *)title byArtist:(NSString *)artist onAlbum:(NSString *)album withStartTime:(int)startTime withDuration:(int)duration fromSource:(NSString *)source rating:(NSString *)rating;
- (void)handshake;
- (void)flushQueue:(NSTimer *)theTimer;
- (void)doQueueTimer;
- (void)loadQueue;
- (void)saveQueue;
- (void)update:(NSTimer *)theTimer;
- (void)cancelTimer;
@end
