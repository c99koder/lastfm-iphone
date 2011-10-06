/* LastFMService.m - AudioScrobbler webservice proxy
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
	NSDate *age = [[[NSFileManager defaultManager] attributesOfItemAtPath:file error:nil] objectForKey:NSFileModificationDate];
	if(age==nil) return NO;
	if(([age timeIntervalSinceNow] * -1) > seconds && [((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) hasNetworkConnection]) {
		return NO;
	} else
		return YES;
}

@implementation LastFMService
@synthesize session;
@synthesize error;
@synthesize cacheOnly;

+ (LastFMService *)sharedInstance {
  static LastFMService *sharedInstance;
	
  @synchronized(self) {
    if(!sharedInstance)
      sharedInstance = [[LastFMService alloc] init];
		
    return sharedInstance;
  }
	return nil;
}
- (NSArray *)doGet:(NSString *)url maxCacheAge:(double)seconds XPath:(NSString *)XPath {
	NSData *theResponseData;
	NSURLResponse *theResponse = NULL;
	NSError *theError = NULL;
	
	[error release];
	error = nil;
	
	if((seconds && shouldUseCache(CACHE_FILE([url md5sum]),seconds)) || cacheOnly) {
		theResponseData = [NSData dataWithContentsOfFile:CACHE_FILE([url md5sum])];
	} else if([((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) hasNetworkConnection] && !cacheOnly) {
		[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
		NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) hasWiFiConnection]?40:60];
		[theRequest setValue:kUserAgent forHTTPHeaderField:@"User-Agent"];
		
		theResponseData = [NSURLConnection sendSynchronousRequest:theRequest returningResponse:&theResponse error:&theError];
		[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	} else {
		error = [[NSError alloc] initWithDomain:NSURLErrorDomain code:0 userInfo:nil];
		return nil;
	}
	
	if(theError) {
		error = [theError retain];
		return nil;
	}
	
	CXMLDocument *d = [[[CXMLDocument alloc] initWithData:theResponseData options:0 error:&theError] autorelease];
	
	if(theError) {
		error = [theError retain];
		return nil;
	}
	
	NSArray *output = [[d rootElement] nodesForXPath:XPath error:&theError];

	//Cache the response
	[theResponseData writeToFile:CACHE_FILE([url md5sum]) atomically:YES];
	
	return output;
}
- (NSArray *)_doMethod:(NSString *)method maxCacheAge:(double)seconds XPath:(NSString *)XPath withParams:(NSArray *)params authenticated:(BOOL)authenticated {
	NSData *theResponseData;
	NSURLResponse *theResponse = NULL;
	NSError *theError = NULL;

	[error release];
	error = nil;
	
	NSArray *sortedParams = [[params arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:[NSString stringWithFormat:@"method=%@",method],(session && authenticated)?[NSString stringWithFormat:@"sk=%@",session]:nil,nil]] sortedArrayUsingSelector:@selector(compare:)];
	NSMutableString *signature = [[[NSMutableString alloc] init] autorelease];
	for(NSString *param in sortedParams) {
		[signature appendString:[[param stringByReplacingOccurrencesOfString:@"=" withString:@""] unURLEscape]];
	}
	[signature appendString:[NSString stringWithFormat:@"%s", API_SECRET]];
	if((seconds && shouldUseCache(CACHE_FILE([signature md5sum]),seconds)) || cacheOnly) {
		theResponseData = [NSData dataWithContentsOfFile:CACHE_FILE([signature md5sum])];
	} else if([((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) hasNetworkConnection] && !cacheOnly) {
		[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
		NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%s", API_URL]] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) hasWiFiConnection]?40:60];
		[theRequest setValue:kUserAgent forHTTPHeaderField:@"User-Agent"];
		[theRequest setHTTPMethod:@"POST"];
		[theRequest setHTTPBody:[[NSString stringWithFormat:@"%@&api_sig=%@", [sortedParams componentsJoinedByString:@"&"], [signature md5sum]] dataUsingEncoding:NSUTF8StringEncoding]];
		//NSLog(@"+++ method: %@ : params: %@", method, [NSString stringWithFormat:@"%@&api_sig=%@", [sortedParams componentsJoinedByString:@"&"], [signature md5sum]]);
		
		theResponseData = [NSURLConnection sendSynchronousRequest:theRequest returningResponse:&theResponse error:&theError];
		[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	} else {
		error = [[NSError alloc] initWithDomain:NSURLErrorDomain code:0 userInfo:nil];
		return nil;
	}
	
	if(theError) {
		error = [theError retain];
		return nil;
	}
	
	//terrible namespace hax
	NSString *theXML = [[[[[NSString alloc] initWithBytes:[theResponseData bytes] length:[theResponseData length] encoding:NSUTF8StringEncoding] autorelease] stringByReplacingOccurrencesOfString:@"<geo:" withString:@"<"] stringByReplacingOccurrencesOfString:@"</geo:" withString:@"</"];

	//NSLog(@"--- (%@) Response: %@\n", method, theXML);
	
	CXMLDocument *d = [[[CXMLDocument alloc] initWithData:[theXML dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&theError] autorelease];
	
	if(theError) {
		error = [theError retain];
		return nil;
	}

	NSArray *output = [[d rootElement] nodesForXPath:XPath error:&theError];
	if(![[[d rootElement] objectAtXPath:@"./@status"] isEqualToString:@"ok"]) {
		error = [[NSError alloc] initWithDomain:LastFMServiceErrorDomain
																			 code:[[[d rootElement] objectAtXPath:@"./error/@code"] intValue]
																	 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[[d rootElement] objectAtXPath:@"./error"],NSLocalizedDescriptionKey,method,@"method",nil]];
#ifndef DISTRIBUTION
		if([error.userInfo objectForKey:NSLocalizedDescriptionKey])
			NSLog(@"%@", error);
#endif
		return nil;
	}
	//Cache the response
	[theResponseData writeToFile:CACHE_FILE([signature md5sum]) atomically:YES];

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
		while ((eachParam = va_arg(argumentList, id))) {
			[params addObject: eachParam];
		}
		va_end(argumentList);
  }
	
	[params addObject:[NSString stringWithFormat:@"api_key=%s", API_KEY]];
	
	output = [self _doMethod:method maxCacheAge:seconds XPath:XPath withParams:params authenticated:YES];
	[params release];
	return output;
}
- (NSArray *)doMethod:(NSString *)method maxCacheAge:(double)seconds XPath:(NSString *)XPath authenticated:(BOOL)authenticated withParameters:(NSString *)firstParam, ... {
	NSMutableArray *params = [[NSMutableArray alloc] init];
	NSArray *output = nil;
	id eachParam;
	va_list argumentList;
	
	if(firstParam) {
		[params addObject: firstParam];
		va_start(argumentList, firstParam);
		while ((eachParam = va_arg(argumentList, id))) {
			[params addObject: eachParam];
		}
		va_end(argumentList);
  }
	
	[params addObject:[NSString stringWithFormat:@"api_key=%s", API_KEY]];
	
	output = [self _doMethod:method maxCacheAge:seconds XPath:XPath withParams:params authenticated:authenticated];
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
	if([output objectForKey:@"startDate"]) {
		NSMutableDictionary *o = [[NSMutableDictionary alloc] initWithDictionary:output];
		NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
		[formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease]];
		[formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss"]; //"Fri, 21 Jan 2011 21:00:00"
		
		NSDate *date = [formatter dateFromString:[output objectForKey:@"startDate"]];
		[o setObject:date forKey:@"startNSDate"];
		output = [o autorelease];
		[formatter release];
	}
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

- (NSDictionary *)getSessionInfo {
	NSArray *nodes = [self doMethod:@"auth.getSessionInfo" maxCacheAge:0 XPath:@"./application" withParameters:nil];
	if([nodes count])
		return [self _convertNode:[nodes objectAtIndex:0]
			 toDictionaryWithXPaths:[NSArray arrayWithObjects:@"./session/subscriber", @"./country", 
															 @"./radioPermission/user[@type=\"you\"]/radio",
															 @"./radioPermission/user[@type=\"you\"]/freetrial",
															 @"./radioPermission/user[@type=\"you\"]/trial/expired", 
															 @"./radioPermission/user[@type=\"you\"]/trial/playsleft", 
															 @"./radioPermission/user[@type=\"you\"]/trial/playselapsed", 
															 nil]
											forKeys:[NSArray arrayWithObjects:@"subscriber", @"country", @"radio_enabled", @"trial_enabled", @"trial_expired", @"trial_playsleft", @"trial_playselapsed", nil]];
	else
		return nil;
}

- (NSDictionary *)getGeo {
	NSArray *nodes = [self doMethod:@"bespoke.getGeo" maxCacheAge:0 XPath:@"./geo" withParameters:nil];
	if([nodes count])
		return [self _convertNode:[nodes objectAtIndex:0]
			 toDictionaryWithXPaths:[NSArray arrayWithObjects:@"./countrycode",@"./countryname", 
															 nil]
											forKeys:[NSArray arrayWithObjects:@"countrycode", @"countryname", nil]];
	else
		return nil;
}

#pragma mark Artist methods

- (NSDictionary *)metadataForArtist:(NSString *)artist inLanguage:(NSString *)lang {
	NSDictionary *metadata = nil;
	NSArray *nodes = [self doMethod:@"artist.getInfo" maxCacheAge:7*DAYS XPath:@"./artist" withParameters:[NSString stringWithFormat:@"artist=%@", [artist URLEscaped]], 
					  [NSString stringWithFormat:@"username=%@", [[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] URLEscaped]], [NSString stringWithFormat:@"lang=%@", lang] , nil];
	if([nodes count]) {
		CXMLNode *node = [nodes objectAtIndex:0];
		metadata = [self _convertNode:node
					 toDictionaryWithXPaths:[NSArray arrayWithObjects:@"./name", @"./image[@size=\"large\"]", @"./bio/summary", @"./bio/content", @"./stats/listeners", @"./stats/playcount", @"./stats/userplaycount", nil]
													forKeys:[NSArray arrayWithObjects:@"name", @"image", @"summary", @"bio", @"listeners", @"playcount", @"userplaycount", nil]];
	}
	return metadata;
}
- (NSArray *)artistsSimilarTo:(NSString *)artist {
	NSArray *nodes = [self doMethod:@"artist.getSimilar" maxCacheAge:7*DAYS XPath:@"./similarartists/artist" withParameters:[NSString stringWithFormat:@"artist=%@", [artist URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./match", @"./image[@size=\"large\"]", @"./streamable", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"match", @"image", @"streamable", nil]];
}
- (NSArray *)searchForArtist:(NSString *)artist {
	NSArray *nodes = [self doMethod:@"artist.search" maxCacheAge:1*HOURS XPath:@"./results/artistmatches/artist" withParameters:[NSString stringWithFormat:@"artist=%@", [artist URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./streamable", @"./image[@size=\"large\"]", nil]
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
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./playcount", @"./image[@size=\"large\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"playcount", @"image", nil]];
}
- (void)dismissRecommendedArtist:(NSString *)artist {
	[self doMethod:@"user.dismissArtistRecommendation" maxCacheAge:0 XPath:@"." withParameters:[NSString stringWithFormat:@"artist=%@", [artist URLEscaped]], nil];
}
- (void)addArtistToLibrary:(NSString *)artist {
	[self doMethod:@"library.addArtist" maxCacheAge:0 XPath:@"." withParameters:[NSString stringWithFormat:@"artist=%@", [artist URLEscaped]], nil];
}
- (void)recommendArtist:(NSString *)artist toEmailAddress:(NSString *)emailAddress {
	[self doMethod:@"artist.share" maxCacheAge:0 XPath:@"." withParameters:[NSString stringWithFormat:@"artist=%@", [artist URLEscaped]],
																		   [NSString stringWithFormat:@"recipient=%@", [emailAddress URLEscaped]],
																		   nil];
}

#pragma mark Album methods

- (void)addAlbumToLibrary:(NSString *)album byArtist:(NSString *)artist {
	[self doMethod:@"library.addAlbum" maxCacheAge:0 XPath:@"." withParameters:[NSString stringWithFormat:@"artist=%@", [artist URLEscaped]], [NSString stringWithFormat:@"album=%@", [album URLEscaped]], nil];
}
- (NSDictionary *)metadataForAlbum:(NSString *)album byArtist:(NSString *)artist inLanguage:(NSString *)lang {
	NSDictionary *metadata = nil;
	float scale = 1.0f;
	if([[UIScreen mainScreen] respondsToSelector:@selector(scale)])
		scale = [[UIScreen mainScreen] scale];
	NSArray *nodes = [self doMethod:@"album.getInfo" maxCacheAge:7*DAYS XPath:@"./album" withParameters:[NSString stringWithFormat:@"album=%@", [album URLEscaped]], 
										[NSString stringWithFormat:@"artist=%@", [artist URLEscaped]],
										[NSString stringWithFormat:@"username=%@", [[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] URLEscaped]], 
										[NSString stringWithFormat:@"lang=%@", lang], nil];
	if([nodes count]) {
		CXMLNode *node = [nodes objectAtIndex:0];
		metadata = [self _convertNode:node
					 toDictionaryWithXPaths:[NSArray arrayWithObjects:@"./name", @"./artist", @"./releasedate", @"./userplaycount", (scale==1)?@"./image[@size=\"extralarge\"]":@"./image[@size=\"mega\"]", nil]
													forKeys:[NSArray arrayWithObjects:@"name", @"artist", @"releasedate", @"userplaycount", @"image", nil]];
	}
	return metadata;
}
- (NSArray *)tracksForAlbum:(NSString *)album byArtist:(NSString *)artist {
	NSArray *nodes = [self doMethod:@"album.getInfo" maxCacheAge:7*DAYS XPath:@"./album/tracks/track" withParameters:[NSString stringWithFormat:@"album=%@", [album URLEscaped]], [NSString stringWithFormat:@"artist=%@", [artist URLEscaped]],nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./artist/name", @"./image[@size=\"large\"]", nil]
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
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./playcount", @"./artist/name", @"./image[@size=\"large\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"playcount", @"artist", @"image", nil]];
}
- (void)recommendAlbum:(NSString *)album byArtist:(NSString *)artist toEmailAddress:(NSString *)emailAddress {
	[self doMethod:@"album.share" maxCacheAge:0 XPath:@"." withParameters:[NSString stringWithFormat:@"album=%@", [album URLEscaped]],
	 [NSString stringWithFormat:@"artist=%@", [artist URLEscaped]],
	 [NSString stringWithFormat:@"recipient=%@", [emailAddress URLEscaped]],
	 nil];
}

#pragma mark Track methods

- (NSDictionary *)metadataForTrack:(NSString *)track byArtist:(NSString *)artist inLanguage:(NSString *)lang {
	NSDictionary *metadata = nil;
	NSArray *nodes = [self doMethod:@"track.getInfo" maxCacheAge:7*DAYS XPath:@"./track" withParameters:[NSString stringWithFormat:@"track=%@", [track URLEscaped]], 
										[NSString stringWithFormat:@"artist=%@", [artist URLEscaped]],
										[NSString stringWithFormat:@"username=%@", [[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] URLEscaped]], 
										[NSString stringWithFormat:@"lang=%@", lang], nil];
	if([nodes count]) {
		CXMLNode *node = [nodes objectAtIndex:0];
		metadata = [self _convertNode:node
					 toDictionaryWithXPaths:[NSArray arrayWithObjects:@"./name", @"./artist/name", @"./duration", @"./playcount", @"./listeners", @"./userplaycount", @"./wiki/summary", @"./album/image[@size=\"extralarge\"]", @"./album/title", nil]
													forKeys:[NSArray arrayWithObjects:@"name", @"artist", @"duration", @"playcount", @"listeners", @"userplaycount", @"wiki", @"image", @"album", nil]];
	}
	return metadata;
}
- (void)loveTrack:(NSString *)title byArtist:(NSString *)artist {
	[self doMethod:@"track.love" maxCacheAge:0 XPath:@"." withParameters:[NSString stringWithFormat:@"track=%@", [title URLEscaped]], [NSString stringWithFormat:@"artist=%@", [artist URLEscaped]], nil];
}
- (void)addTrackToLibrary:(NSString *)title byArtist:(NSString *)artist {
	[self doMethod:@"library.addTrack" maxCacheAge:0 XPath:@"." withParameters:[NSString stringWithFormat:@"track=%@", [title URLEscaped]], [NSString stringWithFormat:@"artist=%@", [artist URLEscaped]], nil];
}
- (void)nowPlayingTrack:(NSString *)title byArtist:(NSString *)artist onAlbum:(NSString *)album withDuration:(int)duration {
	[self doMethod:@"track.updateNowPlaying" maxCacheAge:0 XPath:@"." withParameters:[NSString stringWithFormat:@"track=%@", [title URLEscaped]], [NSString stringWithFormat:@"artist=%@", [artist URLEscaped]], [NSString stringWithFormat:@"album=%@", [album URLEscaped]], [NSString stringWithFormat:@"duration=%i", duration], nil];
}
- (void)removeNowPlayingTrack:(NSString *)title byArtist:(NSString *)artist onAlbum:(NSString *)album {
	[self doMethod:@"track.removeNowPlaying" maxCacheAge:0 XPath:@"." withParameters:[NSString stringWithFormat:@"track=%@", [title URLEscaped]], [NSString stringWithFormat:@"artist=%@", [artist URLEscaped]], [NSString stringWithFormat:@"album=%@", [album URLEscaped]], nil];
}
- (void)scrobbleTrack:(NSString *)title byArtist:(NSString *)artist onAlbum:(NSString *)album withDuration:(int)duration timestamp:(int)timestamp streamId:(NSString *)streamId {
	[self doMethod:@"track.scrobble" maxCacheAge:0 XPath:@"." withParameters:[NSString stringWithFormat:@"track=%@", [title URLEscaped]], 
	 [NSString stringWithFormat:@"artist=%@", [artist URLEscaped]], 
	 [NSString stringWithFormat:@"album=%@", [album URLEscaped]], 
	 [NSString stringWithFormat:@"streamId=%@", streamId], 
	 [NSString stringWithFormat:@"timestamp=%i", timestamp], 
	 [NSString stringWithFormat:@"duration=%i", duration], nil];
}
- (void)banTrack:(NSString *)title byArtist:(NSString *)artist {
	[self doMethod:@"track.ban" maxCacheAge:0 XPath:@"." withParameters:[NSString stringWithFormat:@"track=%@", [title URLEscaped]], [NSString stringWithFormat:@"artist=%@", [artist URLEscaped]], nil];
}
- (NSArray *)fansOfTrack:(NSString *)track byArtist:(NSString *)artist {
	NSArray *nodes = [self doMethod:@"track.getTopFans" maxCacheAge:7*DAYS XPath:@"./topfans/user" withParameters:[NSString stringWithFormat:@"track=%@", [track URLEscaped]], [NSString stringWithFormat:@"artist=%@", [artist URLEscaped]],nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./weight", @"./image[@size=\"large\"]", nil]
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
- (NSArray *)shoutsForTrack:(NSString *)track byArtist:(NSString *)artist {
	NSArray *nodes = [self doMethod:@"track.getShouts" maxCacheAge:5*MINUTES XPath:@"./shouts/shout" withParameters:[NSString stringWithFormat:@"track=%@", [track URLEscaped]], [NSString stringWithFormat:@"artist=%@", [artist URLEscaped]],nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./author", @"./body", @"./date", nil]
										 forKeys:[NSArray arrayWithObjects:@"author", @"body", @"date", nil]];
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
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./playcount", @"./streamable", @"./image[@size=\"large\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"playcount", @"streamable", @"image", nil]];
}
- (NSDictionary *)weeklyArtistsForUser:(NSString *)username {
	CXMLNode *node = [[self doMethod:@"user.getWeeklyArtistChart" maxCacheAge:5*MINUTES XPath:@"./weeklyartistchart" withParameters:[NSString stringWithFormat:@"user=%@", [username URLEscaped]], nil] objectAtIndex:0];
	if( !node ) return nil;

	NSDictionary *result = nil;
	NSString* from = [node objectAtXPath: @"@from"];
	NSString* to = [node objectAtXPath: @"@to"];
	NSError* nodeError;
	NSArray* nodes = [node nodesForXPath:@"./artist" error:&nodeError];
	NSArray* artists = [self _convertNodes:nodes
						toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./playcount", @"./streamable", @"./image[@size=\"large\"]", nil]
						forKeys:[NSArray arrayWithObjects:@"name", @"playcount", @"streamable", @"image", nil]];
	if(from != nil && to != nil && artists != nil)
		result = [NSDictionary dictionaryWithObjects: [NSArray arrayWithObjects: from, to, artists, nil ] 
													   forKeys: [NSArray arrayWithObjects: @"from", @"to", @"artists", nil ]];
	return result;
}
- (NSArray *)recommendedArtistsForUser:(NSString *)username {
	NSArray *nodes = [self doMethod:@"user.getRecommendedArtists" maxCacheAge:0 XPath:@"./recommendations/artist" withParameters:[NSString stringWithFormat:@"user=%@", [username URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./playcount", @"./streamable", @"./image[@size=\"large\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"playcount", @"streamable", @"image", nil]];
}
- (NSArray *)recommendedReleasesForUser:(NSString *)username {
	NSArray *nodes = [self doMethod:@"user.getNewReleases" maxCacheAge:5*MINUTES XPath:@"./albums/album" withParameters:[NSString stringWithFormat:@"user=%@", [username URLEscaped]], @"userecs=1", nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./playcount", @"./artist/name", @"./image[@size=\"large\"]", @"./@releasedate", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"playcount", @"artist", @"image", @"releasedate", nil]];
}
- (NSArray *)releasesForUser:(NSString *)username {
	NSArray *nodes = [self doMethod:@"user.getNewReleases" maxCacheAge:5*MINUTES XPath:@"./albums/album" withParameters:[NSString stringWithFormat:@"user=%@", [username URLEscaped]], @"userecs=0", nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./playcount", @"./artist/name", @"./image[@size=\"large\"]", @"./@releasedate", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"playcount", @"artist", @"image", @"releasedate", nil]];
}
- (NSString *)releaseDataSourceForUser:(NSString *)username {
	NSArray *nodes = [self doMethod:@"user.getNewReleases" maxCacheAge:5*MINUTES XPath:@"./albums" withParameters:[NSString stringWithFormat:@"user=%@", [username URLEscaped]], nil];
	if([nodes count]) {
		NSDictionary *source = nil;
		CXMLNode *node = [nodes objectAtIndex:0];
		source = [self _convertNode:node
					toDictionaryWithXPaths:[NSArray arrayWithObjects:@"@source", nil]
												 forKeys:[NSArray arrayWithObjects:@"source", nil]];
		return [source objectForKey:@"source"];
	}
	return nil;
}
- (NSArray *)topAlbumsForUser:(NSString *)username {
	NSArray *nodes = [self doMethod:@"user.getTopAlbums" maxCacheAge:5*MINUTES XPath:@"./topalbums/album" withParameters:[NSString stringWithFormat:@"user=%@", [username URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./playcount", @"./artist/name", @"./image[@size=\"large\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"playcount", @"artist", @"image", nil]];
}
- (NSArray *)topTracksForUser:(NSString *)username {
	NSArray *nodes = [self doMethod:@"user.getTopTracks" maxCacheAge:5*MINUTES XPath:@"./toptracks/track" withParameters:[NSString stringWithFormat:@"user=%@", [username URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./playcount", @"./artist/name", @"./image[@size=\"large\"]", nil]
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
	NSArray *nodes = [self doMethod:@"user.getRecentTracks" maxCacheAge:0 XPath:@"./recenttracks/track" withParameters:[NSString stringWithFormat:@"user=%@", [username URLEscaped]], @"extended=true", @"limit=50", nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./@nowplaying", @"./artist/name", @"./name", @"./date", @"./date/@uts", @"./image[@size=\"large\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"nowplaying", @"artist", @"name", @"date", @"uts", @"image", nil]];
}
- (NSArray *)friendsOfUser:(NSString *)username {
	NSArray *nodes = [self doMethod:@"user.getFriends" maxCacheAge:0 XPath:@"./friends/user" withParameters:[NSString stringWithFormat:@"user=%@", [username URLEscaped]], @"limit=500", nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./image[@size=\"large\"]", @"realname", nil]
										 forKeys:[NSArray arrayWithObjects:@"username", @"image", @"realname", nil]];
}
- (NSArray *)nowListeningFriendsOfUser:(NSString *)username {
	NSArray *nodes = [self doMethod:@"user.getfriendslisteningnow" maxCacheAge:0 XPath:@"./friendslisteningnow/user" withParameters:[NSString stringWithFormat:@"user=%@", [username URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./realname", @"./scrobblesource/name", @"./recenttrack/artist/name", @"./recenttrack/name", @"./image[@size=\"extralarge\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"username", @"realname", @"scrobblesource", @"artist", @"title", @"image", nil]];
}
- (NSDictionary *)profileForUser:(NSString *)username {
	return [self profileForUser:username authenticated:YES];
}
- (NSDictionary *)profileForUser:(NSString *)username authenticated:(BOOL)authenticated {
	NSArray *nodes = [self doMethod:@"user.getInfo" maxCacheAge:0 XPath:@"./user" authenticated:authenticated withParameters:[NSString stringWithFormat:@"user=%@", [[username lowercaseString] URLEscaped]], nil];
	if([nodes count])
		return [self _convertNode:[nodes objectAtIndex:0]
			 toDictionaryWithXPaths:[NSArray arrayWithObjects:@"./realname", @"./registered/@unixtime", @"./age", @"./gender", @"./country", @"./playcount", @"./image[@size=\"extralarge\"]", nil]
											forKeys:[NSArray arrayWithObjects:@"realname", @"registered", @"age", @"gender", @"country", @"playcount", @"avatar", nil]];
	else
		return nil;
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
										[NSString stringWithFormat:@"username=%@", [[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] URLEscaped]], 
										[NSString stringWithFormat:@"lang=%@", lang], nil];
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
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./streamable", @"./image[@size=\"large\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"streamable", @"image", nil]];
}
- (NSArray *)topAlbumsForTag:(NSString *)tag {
	NSArray *nodes = [self doMethod:@"tag.getTopAlbums" maxCacheAge:5*MINUTES XPath:@"./topalbums/album" withParameters:[NSString stringWithFormat:@"tag=%@", [tag URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./playcount", @"./artist/name", @"./image[@size=\"large\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"playcount", @"artist", @"image", nil]];
}
- (NSArray *)topTracksForTag:(NSString *)tag {
	NSArray *nodes = [self doMethod:@"tag.getTopTracks" maxCacheAge:5*MINUTES XPath:@"./toptracks/track" withParameters:[NSString stringWithFormat:@"tag=%@", [tag URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./playcount", @"./artist/name", @"./image[@size=\"large\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"playcount", @"artist", @"image", nil]];
}

#pragma mark Radio methods

- (NSDictionary *)tuneRadioStation:(NSString *)stationURL {
	NSDictionary *station = nil;
	NSArray *nodes = [self doMethod:@"radio.tune" maxCacheAge:0 XPath:@"./station" withParameters:[NSString stringWithFormat:@"station=%@", [stationURL URLEscaped]], [NSString stringWithFormat:@"rtp=%i", [[[NSUserDefaults standardUserDefaults] objectForKey:@"scrobbling"] isEqualToString:@"YES"]], @"additional_info=1", nil];
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
		speed = @"8";
	} else {
		network = @"wwan";
		bitrate = [[NSUserDefaults standardUserDefaults] objectForKey:@"bitrate"];
		speed = @"8";
	}
	
	NSArray *nodes = [[[[[self doMethod:@"radio.getPlaylist" maxCacheAge:0 XPath:@"." withParameters:
												[NSString stringWithFormat:@"mobile_net=%@",network],
												[NSString stringWithFormat:@"bitrate=%@", bitrate],
												[NSString stringWithFormat:@"speed_multiplier=%@", speed],
												@"additional_info=1",
												nil] objectAtIndex:0] children] objectAtIndex:1] children];
	NSString *title = nil;
	NSString *expiry = nil;
	
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
									if([[extNode name] isEqualToString:@"context"]) {
										NSMutableArray *context = [[NSMutableArray alloc] init];
										for(CXMLNode *ctxNode in [extNode children]) {
											if(![[ctxNode name] isEqualToString:@"user"] && [[[ctxNode stringValue] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]] length] > 0)
												[context addObject:[ctxNode stringValue]];
										}
										[track setObject:context forKey:@"context"];
										[context release];
									} else if([extNode stringValue])
										[track setObject:[extNode stringValue] forKey:[extNode name]];
								}
							} else if([trackNode stringValue])
								[track setObject:[trackNode stringValue] forKey:[trackNode name]];
						}
						
						[playlist addObject:track];
						[track release];
					}
				}
			} else if([[node name] isEqualToString:@"link"] && [node stringValue]) {
				expiry = [NSMutableString stringWithString:[node stringValue]];
			} else if([[node name] isEqualToString:@"title"] && [node stringValue]) {
				NSMutableString *station = [NSMutableString stringWithString:[node stringValue]];
				[station replaceOccurrencesOfString:@"+" withString:@" " options:NSLiteralSearch range:NSMakeRange(0, [station length])];
				[station replaceOccurrencesOfString:@"-" withString:@" " options:NSLiteralSearch range:NSMakeRange(0, [station length])];
				title = [(NSString *)CFURLCreateStringByReplacingPercentEscapes(NULL,(CFStringRef)[station stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]],CFSTR("")) autorelease];
			} else if([[node name] isEqualToString:@"extension"] && [[node children] count]) {
				for(CXMLNode *extNode in [node children]) {
					if([[extNode name] isEqualToString:@"expired"]) {
						[[NSUserDefaults standardUserDefaults] setObject:[extNode stringValue] forKey:@"trial_expired"];
						[[NSUserDefaults standardUserDefaults] synchronize];
					}
					if([[extNode name] isEqualToString:@"playsleft"]) {
						[[NSUserDefaults standardUserDefaults] setObject:[extNode stringValue] forKey:@"trial_playsleft"];
						[[NSUserDefaults standardUserDefaults] synchronize];
					}
				}
			}
		}
		return [NSDictionary dictionaryWithObjectsAndKeys:playlist,@"playlist",title,@"title",expiry,@"expiry",nil]; 
	} else {
		return nil;
	}
}
- (NSArray *)suggestedTagsForStation:(NSString *)stationURL {
	NSArray *nodes = [self doMethod:@"radio.getTagSuggestions" maxCacheAge:1*HOURS XPath:@"./suggestions/suggestion" withParameters:[NSString stringWithFormat:@"station=%@", [stationURL URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./tag/name", @"./station/url", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"url", nil]];
}
- (NSDictionary *)userStations {
	NSArray *nodes = [self doMethod:@"radio.getUserStations" maxCacheAge:0 XPath:@"./userstations/*" withParameters: nil];	
	NSMutableDictionary* results = [NSMutableDictionary dictionary];
	for ( CXMLNode* stationGroup in nodes ) {
		NSArray* stationNodes = [stationGroup nodesForXPath: @"./station" error: &error];
		
		NSArray* stations = [self _convertNodes: stationNodes
							  toArrayWithXPaths: [NSArray arrayWithObjects: @"./name", @"./url", @"@available", nil]
										forKeys: [NSArray arrayWithObjects: @"name", @"url", @"available", nil]];
		
		
		[results setValue:stations forKey: [stationGroup name]];
	}
	return results;
}
	
#pragma mark Search methods

- (NSArray *)search:(NSString *)query {
	NSArray *nodes = [[[self doMethod:@"search.multi" maxCacheAge:0 XPath:@"./results/matches" withParameters:
												[NSString stringWithFormat:@"term=%@",query],
												nil] objectAtIndex:0] children];
	
	if([nodes count]) {
		NSMutableArray *results = [[[NSMutableArray alloc] init] autorelease];
		
		for(CXMLNode *node in nodes) {
			if([[node name] isEqualToString:@"tag"]) {
				NSDictionary *tag = [self _convertNode:node toDictionaryWithXPaths:[NSArray arrayWithObjects:@"./name", @"./streamable", nil]
																		 forKeys:[NSArray arrayWithObjects:@"name", @"streamable", nil]];
				NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithDictionary:tag];
				[result setObject:@"tag" forKey:@"kind"];
				[results addObject: result];
				[result release];
			}
			if([[node name] isEqualToString:@"artist"]) {
				NSDictionary *artist = [self _convertNode:node toDictionaryWithXPaths:[NSArray arrayWithObjects:@"./name", @"./streamable", @"./image[@size=\"large\"]", nil]
																		 forKeys:[NSArray arrayWithObjects:@"name", @"streamable", @"image", nil]];
				NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithDictionary:artist];
				[result setObject:@"artist" forKey:@"kind"];
				[results addObject: result];
				[result release];
			}
			if([[node name] isEqualToString:@"album"]) {
				NSDictionary *album = [self _convertNode:node toDictionaryWithXPaths:[NSArray arrayWithObjects:@"./name", @"./streamable", @"./artist/name", @"./image[@size=\"large\"]", nil]
																		 forKeys:[NSArray arrayWithObjects:@"name", @"streamable", @"artist", @"image", nil]];
				NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithDictionary:album];
				[result setObject:@"album" forKey:@"kind"];
				[results addObject: result];
				[result release];
			}
			if([[node name] isEqualToString:@"track"]) {
				NSDictionary *track = [self _convertNode:node toDictionaryWithXPaths:[NSArray arrayWithObjects:@"./name", @"./streamable", @"./artist/name", @"./image[@size=\"large\"]", @"./duration", nil]
																		 forKeys:[NSArray arrayWithObjects:@"name", @"streamable", @"artist", @"image", @"duration", nil]];
				NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithDictionary:track];
				[result setObject:@"track" forKey:@"kind"];
				[results addObject: result];
				[result release];
			}
		}
		return results;
	} else {
		return nil;
	}
}
- (NSString *)searchForStation:(NSString *)query {
	NSArray *nodes = [self doMethod:@"radio.search" maxCacheAge:0 XPath:@"./stations/station" withParameters:[NSString stringWithFormat:@"name=%@", [query URLEscaped]], nil];
	if([nodes count]) {
		NSDictionary *station = nil;
		CXMLNode *node = [nodes objectAtIndex:0];
		station = [self _convertNode:node
					toDictionaryWithXPaths:[NSArray arrayWithObjects:@"./name", @"./url", nil]
												 forKeys:[NSArray arrayWithObjects:@"name", @"url", nil]];
		return [station objectForKey:@"url"];
	}
	return nil;
}

#pragma mark Event methods

- (NSArray *)festivalsForArtist:(NSString *)artist {
	NSArray *nodes = [self doMethod:@"artist.getEvents" maxCacheAge:1*DAYS XPath:@"./events/event" withParameters:@"festivalsonly=1",[NSString stringWithFormat:@"artist=%@", [artist URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./id", @"./artists/headliner", @"./artists/artist", @"./title", @"./description", @"./venue/name", @"./venue/location/street", @"./venue/location/city", @"./venue/location/postalcode", @"./venue/location/country", @"./venue/website", @"./venue/phonenumber", @"./startDate", @"./image[@size=\"large\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"id", @"headliner", @"artists", @"title", @"description", @"venue", @"street", @"city", @"postalcode", @"country", @"website", @"phonenumber", @"startDate", @"image", nil]];
}
- (NSArray *)searchForFestival:(NSString *)event {
	NSArray *nodes = [self doMethod:@"event.search" maxCacheAge:1*DAYS XPath:@"./results/eventmatches/event" withParameters:@"festivalsonly=1",[NSString stringWithFormat:@"event=%@", [event URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./id", @"./artists/headliner", @"./artists/artist", @"./title", @"./description", @"./venue/name", @"./venue/location/street", @"./venue/location/city", @"./venue/location/postalcode", @"./venue/location/country", @"./venue/website", @"./venue/phonenumber", @"./startDate", @"./image[@size=\"large\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"id", @"headliner", @"artists", @"title", @"description", @"venue", @"street", @"city", @"postalcode", @"country", @"website", @"phonenumber", @"startDate", @"image", nil]];
}
- (NSArray *)searchForEvent:(NSString *)event {
	NSArray *nodes = [self doMethod:@"event.search" maxCacheAge:1*DAYS XPath:@"./results/eventmatches/event" withParameters:[NSString stringWithFormat:@"event=%@", [event URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./id", @"./artists/headliner", @"./artists/artist", @"./title", @"./description", @"./venue/name", @"./venue/location/street", @"./venue/location/city", @"./venue/location/postalcode", @"./venue/location/country", @"./venue/website", @"./venue/phonenumber", @"./startDate", @"./image[@size=\"large\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"id", @"headliner", @"artists", @"title", @"description", @"venue", @"street", @"city", @"postalcode", @"country", @"website", @"phonenumber", @"startDate", @"image", nil]];
}
- (NSArray *)eventsForArtist:(NSString *)artist {
	NSArray *nodes = [self doMethod:@"artist.getEvents" maxCacheAge:1*DAYS XPath:@"./events/event" withParameters:[NSString stringWithFormat:@"artist=%@", [artist URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./id", @"./artists/headliner", @"./artists/artist", @"./title", @"./description", @"./venue/name", @"./venue/location/street", @"./venue/location/city", @"./venue/location/postalcode", @"./venue/location/country", @"./venue/website", @"./venue/phonenumber", @"./startDate", @"./image[@size=\"large\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"id", @"headliner", @"artists", @"title", @"description", @"venue", @"street", @"city", @"postalcode", @"country", @"website", @"phonenumber", @"startDate", @"image", nil]];
}
- (NSArray *)eventsForUser:(NSString *)username {
	NSArray *nodes = [self doMethod:@"user.getEvents" maxCacheAge:0 XPath:@"./events/event" withParameters:[NSString stringWithFormat:@"user=%@", [username URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./@status", @"./id", @"./artists/headliner", @"./artists/artist", @"./title", @"./description", @"./venue/name", @"./venue/location/street", @"./venue/location/city", @"./venue/location/postalcode", @"./venue/location/country", @"./venue/website", @"./venue/phonenumber", @"./startDate", @"./image[@size=\"large\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"status", @"id", @"headliner", @"artists", @"title", @"description", @"venue", @"street", @"city", @"postalcode", @"country", @"website", @"phonenumber", @"startDate", @"image", nil]];
}
- (NSArray *)eventsForFriendsOfUser:(NSString *)username {
	NSArray *nodes = [self doMethod:@"user.getFriendsEvents" maxCacheAge:0 XPath:@"./events/event" withParameters:[NSString stringWithFormat:@"user=%@", [username URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./@status", @"./id", @"./artists/headliner", @"./artists/artist", @"./title", @"./description", 
															@"./venue/name", @"./venue/location/street", @"./venue/location/city", @"./venue/location/postalcode", 
															@"./venue/location/country", @"./venue/website", @"./venue/phonenumber", @"./startDate", 
															@"./image[@size=\"large\"]", @"./friendsattending/attendee", nil]
										 forKeys:[NSArray arrayWithObjects:@"status", @"id", @"headliner", @"artists", @"title", @"description", @"venue", @"street", @"city", @"postalcode", @"country", @"website", @"phonenumber", @"startDate", @"image", @"attendees", nil]];
}
- (NSArray *)recommendedEventsForUser:(NSString *)username {
	NSArray *nodes = [self doMethod:@"user.getRecommendedEvents" maxCacheAge:0 XPath:@"./events/event" withParameters:[NSString stringWithFormat:@"user=%@", [username URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./@status", @"./id", @"./artists/headliner", @"./artists/artist", @"./title", @"./description", @"./venue/name", @"./venue/location/street", @"./venue/location/city", @"./venue/location/postalcode", @"./venue/location/country", @"./venue/website", @"./venue/phonenumber", @"./startDate", @"./image[@size=\"large\"]", @"./score", nil]
										 forKeys:[NSArray arrayWithObjects:@"status", @"id", @"headliner", @"artists", @"title", @"description", @"venue", @"street", @"city", @"postalcode", @"country", @"website", @"phonenumber", @"startDate", @"image", @"score", nil]];
}
- (NSArray *)festivalsForCountry:(NSString *)country page:(int)page {
	NSArray *nodes = [self doMethod:@"geo.getEvents" maxCacheAge:1*DAYS XPath:@"./events/event" withParameters:@"festivalsonly=1",[NSString stringWithFormat:@"page=%i", page],
															 [NSString stringWithFormat:@"location=%@", [country URLEscaped]], @"limit=100", nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./@status", @"./id", @"./artists/headliner", @"./artists/artist", @"./title", @"./description", @"./venue/name", @"./venue/location/street", @"./venue/location/city", @"./venue/location/postalcode", @"./venue/location/country", @"./venue/location/point/lat", @"./venue/location/point/long", @"./venue/website", @"./venue/phonenumber", @"./startDate", @"./image[@size=\"large\"]", @"./image[@size=\"mega\"]", @"./score", nil]
										 forKeys:[NSArray arrayWithObjects:@"status", @"id", @"headliner", @"artists", @"title", @"description", @"venue", @"street", @"city", @"postalcode", @"country", @"lat", @"long", @"website", @"phonenumber", @"startDate", @"image", @"megaimage", @"score", nil]];
}
- (NSArray *)festivalsForUser:(NSString *)username {
	NSArray *nodes = [self doMethod:@"user.getEvents" maxCacheAge:0 XPath:@"./events/event" withParameters:@"festivalsonly=1",[NSString stringWithFormat:@"user=%@", [username URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./@status", @"./id", @"./artists/headliner", @"./artists/artist", @"./title", @"./description", @"./venue/name", @"./venue/location/street", @"./venue/location/city", @"./venue/location/postalcode", @"./venue/location/country", @"./venue/website", @"./venue/phonenumber", @"./startDate", @"./image[@size=\"large\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"status", @"id", @"headliner", @"artists", @"title", @"description", @"venue", @"street", @"city", @"postalcode", @"country", @"website", @"phonenumber", @"startDate", @"image", nil]];
}
- (NSArray *)festivalsForFriendsOfUser:(NSString *)username {
	NSArray *nodes = [self doMethod:@"user.getFriendsEvents" maxCacheAge:0 XPath:@"./events/event" withParameters:@"festivalsonly=1",[NSString stringWithFormat:@"user=%@", [username URLEscaped]], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./@status", @"./id", @"./artists/headliner", @"./artists/artist", @"./title", @"./description", 
															@"./venue/name", @"./venue/location/street", @"./venue/location/city", @"./venue/location/postalcode", 
															@"./venue/location/country", @"./venue/website", @"./venue/phonenumber", @"./startDate", 
															@"./image[@size=\"large\"]", @"./friendsattending/attendee", nil]
										 forKeys:[NSArray arrayWithObjects:@"status", @"id", @"headliner", @"artists", @"title", @"description", @"venue", @"street", @"city", @"postalcode", @"country", @"website", @"phonenumber", @"startDate", @"image", @"attendees", nil]];
}
- (NSArray *)eventsForLatitude:(float)latitude longitude:(float)longitude radius:(int)radius {
	NSArray *nodes = [self doMethod:@"geo.getEvents" maxCacheAge:0 XPath:@"./events/event" withParameters:[NSString stringWithFormat:@"lat=%f", latitude], [NSString stringWithFormat:@"long=%f", longitude], [NSString stringWithFormat:@"distance=%i", radius], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./@status", @"./id", @"./artists/headliner", @"./artists/artist", @"./title", @"./description", @"./venue/name", @"./venue/location/street", @"./venue/location/city", @"./venue/location/postalcode", @"./venue/location/country", @"./venue/website", @"./venue/phonenumber", @"./startDate", @"./image[@size=\"large\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"status", @"id", @"headliner", @"artists", @"title", @"description", @"venue", @"street", @"city", @"postalcode", @"country", @"website", @"phonenumber", @"startDate", @"image", nil]];
}
- (NSArray *)festivalsForLatitude:(float)latitude longitude:(float)longitude radius:(int)radius {
	NSArray *nodes = [self doMethod:@"geo.getEvents" maxCacheAge:0 XPath:@"./events/event" withParameters:@"festivalsonly=1", [NSString stringWithFormat:@"lat=%f", latitude], [NSString stringWithFormat:@"long=%f", longitude], [NSString stringWithFormat:@"distance=%i", radius], @"limit=100", nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./@status", @"./id", @"./artists/headliner", @"./artists/artist", @"./title", @"./description", @"./venue/name", @"./venue/location/street", @"./venue/location/city", @"./venue/location/postalcode", @"./venue/location/country", @"./venue/website", @"./venue/phonenumber", @"./startDate", @"./image[@size=\"large\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"status", @"id", @"headliner", @"artists", @"title", @"description", @"venue", @"street", @"city", @"postalcode", @"country", @"website", @"phonenumber", @"startDate", @"image", nil]];
}
- (NSArray *)recommendedLineupForEvent:(int)eventID {
	NSArray *nodes = [self doMethod:@"event.getRecommendedLineup" maxCacheAge:0 XPath:@"./artists/artist" withParameters:[NSString stringWithFormat:@"event=%i", eventID], nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./streamable", @"./image[@size=\"large\"]", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"streamable", @"image", nil]];
}
- (void)attendEvent:(int)event status:(int)status {
	[self doMethod:@"event.attend" maxCacheAge:0 XPath:@"." withParameters:[NSString stringWithFormat:@"event=%i", event], [NSString stringWithFormat:@"status=%i", status], nil];
}
- (NSDictionary *)detailsForEvent:(int)eventID {
	NSDictionary *metadata = nil;
	NSArray *nodes = [self doMethod:@"event.getInfo" maxCacheAge:1*DAYS XPath:@"./event" withParameters:[NSString stringWithFormat:@"event=%i", eventID], nil];
	if([nodes count]) {
		CXMLNode *node = [nodes objectAtIndex:0];
		metadata = [self _convertNode:node toDictionaryWithXPaths:[NSArray arrayWithObjects:@"./@status", @"./score", @"./id", @"./artists/headliner", @"./artists/artist", @"./title", @"./description", @"./venue/name", @"./venue/location/street", @"./venue/location/city", @"./venue/location/postalcode", @"./venue/location/country", @"./venue/website", @"./venue/phonenumber", @"./startDate", @"./image[@size=\"large\"]", @"./image[@size=\"extralarge\"]", @"./image[@size=\"mega\"]", nil]
																											forKeys:[NSArray arrayWithObjects:@"status", @"score", @"id", @"headliner", @"artists", @"title", @"description", @"venue", @"street", @"city", @"postalcode", @"country", @"website", @"phonenumber", @"startDate", @"image", @"extralargeimage", @"megaimage", nil]];
	}
	return metadata;
}
- (void)recommendEvent:(int)event toEmailAddress:(NSString *)emailAddress {
	[self doMethod:@"event.share" maxCacheAge:0 XPath:@"." withParameters:[NSString stringWithFormat:@"event=%i", event],
	 [NSString stringWithFormat:@"recipient=%@", [emailAddress URLEscaped]],
	 nil];
}
- (NSArray *)highlightedFestivals {
	NSArray *nodes = [self doGet:[NSString stringWithFormat:@"http://cdn.last.fm/client/festivals/highlights-%@.xml", [[NSUserDefaults standardUserDefaults] objectForKey:@"countrycode"]] maxCacheAge:1*DAYS XPath:@"/highlights/festival"];
	if(![nodes count])
		 nodes = [self doGet:@"http://cdn.last.fm/client/festivals/highlights.xml" maxCacheAge:1*DAYS XPath:@"/highlights/festival"];

	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./id", @"./img", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"id", @"image", nil]];
}
- (NSDictionary *)adsForCountry:(NSString *)country {
	NSDictionary *ads = nil;
	NSArray *nodes = [self doGet:[NSString stringWithFormat:@"http://cdn.last.fm/client/festivals/ads/iphone-%@.xml", country] maxCacheAge:1*DAYS XPath:@"/ads"];
	if([nodes count]) {
		CXMLNode *node = [nodes objectAtIndex:0];
		ads = [self _convertNode:node toDictionaryWithXPaths:[NSArray arrayWithObjects:@"./splash", @"./titlebar", @"./titlebar_retina", @"./title", @"./popup", @"./link", nil]
													forKeys:[NSArray arrayWithObjects:@"splash", @"titlebar", @"titlebar_retina", @"title", @"popup", @"link", nil]];
	}
	return ads;
}
- (NSArray *)getMetros {
	NSArray *nodes = [self doMethod:@"geo.getMetros" maxCacheAge:7*DAYS XPath:@"./metros/metro" withParameters:nil];
	return [self _convertNodes:nodes
					 toArrayWithXPaths:[NSArray arrayWithObjects:@"./name", @"./country", nil]
										 forKeys:[NSArray arrayWithObjects:@"name", @"country", nil]];
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
