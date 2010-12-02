/* LastFMService.m - AudioScrobbler webservice proxy
 * 
 * Copyright 2009 Last.fm Ltd.
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
#import "LastFMService.h"
#import "NSString+MD5.h"
#import "NSString+URLEscaped.h"
#import "MobileLastFMApplicationDelegate.h"
#include "version.h"

@implementation NSURLRequest(LastFMCertificateHack)

+ (BOOL)allowsAnyHTTPSCertificateForHost:(NSString *)host {
	if([host hasSuffix:@".audioscrobbler.com"])
		return YES;
	else
		return NO;
}

@end

@interface CXMLNode (objectAtXPath)
-(id)objectAtXPath:(NSString *)XPath;
@end

@implementation CXMLNode (objectAtXPath)
-(id)objectAtXPath:(NSString *)XPath {
	NSError *err;
	NSArray *nodes = [self nodesForXPath:XPath error:&err];
	if([nodes count]) {
		NSMutableArray *strings = [[NSMutableArray alloc] init];
		for(CXMLNode *node in nodes) {
			if([node stringValue])
				[strings addObject:[[node stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
		}
		if([strings count] == 1) {
			NSString *output = [NSString stringWithString:[strings objectAtIndex:0]];
			[strings release];
			return output;
		} else if([strings count] > 1) {
			return [strings autorelease];
		} else {
			[strings release];
			return @"";
		}
	} else {
		return @"";
	}
}
@end

BOOL shouldUseCache(NSString *file, double seconds) {
	NSDate *age = [[[NSFileManager defaultManager] fileAttributesAtPath:file traverseLink:YES] objectForKey:NSFileModificationDate];
	if(age==nil) return NO;
	if(([age timeIntervalSinceNow] * -1) > seconds && [((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) hasNetworkConnection]) {
		[[NSFileManager defaultManager] removeItemAtPath:file error:NULL];
		return NO;
	} else
		return YES;
}

@implementation LastFMService
@synthesize session;
@synthesize error;

+ (LastFMService *)sharedInstance {
  static LastFMService *sharedInstance;
	
  @synchronized(self) {
    if(!sharedInstance)
      sharedInstance = [[LastFMService alloc] init];
		
    return sharedInstance;
  }
	return nil;
}
- (NSArray *)_doMethod:(NSString *)method maxCacheAge:(double)seconds XPath:(NSString *)XPath withParams:(NSArray *)params {
	NSData *theResponseData;
	NSURLResponse *theResponse = NULL;
	NSError *theError = NULL;

	[error release];
	error = nil;
	
	NSArray *sortedParams = [[params arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:[NSString stringWithFormat:@"method=%@",method],session?[NSString stringWithFormat:@"sk=%@",session]:nil,nil]] sortedArrayUsingSelector:@selector(compare:)];
	NSMutableString *signature = [[NSMutableString alloc] init];
	for(NSString *param in sortedParams) {
		[signature appendString:[[param stringByReplacingOccurrencesOfString:@"=" withString:@""] unURLEscape]];
	}
	[signature appendString:[NSString stringWithFormat:@"%s", API_SECRET]];
	if(seconds && shouldUseCache(CACHE_FILE([signature md5sum]),seconds)) {
		theResponseData = [NSData dataWithContentsOfFile:CACHE_FILE([signature md5sum])];
	} else if([((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) hasNetworkConnection]) {
		[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
		NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%s", API_URL]] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) hasWiFiConnection]?40:60];
		[theRequest setValue:kUserAgent forHTTPHeaderField:@"User-Agent"];
		[theRequest setHTTPMethod:@"POST"];
		[theRequest setHTTPBody:[[NSString stringWithFormat:@"%@&api_sig=%@", [sortedParams componentsJoinedByString:@"&"], [signature md5sum]] dataUsingEncoding:NSUTF8StringEncoding]];
		//NSLog(@"method: %@ : params: %@", method, [NSString stringWithFormat:@"%@&api_sig=%@", [sortedParams componentsJoinedByString:@"&"], [signature md5sum]]);
		
		theResponseData = [NSURLConnection sendSynchronousRequest:theRequest returningResponse:&theResponse error:&theError];
		if(seconds)
			[theResponseData writeToFile:CACHE_FILE([signature md5sum]) atomically:YES];
		[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	} else {
		error = [[NSError alloc] initWithDomain:NSURLErrorDomain code:0 userInfo:nil];
		[signature release];
		return nil;
	}
	[signature release];
	
	if(theError) {
		error = [theError retain];
		return nil;
	}
	
	//NSLog(@"Response: %s\n", [theResponseData bytes]);
	
	CXMLDocument *d = [[[CXMLDocument alloc] initWithData:theResponseData options:0 error:&theError] autorelease];
	if(theError) {
		error = [theError retain];
		return nil;
	}
	
	NSArray *output = [[d rootElement] nodesForXPath:XPath error:&theError];
	if(![[[d rootElement] objectAtXPath:@"./@status"] isEqualToString:@"ok"]) {
		error = [[NSError alloc] initWithDomain:LastFMServiceErrorDomain
																			 code:[[[d rootElement] objectAtXPath:@"./error/@code"] intValue]
																	 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[[d rootElement] objectAtXPath:@"./error"],NSLocalizedDescriptionKey,nil]];
		NSLog(@"%@", error);
		return nil;
	}
	return output;
}
- (NSArray *)doMethod:(NSString *)method maxCacheAge:(double)seconds XPath:(NSString *)XPath withParameters:(NSString *)firstParam, ... {
	NSMutableArray *params = [[NSMutableArray alloc] init];
	NSArray *output = nil;
	id eachParam;
	va_list argumentList;
	
	if(firstParam) {
		[params addObject: firstParam];
		va_start(argumentList, firstParam);
		while (eachParam = va_arg(argumentList, id)) {
			[params addObject: eachParam];
		}
		va_end(argumentList);
  }
	
	[params addObject:[NSString stringWithFormat:@"api_key=%s", API_KEY]];
	
	output = [self _doMethod:method maxCacheAge:seconds XPath:XPath withParams:params];
	[params release];
	return output;
}
- (NSDictionary *)_convertNode:(CXMLNode *)node toDictionaryWithXPaths:(NSArray *)XPaths forKeys:(NSArray *)keys {
	NSDictionary *map = [NSDictionary dictionaryWithObjects:XPaths forKeys:keys];
	NSMutableArray *objects = [[NSMutableArray alloc] init];
	
	for(NSString *key in keys) {
		NSString *xpath = [map objectForKey:key];
		[objects addObject:[node objectAtXPath:xpath]];
	}
	
	NSDictionary *output = [NSDictionary dictionaryWithObjects:objects forKeys:keys];
	[objects release];
	return output;
}
- (NSArray *)_convertNodes:(NSArray *)nodes toArrayWithXPaths:(NSArray *)XPaths forKeys:(NSArray *)keys {
	NSMutableArray *output = nil;
	if([nodes count]) {
		output = [[[NSMutableArray alloc] init] autorelease];
		for(CXMLNode *node in nodes) {
			[output addObject:[self _convertNode:node 
										toDictionaryWithXPaths:XPaths
																	 forKeys:keys]];
		}
	}
	return output;
}

#pragma mark Artist methods

- (NSDictionary *)metadataForArtist:(NSString *)artist inLanguage:(NSString *)lang {
	NSDictionary *metadata = nil;
	NSArray *nodes = [self doMethod:@"artist.getInfo" maxCacheAge:7*DAYS XPath:@"./artist" withParameters:[NSString stringWithFormat:@"artist=%@", [artist URLEscaped]], 
										[NSString stringWithFormat:@"username=%@", [[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] URLEscaped]], nil];
	if([nodes count]) {
		CXMLNode *node = [nodes objectAtIndex:0];
		metadata = [self _convertNode:node
					 toDictionaryWithXPaths:[NSArray arrayWithObjects:@"./name", @"./image[@size=\"large\"]", @"./bio/summary", @"./bio/content", @"./stats/listeners", @"./stats/playcount", @"./stats/userplaycount", nil]
													forKeys:[NSArray arrayWithObjects:@"name", @"image", @"summary", @"bio", @"listeners", @"playcount", @"userplaycount", nil]];
	}
	return metadata;
}
- (NSArray *)eventsForArtist:(NSString *)artist {
	NSArray *nodes = [self doMethod:@"artist.getEvents" maxCacheAge:1*DAYS XPath:@"./events/event" withParameters:[NSString stringWithFormat:@"artist=%@", [artist URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./id", @"./artists/headliner", @"./artists/artist", @"./title", @"./description", @"./venue/name", @"./venue/location/street", @"./venue/location/city", @"./venue/location/postalcode", @"./venue/location/country", @"./startDate", @"./image[@size=\"medium\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"id", @"headliner", @"artists", @"title", @"description", @"venue", @"street", @"city", @"postalcode", @"country", @"startDate", @"image", nil]];
}
- (NSArray *)artistsSimilarTo:(NSString *)artist {
	NSArray *nodes = [self doMethod:@"artist.getSimilar" maxCacheAge:7*DAYS XPath:@"./similarartists/artist" withParameters:[NSString stringWithFormat:@"artist=%@", [artist URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./match", @"./image[@size=\"medium\"]", @"./streamable", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"match", @"image", @"streamable", nil]];
}
- (NSArray *)searchForArtist:(NSString *)artist {
	NSArray *nodes = [self doMethod:@"artist.search" maxCacheAge:1*HOURS XPath:@"./results/artistmatches/artist" withParameters:[NSString stringWithFormat:@"artist=%@", [artist URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./streamable", @"./image[@size=\"medium\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"streamable", @"image", nil]];
}
- (NSArray *)topTagsForArtist:(NSString *)artist {
	NSArray *nodes = [self doMethod:@"artist.getTopTags" maxCacheAge:7*DAYS XPath:@"./toptags/tag" withParameters:[NSString stringWithFormat:@"artist=%@", [artist URLEscaped]],nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./count", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"count", nil]];
}
- (void)addTags:(NSArray *)tags toArtist:(NSString *)artist {
	[self doMethod:@"artist.addTags" maxCacheAge:0 XPath:@"." withParameters:[NSString stringWithFormat:@"artist=%@", [artist URLEscaped]],
	 [NSString stringWithFormat:@"tags=%@", [[tags componentsJoinedByString:@","] URLEscaped]], nil];
}
- (void)removeTag:(NSString *)tag fromArtist:(NSString *)artist {
	[self doMethod:@"artist.removeTag" maxCacheAge:0 XPath:@"." withParameters:[NSString stringWithFormat:@"artist=%@", [artist URLEscaped]],
	 [NSString stringWithFormat:@"tag=%@", [tag URLEscaped]], nil];
}
- (NSArray *)tagsForArtist:(NSString *)artist {
	NSArray *nodes = [self doMethod:@"artist.getTags" maxCacheAge:0 XPath:@"./tags/tag" withParameters:[NSString stringWithFormat:@"artist=%@", [artist URLEscaped]],nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", nil]];
}
- (NSArray *)topTracksForArtist:(NSString *)artist {
	NSArray *nodes = [self doMethod:@"artist.getTopTracks" maxCacheAge:5*MINUTES XPath:@"./toptracks/track" withParameters:[NSString stringWithFormat:@"artist=%@", [artist URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./playcount", @"./image[@size=\"medium\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"playcount", @"image", nil]];
}

#pragma mark Album methods

- (NSDictionary *)metadataForAlbum:(NSString *)album byArtist:(NSString *)artist inLanguage:(NSString *)lang {
	NSDictionary *metadata = nil;
	NSArray *nodes = [self doMethod:@"album.getInfo" maxCacheAge:7*DAYS XPath:@"./album" withParameters:[NSString stringWithFormat:@"album=%@", [album URLEscaped]], 
										[NSString stringWithFormat:@"artist=%@", [artist URLEscaped]],
										[NSString stringWithFormat:@"username=%@", [[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] URLEscaped]], nil];
	if([nodes count]) {
		CXMLNode *node = [nodes objectAtIndex:0];
		metadata = [self _convertNode:node
					 toDictionaryWithXPaths:[NSArray arrayWithObjects:@"./name", @"./artist", @"./releasedate", @"./userplaycount", @"./image[@size=\"extralarge\"]", nil]
													forKeys:[NSArray arrayWithObjects:@"name", @"artist", @"releasedate", @"userplaycount", @"image", nil]];
	}
	return metadata;
}
- (NSArray *)tracksForAlbum:(NSString *)album byArtist:(NSString *)artist {
	NSArray *nodes = [self doMethod:@"album.getInfo" maxCacheAge:7*DAYS XPath:@"./album/tracks/track" withParameters:[NSString stringWithFormat:@"album=%@", [album URLEscaped]], [NSString stringWithFormat:@"artist=%@", [artist URLEscaped]],nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./artist/name", @"./image[@size=\"medium\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"artist", @"image", nil]];
}
- (NSArray *)topTagsForAlbum:(NSString *)album byArtist:(NSString *)artist {
	NSArray *nodes = [self doMethod:@"album.getTopTags" maxCacheAge:7*DAYS XPath:@"./toptags/tag" withParameters:[NSString stringWithFormat:@"album=%@", [album URLEscaped]], [NSString stringWithFormat:@"artist=%@", [artist URLEscaped]],nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./count", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"count", nil]];
}
- (void)addTags:(NSArray *)tags toAlbum:(NSString *)album byArtist:(NSString *)artist {
	[self doMethod:@"album.addTags" maxCacheAge:0 XPath:@"." withParameters:[NSString stringWithFormat:@"album=%@", [album URLEscaped]], [NSString stringWithFormat:@"artist=%@", [artist URLEscaped]],
	 [NSString stringWithFormat:@"tags=%@", [[tags componentsJoinedByString:@","] URLEscaped]], nil];
}
- (void)removeTag:(NSString *)tag fromAlbum:(NSString *)album byArtist:(NSString *)artist {
	[self doMethod:@"album.removeTag" maxCacheAge:0 XPath:@"." withParameters:[NSString stringWithFormat:@"album=%@", [album URLEscaped]], [NSString stringWithFormat:@"artist=%@", [artist URLEscaped]],
	 [NSString stringWithFormat:@"tag=%@", [tag URLEscaped]], nil];
}
- (NSArray *)tagsForAlbum:(NSString *)album byArtist:(NSString *)artist {
	NSArray *nodes = [self doMethod:@"album.getTags" maxCacheAge:0 XPath:@"./tags/tag" withParameters:[NSString stringWithFormat:@"album=%@", [album URLEscaped]], [NSString stringWithFormat:@"artist=%@", [artist URLEscaped]],nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", nil]];
}
- (NSArray *)topAlbumsForArtist:(NSString *)artist {
	NSArray *nodes = [self doMethod:@"artist.getTopAlbums" maxCacheAge:5*MINUTES XPath:@"./topalbums/album" withParameters:[NSString stringWithFormat:@"artist=%@", [artist URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./playcount", @"./artist/name", @"./image[@size=\"medium\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"playcount", @"artist", @"image", nil]];
}

#pragma mark Track methods

- (NSDictionary *)metadataForTrack:(NSString *)track byArtist:(NSString *)artist inLanguage:(NSString *)lang {
	NSDictionary *metadata = nil;
	NSArray *nodes = [self doMethod:@"track.getInfo" maxCacheAge:7*DAYS XPath:@"./track" withParameters:[NSString stringWithFormat:@"track=%@", [track URLEscaped]], 
										[NSString stringWithFormat:@"artist=%@", [artist URLEscaped]],
										[NSString stringWithFormat:@"username=%@", [[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] URLEscaped]], nil];
	if([nodes count]) {
		CXMLNode *node = [nodes objectAtIndex:0];
		metadata = [self _convertNode:node
					 toDictionaryWithXPaths:[NSArray arrayWithObjects:@"./name", @"./artist/name", @"./duration", @"./userplaycount", @"./wiki/summary", @"./album/image[@size=\"extralarge\"]", nil]
													forKeys:[NSArray arrayWithObjects:@"name", @"artist", @"duration", @"userplaycount", @"wiki", @"image", nil]];
	}
	return metadata;
}
- (void)loveTrack:(NSString *)title byArtist:(NSString *)artist {
	[self doMethod:@"track.love" maxCacheAge:0 XPath:@"." withParameters:[NSString stringWithFormat:@"track=%@", [title URLEscaped]], [NSString stringWithFormat:@"artist=%@", [artist URLEscaped]], nil];
}
- (void)banTrack:(NSString *)title byArtist:(NSString *)artist {
	[self doMethod:@"track.ban" maxCacheAge:0 XPath:@"." withParameters:[NSString stringWithFormat:@"track=%@", [title URLEscaped]], [NSString stringWithFormat:@"artist=%@", [artist URLEscaped]], nil];
}
- (NSArray *)fansOfTrack:(NSString *)track byArtist:(NSString *)artist {
	NSArray *nodes = [self doMethod:@"track.getTopFans" maxCacheAge:7*DAYS XPath:@"./topfans/user" withParameters:[NSString stringWithFormat:@"track=%@", [track URLEscaped]], [NSString stringWithFormat:@"artist=%@", [artist URLEscaped]],nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./weight", @"./image[@size=\"medium\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"username", @"weight", @"image", nil]];
}
- (NSArray *)topTagsForTrack:(NSString *)track byArtist:(NSString *)artist {
	NSArray *nodes = [self doMethod:@"track.getTopTags" maxCacheAge:7*DAYS XPath:@"./toptags/tag" withParameters:[NSString stringWithFormat:@"track=%@", [track URLEscaped]], [NSString stringWithFormat:@"artist=%@", [artist URLEscaped]],nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./count", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"count", nil]];
}
- (void)recommendTrack:(NSString *)track byArtist:(NSString *)artist toEmailAddress:(NSString *)emailAddress {
	[self doMethod:@"track.share" maxCacheAge:0 XPath:@"." withParameters:[NSString stringWithFormat:@"track=%@", [track URLEscaped]],
	 [NSString stringWithFormat:@"artist=%@", [artist URLEscaped]],
	 [NSString stringWithFormat:@"recipient=%@", [emailAddress URLEscaped]],
	 nil];
}
- (void)addTags:(NSArray *)tags toTrack:(NSString *)track byArtist:(NSString *)artist {
	[self doMethod:@"track.addTags" maxCacheAge:0 XPath:@"." withParameters:[NSString stringWithFormat:@"track=%@", [track URLEscaped]], [NSString stringWithFormat:@"artist=%@", [artist URLEscaped]],
	 [NSString stringWithFormat:@"tags=%@", [[tags componentsJoinedByString:@","] URLEscaped]], nil];
}
- (void)removeTag:(NSString *)tag fromTrack:(NSString *)track byArtist:(NSString *)artist {
	[self doMethod:@"track.removeTag" maxCacheAge:0 XPath:@"." withParameters:[NSString stringWithFormat:@"track=%@", [track URLEscaped]], [NSString stringWithFormat:@"artist=%@", [artist URLEscaped]],
	 [NSString stringWithFormat:@"tag=%@", [tag URLEscaped]], nil];
}
- (NSArray *)tagsForTrack:(NSString *)track byArtist:(NSString *)artist {
	NSArray *nodes = [self doMethod:@"track.getTags" maxCacheAge:0 XPath:@"./tags/tag" withParameters:[NSString stringWithFormat:@"track=%@", [track URLEscaped]], [NSString stringWithFormat:@"artist=%@", [artist URLEscaped]],nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", nil]];
}

#pragma mark User methods

- (void)createUser:(NSString *)username withPassword:(NSString *)password andEmail:(NSString *)email {
	[self doMethod:@"user.signUp" maxCacheAge:0 XPath:@"." withParameters:[NSString stringWithFormat:@"username=%@", [username URLEscaped]],
	 [NSString stringWithFormat:@"password=%@", [password URLEscaped]],
	 [NSString stringWithFormat:@"email=%@", [email URLEscaped]],
	 nil];
}
- (NSDictionary *)getMobileSessionForUser:(NSString *)username password:(NSString *)password {
	NSString *authToken = [[NSString stringWithFormat:@"%@%@", [username lowercaseString], [password md5sum]] md5sum];
	NSArray *nodes = [self doMethod:@"auth.getMobileSession" maxCacheAge:0 XPath:@"./session" withParameters:[NSString stringWithFormat:@"username=%@", [[username lowercaseString] URLEscaped]], [NSString stringWithFormat:@"authToken=%@", [authToken URLEscaped]], nil];
	if([nodes count])
		return [self _convertNode:[nodes objectAtIndex:0]
			 toDictionaryWithXPaths:[NSArray arrayWithObjects:@"./key", @"./subscriber", nil]
											forKeys:[NSArray arrayWithObjects:@"key", @"subscriber", nil]];
	else
		return nil;
}
- (NSArray *)topArtistsForUser:(NSString *)username {
	NSArray *nodes = [self doMethod:@"user.getTopArtists" maxCacheAge:5*MINUTES XPath:@"./topartists/artist" withParameters:[NSString stringWithFormat:@"user=%@", [username URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./playcount", @"./streamable", @"./image[@size=\"medium\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"playcount", @"streamable", @"image", nil]];
}
- (NSArray *)weeklyArtistsForUser:(NSString *)username {
	NSArray *nodes = [self doMethod:@"user.getWeeklyArtistChart" maxCacheAge:5*MINUTES XPath:@"./weeklyartistchart/artist" withParameters:[NSString stringWithFormat:@"user=%@", [username URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./playcount", @"./streamable", @"./image[@size=\"medium\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"playcount", @"streamable", @"image", nil]];
}
- (NSArray *)recommendedArtistsForUser:(NSString *)username {
	NSArray *nodes = [self doMethod:@"user.getRecommendedArtists" maxCacheAge:5*MINUTES XPath:@"./recommendations/artist" withParameters:[NSString stringWithFormat:@"user=%@", [username URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./playcount", @"./streamable", @"./image[@size=\"medium\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"playcount", @"streamable", @"image", nil]];
}
- (NSArray *)recommendedReleasesForUser:(NSString *)username {
	NSArray *nodes = [self doMethod:@"user.getNewReleases" maxCacheAge:5*MINUTES XPath:@"./albums/album" withParameters:[NSString stringWithFormat:@"user=%@", [username URLEscaped]], @"userecs=1", nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./playcount", @"./artist/name", @"./image[@size=\"medium\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"playcount", @"artist", @"image", nil]];
}
- (NSArray *)releasesForUser:(NSString *)username {
	NSArray *nodes = [self doMethod:@"user.getNewReleases" maxCacheAge:5*MINUTES XPath:@"./albums/album" withParameters:[NSString stringWithFormat:@"user=%@", [username URLEscaped]], @"userecs=0", nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./playcount", @"./artist/name", @"./image[@size=\"medium\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"playcount", @"artist", @"image", nil]];
}
- (NSArray *)topAlbumsForUser:(NSString *)username {
	NSArray *nodes = [self doMethod:@"user.getTopAlbums" maxCacheAge:5*MINUTES XPath:@"./topalbums/album" withParameters:[NSString stringWithFormat:@"user=%@", [username URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./playcount", @"./artist/name", @"./image[@size=\"medium\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"playcount", @"artist", @"image", nil]];
}
- (NSArray *)topTracksForUser:(NSString *)username {
	NSArray *nodes = [self doMethod:@"user.getTopTracks" maxCacheAge:5*MINUTES XPath:@"./toptracks/track" withParameters:[NSString stringWithFormat:@"user=%@", [username URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./playcount", @"./artist/name", @"./image[@size=\"medium\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"playcount", @"artist", @"image", nil]];
}
- (NSArray *)tagsForUser:(NSString *)username {
	NSArray *nodes = [self doMethod:@"user.getTopTags" maxCacheAge:0 XPath:@"./toptags/tag" withParameters:[NSString stringWithFormat:@"user=%@", [username URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./count", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"count", nil]];
}
- (NSArray *)playlistsForUser:(NSString *)username {
	NSArray *nodes = [self doMethod:@"user.getPlaylists" maxCacheAge:0 XPath:@"./playlists/playlist" withParameters:[NSString stringWithFormat:@"user=%@", [username URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./id", @"./title", @"./size", @"./streamable", nil]
										 forKeys:[NSArray arrayWithObjects:@"id", @"title", @"size", @"streamable", nil]];
}
- (NSArray *)recentlyPlayedTracksForUser:(NSString *)username {
	NSArray *nodes = [self doMethod:@"user.getRecentTracks" maxCacheAge:0 XPath:@"./recenttracks/track" withParameters:[NSString stringWithFormat:@"user=%@", [username URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./artist/name", @"./name", @"./date", @"./image[@size=\"medium\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"artist", @"name", @"date", @"image", nil]];
}
- (NSArray *)friendsOfUser:(NSString *)username {
	NSArray *nodes = [self doMethod:@"user.getFriends" maxCacheAge:0 XPath:@"./friends/user" withParameters:[NSString stringWithFormat:@"user=%@", [username URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./image[@size=\"medium\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"username", @"image", nil]];
}
- (NSArray *)eventsForUser:(NSString *)username {
	NSArray *nodes = [self doMethod:@"user.getEvents" maxCacheAge:0 XPath:@"./events/event" withParameters:[NSString stringWithFormat:@"user=%@", [username URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./@status", @"./id", @"./artists/headliner", @"./artists/artist", @"./title", @"./description", @"./venue/name", @"./venue/location/street", @"./venue/location/city", @"./venue/location/postalcode", @"./venue/location/country", @"./venue/website", @"./venue/phonenumber", @"./startDate", @"./image[@size=\"medium\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"status", @"id", @"headliner", @"artists", @"title", @"description", @"venue", @"street", @"city", @"postalcode", @"country", @"website", @"phonenumber", @"startDate", @"image", nil]];
}
- (NSArray *)recommendedEventsForUser:(NSString *)username {
	NSArray *nodes = [self doMethod:@"user.getRecommendedEvents" maxCacheAge:0 XPath:@"./events/event" withParameters:[NSString stringWithFormat:@"user=%@", [username URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./@status", @"./id", @"./artists/headliner", @"./artists/artist", @"./title", @"./description", @"./venue/name", @"./venue/location/street", @"./venue/location/city", @"./venue/location/postalcode", @"./venue/location/country", @"./venue/website", @"./venue/phonenumber", @"./startDate", @"./image[@size=\"medium\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"status", @"id", @"headliner", @"artists", @"title", @"description", @"venue", @"street", @"city", @"postalcode", @"country", @"website", @"phonenumber", @"startDate", @"image", nil]];
}
- (NSArray *)eventsForLatitude:(float)latitude longitude:(float)longitude radius:(int)radius {
	NSArray *nodes = [self doMethod:@"geo.getEvents" maxCacheAge:0 XPath:@"./events/event" withParameters:[NSString stringWithFormat:@"lat=%f", latitude], [NSString stringWithFormat:@"long=%f", longitude], [NSString stringWithFormat:@"distance=%i", radius], nil];
	return [self _convertNodes:nodes
				 toArrayWithXPaths:[NSArray arrayWithObjects:@"./@status", @"./id", @"./artists/headliner", @"./artists/artist", @"./title", @"./description", @"./venue/name", @"./venue/location/street", @"./venue/location/city", @"./venue/location/postalcode", @"./venue/location/country", @"./venue/website", @"./venue/phonenumber", @"./startDate", @"./image[@size=\"medium\"]", nil]
									 forKeys:[NSArray arrayWithObjects:@"status", @"id", @"headliner", @"artists", @"title", @"description", @"venue", @"street", @"city", @"postalcode", @"country", @"website", @"phonenumber", @"startDate", @"image", nil]];
}
- (NSDictionary *)profileForUser:(NSString *)username {
	NSDictionary *metadata = nil;
	NSError *theError = nil;
	NSData *theResponseData = [NSData dataWithContentsOfURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://ws.audioscrobbler.com/1.0/user/%@/profile.xml", [username URLEscaped]]]];
	CXMLDocument *d = [[[CXMLDocument alloc] initWithData:theResponseData options:0 error:&theError] autorelease];
	if(theError) {
		error = [theError retain];
		return nil;
	}
	
	metadata = [NSDictionary dictionaryWithObjectsAndKeys:
							[[d rootElement] objectAtXPath:@"./realname"], @"realname",
							[[d rootElement] objectAtXPath:@"./registered"], @"registered",
							[[d rootElement] objectAtXPath:@"./age"], @"age",
							[[d rootElement] objectAtXPath:@"./gender"], @"gender",
							[[d rootElement] objectAtXPath:@"./country"], @"country",
							[[d rootElement] objectAtXPath:@"./playcount"], @"playcount",
							[[d rootElement] objectAtXPath:@"./avatar"], @"avatar",
							[[d rootElement] objectAtXPath:@"./icon"], @"icon",
							nil
							];
	return metadata;
}

- (NSDictionary *)compareArtistsOfUser:(NSString *)username withUser:(NSString *)username2 {
	NSDictionary *metadata = nil;
	NSArray *nodes = [self doMethod:@"tasteometer.compare" maxCacheAge:0 XPath:@"./comparison" withParameters:@"type1=user", [NSString stringWithFormat:@"value1=%@", [username URLEscaped]], @"type2=user", [NSString stringWithFormat:@"value2=%@", [username2 URLEscaped]], nil];
	if([nodes count]) {
		CXMLNode *node = [nodes objectAtIndex:0];
		metadata = [self _convertNode:node
					 toDictionaryWithXPaths:[NSArray arrayWithObjects:@"./result/score", @"./result/artists/artist/name", nil]
													forKeys:[NSArray arrayWithObjects:@"score", @"artists", nil]];
	}
	return metadata;
}

- (NSArray *)recentStationsForUser:(NSString *)username {
	NSArray *nodes = [self doMethod:@"user.getRecentStations" maxCacheAge:0 XPath:@"./recentstations/station" withParameters:[NSString stringWithFormat:@"user=%@", [username URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./url", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"url", nil]];
}

#pragma mark Tag methods

- (NSDictionary *)metadataForTag:(NSString *)tag inLanguage:(NSString *)lang {
	NSDictionary *metadata = nil;
	NSArray *nodes = [self doMethod:@"tag.getInfo" maxCacheAge:7*DAYS XPath:@"./tag" withParameters:[NSString stringWithFormat:@"tag=%@", [tag URLEscaped]], 
										[NSString stringWithFormat:@"username=%@", [[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] URLEscaped]], nil];
	if([nodes count]) {
		CXMLNode *node = [nodes objectAtIndex:0];
		metadata = [self _convertNode:node
					 toDictionaryWithXPaths:[NSArray arrayWithObjects:@"./name", @"./wiki/summary", @"./taggings", nil]
													forKeys:[NSArray arrayWithObjects:@"name", @"wiki", @"taggings", nil]];
	}
	return metadata;
}
- (NSArray *)tagsSimilarTo:(NSString *)tag {
	NSArray *nodes = [self doMethod:@"tag.getSimilar" maxCacheAge:7*DAYS XPath:@"./similartags/tag" withParameters:[NSString stringWithFormat:@"tag=%@", [tag URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./streamable", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"streamable", nil]];
}
- (NSArray *)searchForTag:(NSString *)tag {
	NSArray *nodes = [self doMethod:@"tag.search" maxCacheAge:1*HOURS XPath:@"./results/tagmatches/tag" withParameters:[NSString stringWithFormat:@"tag=%@", [tag URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", nil]];
}
- (NSArray *)topArtistsForTag:(NSString *)tag {
	NSArray *nodes = [self doMethod:@"tag.getTopArtists" maxCacheAge:7*DAYS XPath:@"./topartists/artist" withParameters:[NSString stringWithFormat:@"tag=%@", [tag URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./streamable", @"./image[@size=\"medium\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"streamable", @"image", nil]];
}
- (NSArray *)topAlbumsForTag:(NSString *)tag {
	NSArray *nodes = [self doMethod:@"tag.getTopAlbums" maxCacheAge:5*MINUTES XPath:@"./topalbums/album" withParameters:[NSString stringWithFormat:@"tag=%@", [tag URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./playcount", @"./artist/name", @"./image[@size=\"medium\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"playcount", @"artist", @"image", nil]];
}
- (NSArray *)topTracksForTag:(NSString *)tag {
	NSArray *nodes = [self doMethod:@"tag.getTopTracks" maxCacheAge:5*MINUTES XPath:@"./toptracks/track" withParameters:[NSString stringWithFormat:@"tag=%@", [tag URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./playcount", @"./artist/name", @"./image[@size=\"medium\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"playcount", @"artist", @"image", nil]];
}

#pragma mark Radio methods

- (NSDictionary *)tuneRadioStation:(NSString *)stationURL {
	NSDictionary *station = nil;
	NSArray *nodes = [self doMethod:@"radio.tune" maxCacheAge:0 XPath:@"./station" withParameters:[NSString stringWithFormat:@"station=%@", [stationURL URLEscaped]], [NSString stringWithFormat:@"rtp=%i", [[[NSUserDefaults standardUserDefaults] objectForKey:@"scrobbling"] isEqualToString:@"YES"]], nil];
	if([nodes count]) {
		CXMLNode *node = [nodes objectAtIndex:0];
		station = [self _convertNode:node
					toDictionaryWithXPaths:[NSArray arrayWithObjects:@"./name", @"./type", nil]
												 forKeys:[NSArray arrayWithObjects:@"name", @"type", nil]];
	}
	return station;
}
- (NSDictionary *)getPlaylist {
	NSMutableArray *playlist = nil;
	NSString *bitrate;
	NSString *network;
	NSString *speed;
	
	if([((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) hasWiFiConnection]) {
		network = @"wifi";
		bitrate = @"128";
		speed = @"2";
	} else {
		network = @"wwan";
		bitrate = [[NSUserDefaults standardUserDefaults] objectForKey:@"bitrate"];
		speed = @"2";
	}
	
	NSArray *nodes = [[[[[self doMethod:@"radio.getPlaylist" maxCacheAge:0 XPath:@"." withParameters:
												[NSString stringWithFormat:@"mobile_net=%@",network],
												[NSString stringWithFormat:@"bitrate=%@", bitrate],
												[NSString stringWithFormat:@"speed_multiplier=%@", speed],
												nil] objectAtIndex:0] children] objectAtIndex:1] children];
	NSString *title = nil;
	
	if([nodes count]) {
		for(CXMLNode *node in nodes) {
			if([[node name] isEqualToString:@"trackList"] && [[node children] count]) {
				playlist = [[[NSMutableArray alloc] init] autorelease];
				
				for(CXMLNode *tracklistNode in [node children]) {
					if([[tracklistNode name] isEqualToString:@"track"]) {
						NSArray *trackNodes = [tracklistNode children];
						NSEnumerator *trackMembers = [trackNodes objectEnumerator];
						CXMLNode *trackNode = nil;
						NSMutableDictionary *track = [[NSMutableDictionary alloc] init];
						
						while ((trackNode = [trackMembers nextObject])) {
							if([[trackNode name] isEqualToString:@"extension"]) {
								for(CXMLNode *extNode in [trackNode children]) {
									if([extNode stringValue])
										[track setObject:[extNode stringValue] forKey:[extNode name]];
								}
							} else if([trackNode stringValue])
								[track setObject:[trackNode stringValue] forKey:[trackNode name]];
						}
						
						[playlist addObject:track];
						[track release];
					}
				}
			} else if([[node name] isEqualToString:@"title"] && [node stringValue]) {
				NSMutableString *station = [NSMutableString stringWithString:[node stringValue]];
				[station replaceOccurrencesOfString:@"+" withString:@" " options:NSLiteralSearch range:NSMakeRange(0, [station length])];
				[station replaceOccurrencesOfString:@"-" withString:@" " options:NSLiteralSearch range:NSMakeRange(0, [station length])];
				title = [(NSString *)CFURLCreateStringByReplacingPercentEscapes(NULL,(CFStringRef)[station stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]],CFSTR("")) autorelease];
			}
		}
		return [NSDictionary dictionaryWithObjectsAndKeys:playlist,@"playlist",title,@"title",nil]; 
	} else {
		return nil;
	}
}

#pragma mark Event methods

- (void)attendEvent:(int)event status:(int)status {
	[self doMethod:@"event.attend" maxCacheAge:0 XPath:@"." withParameters:[NSString stringWithFormat:@"event=%i", event], [NSString stringWithFormat:@"status=%i", status], nil];
}

#pragma mark Playlist methods

- (void)addTrack:(NSString *)track byArtist:(NSString *)artist toPlaylist:(int)playlist {
	[self doMethod:@"playlist.addTrack" maxCacheAge:0 XPath:@"." withParameters:[NSString stringWithFormat:@"track=%@", [track URLEscaped]], [NSString stringWithFormat:@"artist=%@", [artist URLEscaped]], [NSString stringWithFormat:@"playlistID=%i", playlist], nil];
}
- (NSDictionary *)createPlaylist:(NSString *)title {
	NSDictionary *playlist = nil;
	NSArray *nodes = [self doMethod:@"playlist.create" maxCacheAge:0 XPath:@"./playlists/playlist" withParameters:[NSString stringWithFormat:@"title=%@", [title URLEscaped]], @"description=", nil];
	if([nodes count]) {
		CXMLNode *node = [nodes objectAtIndex:0];
		playlist = [self _convertNode:node
					 toDictionaryWithXPaths:[NSArray arrayWithObjects:@"./id", @"./title", nil]
													forKeys:[NSArray arrayWithObjects:@"id", @"title", nil]];
	}
	return playlist;
}

@end
