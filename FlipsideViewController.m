//
//  FlipsideViewController.m
//  Pingy
//
//  Created by Richard Davis on 9/20/13.
//  Copyright (c) 2013 Richard Davis. All rights reserved.
//

#import "FlipsideViewController.h"

@interface FlipsideViewController ()

@end

@implementation FlipsideViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSString *build = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"About.html" ofType:nil];
    NSString *fileURLString = [[NSURL fileURLWithPath:filePath] absoluteString];
    NSString *params = [NSString stringWithFormat:@"?version=%@&build=%@", version, build];
    NSURL *fileURL = [NSURL URLWithString:[fileURLString stringByAppendingString:params]];
    [myWebView loadRequest:[NSURLRequest requestWithURL:fileURL]];
    [myWebView setOpaque:NO];
    myWebView.backgroundColor = [UIColor clearColor];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Actions

- (IBAction)done:(id)sender
{
    [self.delegate flipsideViewControllerDidFinish:self];
}

@end
