//
//  MainViewController.h
//  Pingy
//
//  Created by Richard Davis on 9/20/13.
//  Copyright (c) 2013 Richard Davis. All rights reserved.
//

#import "FlipsideViewController.h"

@interface Globals : NSObject

+ (NSMutableArray*)array;

@end

@interface MainViewController : UIViewController <FlipsideViewControllerDelegate, UITextFieldDelegate> {
    NSString *destinationAddress;
    int receivedCount, sentCount;
    double diffTimer, packetLoss, ticksToNanoseconds;
    uint64_t startTimer, stopTimer;
    
    IBOutlet UISwitch *soundSwitch;
}

- (IBAction)startPing:(id)sender;
- (IBAction)stopPing:(id)sender;

@property (strong, nonatomic) IBOutlet UITextField *getAddress;
@property (strong, nonatomic) IBOutlet UITextView *showResults;
@property (strong, nonatomic) IBOutlet UITextView *showStatistics;

@end
