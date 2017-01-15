//
//  MainViewController.m
//  Pingy
//
//  Created by Richard Davis on 9/20/13.
//  Copyright (c) 2013 Richard Davis. All rights reserved.
//

#import "MainViewController.h"
#import <AudioToolbox/AudioToolbox.h>

#include "SimplePing.h"
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <netdb.h>
#include <sys/socket.h>

@interface MainViewController()

@property (nonatomic, strong, readwrite) SimplePing *pinger;
@property (nonatomic, strong, readwrite) NSTimer *sendTimer;

@end

@implementation Globals

+ (NSMutableArray*)array {
    static NSMutableArray *statArray;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        statArray = [NSMutableArray array];
    });
    return statArray;
}

@end

@implementation MainViewController

@synthesize pinger    = _pinger;
@synthesize sendTimer = _sendTimer;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    ticksToNanoseconds = 0.0; // Initialize variable
    
    self.getAddress.layer.cornerRadius = 5.0;
    self.getAddress.layer.borderWidth = 2.0;
    self.getAddress.layer.borderColor = [[[UIColor grayColor] colorWithAlphaComponent:0.5] CGColor];
    self.getAddress.borderStyle = UITextBorderStyleRoundedRect;
    self.getAddress.placeholder = @"Hostname or IP address";
    
    self.showResults.layer.cornerRadius = 5.0;
    [self.showResults.layer setBorderWidth:2.0];
    [self.showResults.layer setBorderColor:[[[UIColor grayColor] colorWithAlphaComponent:0.5] CGColor]];
    self.showResults.layoutManager.allowsNonContiguousLayout = NO; // Prevents scrolling issues
    
    self.showStatistics.layer.cornerRadius = 5.0;
    [self.showStatistics.layer setBorderWidth:2.0];
    [self.showStatistics.layer setBorderColor:[[[UIColor grayColor] colorWithAlphaComponent:0.5] CGColor]];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.view endEditing:YES];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    [self startPing:self];
    
    return NO;
}

#pragma mark - Flipside View

- (void)flipsideViewControllerDidFinish:(FlipsideViewController *)controller
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showAlternate"]) {
        [[segue destinationViewController] setDelegate:(id)self];
    }
}

#pragma mark * Utilities

- (NSNumber *)meanOf:(NSArray *)array
{
    double runningTotal = 0.0;
    
    for (NSNumber *number in array) {
        runningTotal += [number doubleValue];
    }
    return [NSNumber numberWithDouble:(runningTotal / [array count])];
}

- (NSNumber *)standardDeviationOf:(NSArray *)array
{
    if (![array count]) return nil;
    
    double mean = [[self meanOf:array] doubleValue];
    double sumOfSquaredDifferences = 0.0;
    
    for (NSNumber *number in array) {
        double valueOfNumber = [number doubleValue];
        double difference = valueOfNumber - mean;
        sumOfSquaredDifferences += difference * difference;
    }
    return [NSNumber numberWithDouble:sqrt(sumOfSquaredDifferences / [array count])];
}

static NSString * DisplayAddressForAddress(NSData * address)
// Returns a dotted decimal string for the specified address (a (struct sockaddr)
// within the address NSData).
{
    int err;
    NSString *result;
    char hostStr[NI_MAXHOST];
    
    result = nil;
    
    if (address != nil) {
        err = getnameinfo([address bytes], (socklen_t) [address length], hostStr, sizeof(hostStr), NULL, 0, NI_NUMERICHOST);
        if (err == 0) {
            result = [NSString stringWithCString:hostStr encoding:NSASCIIStringEncoding];
            assert(result != nil);
        }
    }
    return result;
}

- (NSString *)shortErrorFromError:(NSError *)error
// Given an NSError, returns a short error string that we can print, handling
// some special cases along the way.
{
    NSString *result;
    NSNumber *failureNum;
    int failure;
    const char *failureStr;
    
    assert(error != nil);
    
    result = nil;
    
    // Handle DNS errors as a special case.
    
    if ( [[error domain] isEqual:(NSString *)kCFErrorDomainCFNetwork] && ([error code] == kCFHostErrorUnknown) ) {
        failureNum = [[error userInfo] objectForKey:(id)kCFGetAddrInfoFailureKey];
        if ( [failureNum isKindOfClass:[NSNumber class]] ) {
            failure = [failureNum intValue];
            if (failure != 0) {
                failureStr = gai_strerror(failure);
                if (failureStr != NULL) {
                    result = [NSString stringWithUTF8String:failureStr];
                    assert(result != nil);
                }
            }
        }
    }
    
    // Otherwise try various properties of the error object.
    
    if (result == nil) {
        result = [error localizedFailureReason];
    }
    if (result == nil) {
        result = [error localizedDescription];
    }
    if (result == nil) {
        result = [error description];
    }
    assert(result != nil);
    return result;
}

- (void)runWithHostName:(NSString *)hostName
// The Objective-C 'main' for this program.  It creates a SimplePing object
// and runs the runloop sending pings and printing the results.
{
    assert(self.pinger == nil);
    
    self.pinger = [SimplePing simplePingWithHostName:hostName];
    assert(self.pinger != nil);
    
    self.pinger.delegate = (id)self;
    
    [self.pinger start];
    
    do {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    } while (self.pinger != nil);
}

- (void)sendPing
// Called to send a ping, both directly (as soon as the SimplePing object starts up)
// and via a timer (to continue sending pings periodically).
{
    startTimer = mach_absolute_time(); // Start the clock
    sentCount += 1;
    
    assert(self.pinger != nil);
    [self.pinger sendPingWithData:nil];
}

- (void)simplePing:(SimplePing *)pinger didStartWithAddress:(NSData *)address
// A SimplePing delegate callback method.  We respond to the startup by sending a
// ping immediately and starting a timer to continue sending them every second.
{
#pragma unused(pinger)
    assert(pinger == self.pinger);
    assert(address != nil);
    destinationAddress = DisplayAddressForAddress(address);
    
    NSString *pingResponseStr = [NSString stringWithFormat:@"Pinging %@:\n", destinationAddress];
    self.showResults.text = pingResponseStr;
    self.showStatistics.text = @"Available when current ping stops ...";
    
    // Send the first ping straight away.
    
    [self sendPing];
    
    // And start a timer to send the subsequent pings.
    
    assert(self.sendTimer == nil);
    self.sendTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(sendPing) userInfo:nil repeats:YES];
}

- (void)simplePing:(SimplePing *)pinger didFailWithError:(NSError *)error
// A SimplePing delegate callback method.  We shut down our timer and the
// SimplePing object itself, which causes the runloop code to exit.
{
#pragma unused(pinger)
    assert(pinger == self.pinger);
#pragma unused(error)
    NSString *pingResponseStr = [NSString stringWithFormat:@"Cannot resolve address. Unknown host."];
    self.showResults.text = pingResponseStr;
    
    // More verbose error message, not used at this time:
    // [self.showResults setText:[self shortErrorFromError:error]];
    
    [self.sendTimer invalidate];
    self.sendTimer = nil;
    
    // No need to call -stop.  The pinger will stop itself in this case.
    // We do however want to nil out pinger so that the runloop stops.
    
    self.pinger = nil;
}

- (void)simplePing:(SimplePing *)pinger didSendPacket:(NSData *)packet
// A SimplePing delegate callback method.  We just log the send.
{
#pragma unused(pinger)
    assert(pinger == self.pinger);
#pragma unused(packet)
    // NSString *sentString;
    // sentString = [NSString stringWithFormat:@"%u", (unsigned int) OSSwapBigToHostInt16(((const ICMPHeader *) [packet bytes])->sequenceNumber)];
}

- (void)simplePing:(SimplePing *)pinger didFailToSendPacket:(NSData *)packet error:(NSError *)error
// A SimplePing delegate callback method.  We just log the failure.
{
#pragma unused(pinger)
    assert(pinger == self.pinger);
#pragma unused(packet)
#pragma unused(error)
    unsigned int pingResponseInt = (unsigned int) OSSwapBigToHostInt16(((const ICMPHeader *) [packet bytes])->sequenceNumber);
    NSString *pingResponseStr = [NSString stringWithFormat:@"[%u] Request timed out\n", pingResponseInt];
    self.showResults.text = [self.showResults.text stringByAppendingString:pingResponseStr];
    [self.showResults scrollRangeToVisible:NSMakeRange([self.showResults.text length], 0)];
}

- (void)simplePing:(SimplePing *)pinger didReceivePingResponsePacket:(NSData *)packet
// A SimplePing delegate callback method.  We just log the reception of a ping response.
{
    NSMutableArray *statisticsArray = [Globals array];
    
    stopTimer = mach_absolute_time(); // Stop the clock
    
    if (0.0 == ticksToNanoseconds) {
        mach_timebase_info_data_t timebase;
        mach_timebase_info(&timebase);
        ticksToNanoseconds = (double)timebase.numer / timebase.denom;
    }
    diffTimer = (((stopTimer - startTimer) * ticksToNanoseconds) / 1000000); // Calculate elapsed time in ms
    [statisticsArray addObject:[NSNumber numberWithFloat:diffTimer]];
    receivedCount += 1;
    
#pragma unused(pinger)
    assert(pinger == self.pinger);
#pragma unused(packet)
    
    unsigned int pingResponseInt = (unsigned int) OSSwapBigToHostInt16([SimplePing icmpInPacket:packet]->sequenceNumber);
    
    NSString *pingResponseStr = [NSString stringWithFormat:@"[%u] Reply from %@: %.02f ms\n", pingResponseInt, destinationAddress, diffTimer];
    
    self.showResults.text = [self.showResults.text stringByAppendingString:pingResponseStr];
    [self.showResults scrollRangeToVisible:NSMakeRange([self.showResults.text length], 0)];
    
    // If the sound switch is on, play a sound for each received ping
    // If a broadcast address is pinged and multiple responses are received, just play the sound once
    if ((soundSwitch.on == YES) && (receivedCount <= sentCount)) {
        NSString *soundPath = [[NSBundle mainBundle] pathForResource:@"Ping" ofType:@"aiff"];
        SystemSoundID soundID;
        AudioServicesCreateSystemSoundID((__bridge CFURLRef)([NSURL fileURLWithPath: soundPath]), &soundID);
        AudioServicesPlaySystemSound (soundID);
    }
}

/* ----- Decided not to implement at this time -----
 
 - (void)simplePing:(SimplePing *)pinger didReceiveUnexpectedPacket:(NSData *)packet
 // A SimplePing delegate callback method.  We just log the receive.
 {
 const ICMPHeader *icmpPtr;
 
 #pragma unused(pinger)
 assert(pinger == self.pinger);
 #pragma unused(packet)
 
 icmpPtr = [SimplePing icmpInPacket:packet];
 if (icmpPtr != NULL) {
 NSString *pingResponseStr = [NSString stringWithFormat:@"Received ICMP: type=%u, code=%u\n", (unsigned int) icmpPtr->type, (unsigned int) icmpPtr->code];
 self.showResults.text = [self.showResults.text stringByAppendingString:pingResponseStr];
 [self.showResults scrollRangeToVisible:NSMakeRange([self.showResults.text length], 0)];
 }
 else {
 NSString *pingResponseStr = [NSString stringWithFormat:@"Packet size=%zu", (size_t) [packet length]];
 self.showResults.text = [self.showResults.text stringByAppendingString:pingResponseStr];
 [self.showResults scrollRangeToVisible:NSMakeRange([self.showResults.text length], 0)];
 }
 }
 */

- (IBAction)startPing:(id)sender
{
    NSMutableArray *statisticsArray = [Globals array];
    
    self.showResults.text = @"";        // Clear results when a new ping is started
    self.showStatistics.text = @"";     // Clear statistics when a new ping is started
    [statisticsArray removeAllObjects]; // Clear statistics history array
    sentCount = 0, receivedCount = 0;   // Clear counters when a new ping is started
    
    if ([self.getAddress.text length] > 0) {
        [self stopPing:NULL]; // If ping is already running, stop it first
        [self runWithHostName:self.getAddress.text];
    }
    return;
}

- (IBAction)stopPing:(id)sender
{
    NSMutableArray *statisticsArray = [Globals array];
    NSNumber *minTimer = [statisticsArray valueForKeyPath:@"@min.self"];
    NSNumber *maxTimer = [statisticsArray valueForKeyPath:@"@max.self"];
    NSNumber *avgTimer = [statisticsArray valueForKeyPath:@"@avg.self"];
    NSNumber *stdDev = [self standardDeviationOf:statisticsArray];
    
    // Clean up for display for min, max, avg, and SD
    NSNumberFormatter *format = [[NSNumberFormatter alloc]init];
    [format setMinimumFractionDigits:2];
    [format setMaximumFractionDigits:2];
    format.numberStyle = NSNumberFormatterDecimalStyle;
    
    if (sentCount > 0) {
        if (receivedCount > sentCount) { // We received more than we sent! Must be a broadcast address?
            packetLoss = 0.00; // Manually set packet loss to 0.0%, otherwise the calculation won't make sense.
        }
        else {
            packetLoss = 100 - (((float)receivedCount / (float)sentCount) * 100);
        }
        if (receivedCount > 0) {
            NSString *statisticsStr = [NSString stringWithFormat:@"Packets: %d Sent, %d Received, %.02f%% Lost\nMinimum: %@ ms, Maximum: %@ ms\nAverage: %@ ms, StdDev: %@ ms", sentCount, receivedCount, packetLoss, [format stringFromNumber:minTimer], [format stringFromNumber:maxTimer], [format stringFromNumber:avgTimer], [format stringFromNumber:stdDev]];
            self.showStatistics.text = statisticsStr;
        }
        else { // We got nothing back, so we can't calculate the remaining statistics!
            NSString *statisticsStr = [NSString stringWithFormat:@"Packets: %d Sent, %d Received, %.01f%% Lost\nMinimum: N/A, Maximum: N/A\nAverage: N/A, StdDev: N/A", sentCount, receivedCount, packetLoss];
            self.showStatistics.text = statisticsStr;
        }
    }
    
    [self->_pinger stop];
    [self.sendTimer invalidate];
    self.pinger = nil;
    self.sendTimer = nil;
    return;
}

- (void)dealloc
{
    [self->_pinger stop];
    [self->_sendTimer invalidate];
}

@end
