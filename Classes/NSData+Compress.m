/* NSData+Compress.m - Compress an NSData object using zlib
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

#import "NSData+Compress.h"
#include <zlib.h>

@implementation NSData (Compress)
-(NSData *)compressWithLevel:(NSInteger)compressionLevel {
	NSMutableData *bazip;
	if ([self length] == 0) {
		return nil;
	}
	if (compressionLevel < -1 || compressionLevel > 9)
		compressionLevel = -1;
	
	unsigned long len = [self length] + [self length] / 100 + 13;
	int res;
	
	do {
		bazip = [NSMutableData data];
		[bazip setLength:len+4];
		res = compress2([bazip mutableBytes]+4, &len, [self bytes], [self length], compressionLevel);
		
		switch (res) {
			case Z_OK:
				((char *)[bazip mutableBytes])[0] = ([self length] & 0xff000000) >> 24;
				((char *)[bazip mutableBytes])[1] = ([self length] & 0x00ff0000) >> 16;
				((char *)[bazip mutableBytes])[2] = ([self length] & 0x0000ff00) >> 8;
				((char *)[bazip mutableBytes])[3] = ([self length] & 0x000000ff);
				break;
			case Z_MEM_ERROR:
				NSLog(@"Compress: Z_MEM_ERROR: Not enough memory");
				[bazip setLength:0];
				break;
			case Z_BUF_ERROR:
				len *= 2;
				break;
		}
	} while (res == Z_BUF_ERROR);
	
	return [NSData dataWithData:bazip];
}
@end
