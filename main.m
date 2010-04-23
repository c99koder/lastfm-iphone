/* main.m - Application entry point
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

#import <execinfo.h>
#import <signal.h>
#import <UIKit/UIKit.h>
#import "version.h"

void uncaughtExceptionHandler(NSException *exception) {
	NSLog(@"Unhandled %@ exception encountered\n", [exception name]);
	NSLog(@"Reason: %@\n", [exception reason]);
	
	NSArray *callStackArray = [exception callStackReturnAddresses];
	void *backtraceFrames[[callStackArray count]];
	int frameCount = [callStackArray count];
	
	for (int i=0; i<[callStackArray count]; i++) {
		backtraceFrames[i] = (void *)[[callStackArray objectAtIndex:i] unsignedIntegerValue];
	}
  char **frameStrings = backtrace_symbols(&backtraceFrames[0], frameCount);
	
  if(frameStrings != NULL) {
		NSLog(@"Stack trace:\n");
    int x = 0;
    for(x = 0; x < frameCount; x++) {
      if(frameStrings[x] == NULL) { break; }
      NSLog(@"%s\n", frameStrings[x]);
    }
    free(frameStrings);
  }
	
	[[NSData dataWithContentsOfFile:CACHE_FILE(@"debug.log")] writeToFile:CACHE_FILE(@"crash.log") atomically:YES];
	[[NSUserDefaults standardUserDefaults] setObject:@"YES" forKey:@"crashed"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

void mysighandler(int sig, siginfo_t *info, void *context) {
	NSLog(@"Caught signal %i (%s)\n", info->si_signo, sys_signame[sig]);

  void *backtraceFrames[128];
  int frameCount = backtrace(&backtraceFrames[0], 128);
  char **frameStrings = backtrace_symbols(&backtraceFrames[0], frameCount);
	
  if(frameStrings != NULL) {
		NSLog(@"Stack trace:\n");
    int x = 0;
    for(x = 0; x < frameCount; x++) {
      if(frameStrings[x] == NULL) { break; }
      NSLog(@"%s\n", frameStrings[x]);
    }
    free(frameStrings);
  }
	
	[[NSData dataWithContentsOfFile:CACHE_FILE(@"debug.log")] writeToFile:CACHE_FILE(@"crash.log") atomically:YES];
	[[NSUserDefaults standardUserDefaults] setObject:@"YES" forKey:@"crashed"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	exit(-1);
}

// Override NSLog to output to a file as well as the console
void NSLog(NSString *format, ...) {
	va_list ap;
	NSMutableString *print;
	va_start(ap,format);
	print=[[NSMutableString alloc] initWithFormat:format arguments:ap];
	va_end(ap);
	
	if(![print hasSuffix:@"\n"])
		[print appendString:@"\n"];
	
	FILE *f = fopen([CACHE_FILE(@"debug.log") UTF8String], "a");
	fprintf(f, "%s %s", [[[NSDate date] description] UTF8String], [print UTF8String]);
	fclose(f);
#ifndef DISTRIBUTION	
	fprintf(stderr, "%s %s", [[[NSDate date] description] UTF8String], [print UTF8String]);
#endif	
	[print release];
}

int main(int argc, char *argv[]) {
	/*struct sigaction newsigaction;
	newsigaction.sa_sigaction = mysighandler;
	newsigaction.sa_flags = SA_SIGINFO;
	sigemptyset(&newsigaction.sa_mask);
	sigaction(SIGQUIT, &newsigaction, NULL);
	sigaction(SIGILL, &newsigaction, NULL);
	sigaction(SIGTRAP, &newsigaction, NULL);
	sigaction(SIGABRT, &newsigaction, NULL);
	sigaction(SIGEMT, &newsigaction, NULL);
	sigaction(SIGFPE, &newsigaction, NULL);
	sigaction(SIGBUS, &newsigaction, NULL);
	sigaction(SIGSEGV, &newsigaction, NULL);
	sigaction(SIGSYS, &newsigaction, NULL);
	sigaction(SIGPIPE, &newsigaction, NULL);
	sigaction(SIGALRM, &newsigaction, NULL);
	sigaction(SIGXCPU, &newsigaction, NULL);
	sigaction(SIGXFSZ, &newsigaction, NULL);*/
	
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	int retVal;
	
	[[NSFileManager defaultManager] removeItemAtPath:CACHE_FILE(@"debug.log") error:nil];
	
	//@try {
		retVal = UIApplicationMain(argc, argv, nil, nil);
	/*}
	@catch (NSException *exception) {
		uncaughtExceptionHandler(exception);
	}*/
	
	[pool release];
	return retVal;
}
