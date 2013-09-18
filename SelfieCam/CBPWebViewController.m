//
//  KMWebViewController.m
//  KMWordPress
//
//  Created by Karl Monaghan on 30/10/2012.
//  Copyright (c) 2012 Crayons and Brown Paper. All rights reserved.
//

#import "CBPWebViewController.h"

@interface CBPWebViewController ()
@property (strong, nonatomic) IBOutlet UIWebView *webView;

@property (strong, nonatomic) IBOutlet UIBarButtonItem *webBackButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *forwardButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *stopReloadButton;
@property (strong, nonatomic) UIActivityIndicatorView *activity;
@property (strong, nonatomic) IBOutlet UIToolbar *webToolBar;

@property (strong, nonatomic) NSURLRequest *request;
@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;


- (IBAction)backAction:(id)sender;
- (IBAction)forwardAction:(id)sender;
- (IBAction)stopStartAction:(id)sender;
- (IBAction)openInSafariAction:(id)sender;

@end

@implementation CBPWebViewController
- (id)initWithWebURL:(NSURLRequest *)request
{
    self = [self initWithNibName:@"CBPWebViewController" bundle:nil];
    if (self) {
        // Custom initialization
        self.request = request;
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)dealloc
{
    _webView.delegate = nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
    {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    self.view.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    
    // Do any additional setup after loading the view from its nib.
    self.activity = [UIActivityIndicatorView new];
    [self.activity startAnimating];
    self.activity.hidesWhenStopped = YES;
    self.activity.frame = CGRectMake(3,3,25,25);
    
    self.activityIndicator.hidden = YES;
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.activity];
    
    self.webView.delegate = self;
    
    self.webBackButton.enabled = NO;
    self.forwardButton.enabled = NO;
    
    [self.webView loadRequest:self.request];
}

- (IBAction)backAction:(id)sender
{
    [self.webView goBack];
}

- (IBAction)forwardAction:(id)sender
{
    [self.webView goForward];
}

- (IBAction)stopStartAction:(id)sender
{
    if (self.webView.isLoading)
    {
        [self.webView stopLoading];
    }
    else
    {
        [self.webView reload];
    }
}

- (IBAction)openInSafariAction:(id)sender
{
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:NSLocalizedString(@"Open in Safari", nil), NSLocalizedString(@"Copy To Clipboard", nil), nil];
    [sheet showInView:self.view];
}

#pragma mark - UIWebViewDelegate
- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    self.activityIndicator.hidden = YES;
    
    if (!webView.loading)
    {
        self.stopReloadButton.image = [UIImage imageNamed:@"reload.png"];
    
        self.webBackButton.enabled = [self.webView canGoBack];
        self.forwardButton.enabled = [self.webView canGoForward];
        
        [self.activity stopAnimating];
    }
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [self.activity startAnimating];
    
    self.activity.hidden = NO;
    
    self.stopReloadButton.image = [UIImage imageNamed:@"46-no.png"];
}

#pragma  mark UIActionSheetDelegate
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == actionSheet.cancelButtonIndex)
    {
        return;
    }
    
    switch (buttonIndex) {
        case 0:
        {
            [[UIApplication sharedApplication] openURL:[self.webView.request URL]];
        }
            break;
        case 1:
        {
            UIPasteboard *pb = [UIPasteboard generalPasteboard];
            [pb setString:[[self.webView.request URL] absoluteString]];
        }
            break;
        default:
            break;
    }
}
@end
