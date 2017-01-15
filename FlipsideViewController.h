//
//  FlipsideViewController.h
//  Pingy
//
//  Created by Richard Davis on 9/20/13.
//  Copyright (c) 2013 Richard Davis. All rights reserved.
//

#import <UIKit/UIKit.h>

@class FlipsideViewController;

@protocol FlipsideViewControllerDelegate

- (void)flipsideViewControllerDidFinish:(FlipsideViewController *)controller;

@end

@interface FlipsideViewController : UIViewController {
    IBOutlet UIWebView *myWebView;
}

@property (weak, nonatomic) id <FlipsideViewControllerDelegate> delegate;

- (IBAction)done:(id)sender;

@end
