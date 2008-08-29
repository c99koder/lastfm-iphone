/* main.m - Application entry point
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

#import <execinfo.h>
#import <signal.h>
#import <ucontext.h>
#import <UIKit/UIKit.h>
#import "version.h"

/*
 * This function formulates a crash report with data available from the NSException
 * object. The most useful pieces of data are the exception reason and the
 * backtrace. The backtrace addresses are formulated into a more readable format.
 * The report is then logged to stderr and then emailed to a central address.
 *
 * This function was adapted from MyMote
 */
void uncaughtExceptionHandler(NSException *exception) {
	// Transpose the NSException backtrace NSArray object into an array of void
	// pointers for backtrace_symbols.
	void *backtraceFrames[[[exception callStackReturnAddresses] count]];
	int i = 0;
	for (NSNumber *frame in [exception callStackReturnAddresses]) {
		backtraceFrames[i++] = (void *)[frame unsignedIntegerValue];
	}
	int frameCount = [[exception callStackReturnAddresses] count];
	
	// Get symbols for the backtrace addresses
	char **frameStrings = backtrace_symbols(backtraceFrames, frameCount);
	
	NSMutableString *report = [NSMutableString string];
	
	// Populate header of report with exception information
	[report appendFormat:@"Unhandled %@ exception encountered\n", [exception name]];
	[report appendFormat:@"Reason: %@\n", [exception reason]];
	[report appendString:@"MobileLastFM Version: " VERSION @"\n\n"];
	if ([[exception userInfo] count]) {
		[report appendString:@"Application Data:\n"];
		[report appendString:[[exception userInfo] description]];
		[report appendString:@"\n\n"];
	}
	else {
		[report appendString:@"No Application Data Available\n\n"];
	}
	
	// Start backtrace
	[report appendString:@"Backtrace:"];
	
	if(frameStrings != NULL) {
		int i = 0;
		
		// Append each stack frame string to the report
		for(i = 0; i < frameCount; i++) {
			if(frameStrings[i] == NULL) {
				continue;
			}
			[report appendFormat:@"\n%s", frameStrings[i]];
		}
	}
	
	// Log the report to stderr
	NSLog(@"%@", report);
	
	// Copy debug.log to crash.log
	[[NSFileManager defaultManager] removeFileAtPath:CACHE_FILE(@"crash.log") handler:nil];
	[[NSFileManager defaultManager] copyPath:CACHE_FILE(@"debug.log") toPath:CACHE_FILE(@"crash.log") handler:nil];
	
	// Set a key so we prompt the user to report this on next launch
	[[NSUserDefaults standardUserDefaults] setObject:@"YES" forKey:@"crashed"];
	
	// This is needed because we're about to end the program
	[[NSUserDefaults standardUserDefaults] synchronize];
}

/*
 * This function handles signals like segmentation faults. Signal details and a
 * stack trace are reported. Note that this function retrieves the stack by peering
 * into the registers of the process, and some inferences may become inaccurate if
 * the underlying stack frame structures are modified in the future.
 *
 * This function was adapted from MyMote
 */
void mysighandler(int sig, siginfo_t *info, void *context) {
	NSMutableString *report = [NSMutableString string];
	[report appendFormat:@"MobileLastFM terminated due to a %s signal\n", sys_signame[sig]];
	[report appendFormat:@"Signal Number: %d\n", info->si_signo];
	[report appendFormat:@"Error Number: %d\n", info->si_errno];
	[report appendFormat:@"Signal Code: %d\n", info->si_code];
	[report appendFormat:@"PID: %d\n", info->si_pid];
	[report appendFormat:@"UID: %d\n", info->si_uid];
	[report appendFormat:@"Exit Value: %d\n", info->si_status];
	[report appendFormat:@"Address: %p\n", info->si_addr];
	[report appendFormat:@"Signal Value: %p\n", info->si_value];
	[report appendFormat:@"Band: %ld\n", info->si_band];
	
	[report appendString:@"\nBacktrace:\n"];
	
	ucontext_t *ucontext = context;
	
	// Prepare backtrace frames array
	void *backtraceFrames[128];
	int frameCount = 0;
	
	/* These blocks perform stack unwinding to get the backtrace. The registers and
	 * stack frame layouts are architecture specific. Note: ip is the instruction
	 * pointer, bp is the base pointer, and fp is the frame pointer.
	 */
#ifdef __i386__
	void *ip = (void *)ucontext->uc_mcontext->__ss.__eip;
	void **bp = (void **)ucontext->uc_mcontext->__ss.__ebp;
	while (ip && bp && frameCount < 128) {
		backtraceFrames[frameCount++] = ip;
		ip = bp[1];
		bp = bp[0];
	}
#elif defined(__arm__) && defined(__thumb__)
	void *ip = (void *)ucontext->uc_mcontext->__ss.__pc;
	void **fp = (void *)ucontext->uc_mcontext->__ss.__r[7]; // General purpose register r7 is the frame pointer register for the ARM thumb architecture
	void **prevfp = fp - 1;
	
	// Check for word alignment and make sure frames have increasing addresses
	while (ip && fp && !((uint32_t)fp & 3) && prevfp < fp && frameCount < 128) {
		backtraceFrames[frameCount++] = ip;
		// These locations seem to be incorrect according to the ARM docs I've
		// seen online, but they seem to work on the iphone.
		ip = fp[1];
		prevfp = fp;
		fp = fp[0];
	}
#else
	// No support for other architectures
	backtraceFrames[0] = NULL;
	[report appendString:@"No backtrace available on this architecture"];
#endif
	
	// Convert the backtrace addresses into readable strings
	char **frameStrings = backtrace_symbols(backtraceFrames, frameCount);
	
	if(frameStrings != NULL) {
		int i = 0;
		
		// Append each stack frame string to the report
		for(i = 0; i < frameCount; i++) {
			if(frameStrings[i] == NULL) {
				continue;
			}
			[report appendFormat:@"\n%s", frameStrings[i]];
		}
	}
	
#if defined(__arm__) && defined(__thumb__)
	// Check if the backtrace was aborted due to frame word alignment or
	// stack growth direction. The last instruction pointer should be NULL
	// unless the backtrace was aborted, so check it first.
	if (ip) {
		if ((uint32_t)fp & 3) {
			[report appendFormat:@"\nError: Next frame pointer is not word aligned (%p)", fp];
		}
		else if (fp && prevfp >= fp) {
			[report appendFormat:@"\nError: Next frame pointer is up the stack (Next: %p, Previous: %p)", fp, prevfp];
		}
	}
#endif
	
	// Log the report to stderr
	NSLog(report);

	// Copy debug.log to crash.log
	[[NSFileManager defaultManager] removeFileAtPath:CACHE_FILE(@"crash.log") handler:nil];
	[[NSFileManager defaultManager] copyPath:CACHE_FILE(@"debug.log") toPath:CACHE_FILE(@"crash.log") handler:nil];

	// Set a key so we prompt the user to report this on next launch
	[[NSUserDefaults standardUserDefaults] setObject:@"YES" forKey:@"crashed"];
	
	// This is needed because we're about to end the program
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
	
	fprintf(stderr, "%s %s", [[[NSDate date] description] UTF8String], [print UTF8String]);
	
	[print release];
}

int main(int argc, char *argv[])
{
	// Install the signal handler for the following signals
	struct sigaction newsigaction;
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
	sigaction(SIGXFSZ, &newsigaction, NULL);
	
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	int retVal;
	
	[[NSFileManager defaultManager] removeFileAtPath:CACHE_FILE(@"debug.log") handler:nil];
	
	// The following exception handling logic allows us to catch unhandled
	// exceptions. Using the builtin unhandled exceptions handler routines
	// fails to allow the handler to open the mailto: URL for sending crash
	// reports.
	@try {
		retVal = UIApplicationMain(argc, argv, nil, nil);
	}
	@catch (NSException *exception) {
		uncaughtExceptionHandler(exception);
	}

	[pool release];
	return retVal;
}
