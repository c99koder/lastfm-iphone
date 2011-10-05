/* LastFMService.h - AudioScrobbler webservice proxy
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
#import "CXMLDocument.h"
#import "apikey.h"

#define CACHE_FILE(file) [NSTemporaryDirectory() stringByAppendingPathComponent:file]

#define MINUTES 60
#define HOURS 3600
#define DAYS 86400

#define LastFMServiceErrorDomain @"LastFMServiceErrorDomain"

enum serviceErrorCodes {
	errorCodeInvalidService = 2,
	errorCodeInvalidMethod = 3,
	errorCodeAuthenticationFailed = 4,
	errorCodeInvalidFormat = 5,
	errorCodeInvalidParameters = 6,
	errorCodeInvalidResource = 7,
	errorCodeOperationFailed = 8,
	errorCodeInvalidSession = 9,
	errorCodeInvalidAPIKey = 10,
	errorCodeServiceOffline = 11,
	errorCodeSubscribersOnly = 12,
	errorCodeInvalidAPISignature = 13
};

enum radioErrorCodes {
	errorCodeTrialExpired = 18,
	errorCodeNotEnoughContent = 20,
	errorCodeNotEnoughMembers = 21,
	errorCodeNotEnoughFans = 22,
	errorCodeNotEnoughNeighbours = 23,
	errorCodeDeprecated = 27,
	errorCodeGeoRestricted = 28
};

enum eventStatus {
	eventStatusAttending = 0,
	eventStatusMaybeAttending = 1,
	eventStatusNotAttending = 2 
};

@interface LastFMService : NSObject {
	NSString *session;
	NSError *error;
	BOOL cacheOnly;
}
@property (nonatomic, retain) NSString *session;
@property (readonly) NSError *error;
@property (nonatomic) BOOL cacheOnly;

+ (LastFMService *)sharedInstance;
- (NSArray *)doMethod:(NSString *)method maxCacheAge:(double)seconds XPath:(NSString *)XPath withParameters:(NSString *)firstParam, ...;

- (NSDictionary *)getSessionInfo;
- (NSDictionary *)getGeo;

#pragma mark Artist methods

- (NSDictionary *)metadataForArtist:(NSString *)artist inLanguage:(NSString *)lang;
- (NSArray *)artistsSimilarTo:(NSString *)artist;
- (NSArray *)topTagsForArtist:(NSString *)artist;
- (void)addTags:(NSArray *)tags toArtist:(NSString *)artist;
- (void)removeTag:(NSString *)tag fromArtist:(NSString *)artist;
- (NSArray *)tagsForArtist:(NSString *)artist;
- (NSArray *)topAlbumsForArtist:(NSString *)artist;
- (NSArray *)topTracksForArtist:(NSString *)artist;
- (void)dismissRecommendedArtist:(NSString *)artist;
- (void)addArtistToLibrary:(NSString *)artist;
- (void)recommendArtist:(NSString *)artist toEmailAddress:(NSString *)emailAddress;

#pragma mark Album methods

- (void)addAlbumToLibrary:(NSString *)album byArtist:(NSString *)artist;
- (NSDictionary *)metadataForAlbum:(NSString *)album byArtist:(NSString *)artist inLanguage:(NSString *)lang;
- (NSArray *)topTagsForAlbum:(NSString *)track byArtist:(NSString *)artist;
- (void)addTags:(NSArray *)tags toAlbum:(NSString *)album byArtist:(NSString *)artist;
- (void)removeTag:(NSString *)tag fromAlbum:(NSString *)album byArtist:(NSString *)artist;
- (NSArray *)tagsForAlbum:(NSString *)album byArtist:(NSString *)artist;
- (NSArray *)tracksForAlbum:(NSString *)album byArtist:(NSString *)artist;
- (void)recommendAlbum:(NSString *)album byArtist:(NSString *)artist toEmailAddress:(NSString *)emailAddress;

#pragma mark Track methods

- (NSDictionary *)metadataForTrack:(NSString *)track byArtist:(NSString *)artist inLanguage:(NSString *)lang;
- (void)loveTrack:(NSString *)title byArtist:(NSString *)artist;
- (void)banTrack:(NSString *)title byArtist:(NSString *)artist;
- (NSArray *)fansOfTrack:(NSString *)track byArtist:(NSString *)artist;
- (NSArray *)topTagsForTrack:(NSString *)track byArtist:(NSString *)artist;
- (void)recommendTrack:(NSString *)track byArtist:(NSString *)artist toEmailAddress:(NSString *)emailAddress;
- (void)addTags:(NSArray *)tags toTrack:(NSString *)track byArtist:(NSString *)artist;
- (void)removeTag:(NSString *)tag fromTrack:(NSString *)track byArtist:(NSString *)artist;
- (NSArray *)tagsForTrack:(NSString *)track byArtist:(NSString *)artist;
- (NSArray *)shoutsForTrack:(NSString *)track byArtist:(NSString *)artist;
- (void)addTrackToLibrary:(NSString *)title byArtist:(NSString *)artist;
- (void)nowPlayingTrack:(NSString *)title byArtist:(NSString *)artist onAlbum:(NSString *)album withDuration:(int)duration;
- (void)removeNowPlayingTrack:(NSString *)title byArtist:(NSString *)artist onAlbum:(NSString *)album;
- (void)scrobbleTrack:(NSString *)title byArtist:(NSString *)artist onAlbum:(NSString *)album withDuration:(int)duration timestamp:(int)timestamp streamId:(NSString *)streamId;

#pragma mark User methods

- (void)createUser:(NSString *)username withPassword:(NSString *)password andEmail:(NSString *)email;
- (NSDictionary *)getMobileSessionForUser:(NSString *)username password:(NSString *)password;
- (NSArray *)friendsOfUser:(NSString *)username;
- (NSArray *)nowListeningFriendsOfUser:(NSString *)username;
- (NSArray *)topArtistsForUser:(NSString *)username;
- (NSDictionary *)weeklyArtistsForUser:(NSString *)username;
- (NSArray *)topAlbumsForUser:(NSString *)username;
- (NSArray *)topTracksForUser:(NSString *)username;
- (NSArray *)tagsForUser:(NSString *)username;
- (NSArray *)recentlyPlayedTracksForUser:(NSString *)username;
- (NSArray *)playlistsForUser:(NSString *)username;
- (NSArray *)recommendedArtistsForUser:(NSString *)username;
- (NSArray *)recommendedReleasesForUser:(NSString *)username;
- (NSArray *)releasesForUser:(NSString *)username;
- (NSString *)releaseDataSourceForUser:(NSString *)username;
- (NSDictionary *)profileForUser:(NSString *)username;
- (NSDictionary *)profileForUser:(NSString *)username authenticated:(BOOL)authenticated;
- (NSDictionary *)compareArtistsOfUser:(NSString *)username withUser:(NSString *)username2;
- (NSArray *)recentStationsForUser:(NSString *)username;

#pragma mark Tag methods

- (NSArray *)tagsSimilarTo:(NSString *)tag;
- (NSArray *)topArtistsForTag:(NSString *)tag;
- (NSArray *)topAlbumsForTag:(NSString *)tag;
- (NSArray *)topTracksForTag:(NSString *)tag;
- (NSDictionary *)metadataForTag:(NSString *)tag inLanguage:(NSString *)lang;

#pragma mark Radio methods

- (NSDictionary *)tuneRadioStation:(NSString *)stationURL;
- (NSDictionary *)getPlaylist;
- (NSArray *)suggestedTagsForStation:(NSString *)stationURL;
- (NSDictionary *)userStations;

#pragma mark Search methods

- (NSArray *)search:(NSString *)query;
- (NSArray *)searchForArtist:(NSString *)artist;
- (NSArray *)searchForTag:(NSString *)tag;
- (NSString *)searchForStation:(NSString *)query;

#pragma mark Event methods

- (void)attendEvent:(int)event status:(int)status;
- (NSArray *)eventsForLatitude:(float)latitude longitude:(float)longitude radius:(int)radius;
- (NSArray *)festivalsForLatitude:(float)latitude longitude:(float)longitude radius:(int)radius;
- (NSDictionary *)detailsForEvent:(int)eventID;
- (NSArray *)recommendedLineupForEvent:(int)eventID;
- (NSArray *)festivalsForCountry:(NSString *)country page:(int)page;
- (NSArray *)eventsForArtist:(NSString *)artist;
- (NSArray *)festivalsForArtist:(NSString *)artist;
- (NSArray *)searchForEvent:(NSString *)event;
- (NSArray *)searchForFestival:(NSString *)event;
- (NSArray *)eventsForUser:(NSString *)username;
- (NSArray *)eventsForFriendsOfUser:(NSString *)username;
- (NSArray *)festivalsForUser:(NSString *)username;
- (NSArray *)festivalsForFriendsOfUser:(NSString *)username;
- (NSArray *)recommendedEventsForUser:(NSString *)username;
- (void)recommendEvent:(int)event toEmailAddress:(NSString *)emailAddress;
- (NSArray *)highlightedFestivals;
- (NSDictionary *)adsForCountry:(NSString *)country;
- (NSArray *)getMetros;

#pragma mark Playlist methods

- (void)addTrack:(NSString *)track byArtist:(NSString *)artist toPlaylist:(int)playlist;
- (NSDictionary *)createPlaylist:(NSString *)title;

@end