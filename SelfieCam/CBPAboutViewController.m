//
//  CBPAboutViewController.m
//  Santa List
//
//  Created by Karl Monaghan on 25/09/2012.
//  Copyright (c) 2012 Crayons and Brown Paper. All rights reserved.
//

#import <Social/Social.h>

#import "CBPAboutViewController.h"
#import "CBPWebViewController.h"

#define kAppId  @"710446375"

@interface CBPAboutViewController ()
@property (strong, nonatomic) NSString *appName;
@end

@implementation CBPAboutViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                          target:self
                                                                                          action:@selector(done)];
    self.appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
    
    self.navigationItem.title = self.appName;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.navigationController setNavigationBarHidden:NO animated:YES];
}

- (void)done
{
    [[self parentViewController] dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case 0:
            return 3;
            break;
        case 1:
            return 3;
            break;
        case 2:
            return 1;
            break;
        default:
            break;
    }
    
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"AboutCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    // Configure the cell...
    switch (indexPath.section)
    {
        case 0:
        {
            switch (indexPath.row) {
                case 0:
                {
                    cell.textLabel.text = [NSString stringWithFormat:@"Rate %@", self.appName];
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                }
                    break;
                case 1:
                {
                    cell.textLabel.text = NSLocalizedString(@"Share this App", nil);
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                }
                    break;
                case 2:
                {
                    cell.textLabel.text = NSLocalizedString(@"Contact Us", nil);
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                }
                    break;
                default:
                    break;
            }
        }
            break;
        case 1:
        {
            switch (indexPath.row) {
                case 0:
                {
                    cell.textLabel.text = NSLocalizedString(@"More Apps", nil);
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                }
                    break;
                case 1:
                {
                    cell.textLabel.text = NSLocalizedString(@"About the Developer", nil);
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                }
                    break;
                case 2:
                {
                    cell.textLabel.text = NSLocalizedString(@"3rd party libraries", nil);
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                }
                default:
                    break;
            }
        }
            break;
        case 2:
        {
            switch (indexPath.row) {
                case 0:
                {
                    cell.textLabel.text = @"Version";
                    cell.detailTextLabel.text = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
                }
                    break;
                default:
                    break;
            }
        }
            break;
        default:
            break;
            
    }
    
    return cell;
}

#pragma mark - Table view delegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [[tableView cellForRowAtIndexPath:indexPath] setSelected:NO animated:YES];
    
    switch (indexPath.section)
    {
        case 0:
        {
            switch (indexPath.row)
            {
                case 0:
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"itms-apps://ax.itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?type=Purple+Software&id=%@", kAppId]]];
                    break;
                case 1:
                {
                    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Share", nil)
                                                                       delegate:self
                                                              cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                                         destructiveButtonTitle:nil
                                                              otherButtonTitles:NSLocalizedString(@"Facebook", nil), NSLocalizedString(@"Twitter", nil), NSLocalizedString(@"Email", nil), nil];
                    [sheet showInView:self.view];
                    
                }
                    break;
                case 2:
                    [self sendEmail];
                default:
                    break;
            }
        }
            break;
        case 1:
        {
            switch (indexPath.row)
            {
                case 0:
                {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://itunes.apple.com/WebObjects/MZStore.woa/wa/viewArtist?id=427412037"]];
                }
                    break;
                case 1:
                {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://karlmonaghan.com/about"]];
                }
                    break;
                case 2:
                {
                    CBPWebViewController *libraries = [[CBPWebViewController alloc] initWithWebURL:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"libraries" ofType:@"html"] isDirectory:NO]]];
                    
                    [self.navigationController pushViewController:libraries animated:YES];
                }
                default:
                    break;
            }
        }
            break;
            
        default:
            break;
    }
}

#pragma mark Facebook
- (void)postToFacebookFeed
{
    if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeFacebook])
    {
        SLComposeViewController *facebookSheet = [SLComposeViewController
                                               composeViewControllerForServiceType:SLServiceTypeFacebook];
        
        [facebookSheet setInitialText:[NSString stringWithFormat:@"%@ is a great little app from @CrayonsBrownPap", self.appName]];
        
        [facebookSheet addURL: [NSURL URLWithString:[NSString stringWithFormat:@"https://itunes.apple.com/ie/app/id%@?mt=8", kAppId]]];
        
        [self.navigationController presentViewController:facebookSheet animated:YES completion:nil];
    }
    else
    {
        UIAlertView *alertView = [[UIAlertView alloc]
                                  initWithTitle:NSLocalizedString(@"No Facebook Account", nil)
                                  message:NSLocalizedString(@"You must set up at least one account in Settings > Facebook before you can share via Facebook", nil)
                                  delegate:self
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil];
        [alertView show];
    }
}

#pragma mark Twitter
- (void)postToTwitter
{
    if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeTwitter])
    {
        SLComposeViewController *tweetSheet = [SLComposeViewController
                                               composeViewControllerForServiceType:SLServiceTypeTwitter];
        
        [tweetSheet setInitialText:[NSString stringWithFormat:@"%@ is a great little app from @CrayonsBrownPap", self.appName]];
        
        [tweetSheet addURL: [NSURL URLWithString:[NSString stringWithFormat:@"https://itunes.apple.com/ie/app/id%@?mt=8", kAppId]]];
        
        [self.navigationController presentViewController:tweetSheet animated:YES completion:nil];
    }
    else
    {
        UIAlertView *alertView = [[UIAlertView alloc]
                                  initWithTitle:NSLocalizedString(@"No Twitter Accounts", nil)
                                  message:NSLocalizedString(@"You must set up at least one account in Settings > Twitter before you can share via Twitter", nil)
                                  delegate:self
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil];
        [alertView show];
    }
}

#pragma mark Send Email
- (void)shareViaEmail
{
    
    if ([MFMailComposeViewController canSendMail])
    {
        MFMailComposeViewController *mailer = [[MFMailComposeViewController alloc] init];
        
        mailer.mailComposeDelegate = self;
        
        NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
        
        [mailer setSubject:[NSString stringWithFormat:@"You may like this app: %@", [infoDictionary objectForKey:@"CFBundleName"]]];
        
        NSString *body = [NSString stringWithFormat:@"Hi,<br /><br />I thought you might like %@.  You can download it from the <a href=\"%@\">iTunes App Store</a>.", [infoDictionary objectForKey:@"CFBundleName"], [NSString stringWithFormat:@"https://itunes.apple.com/ie/app/id%@?mt=8", kAppId]];
        [mailer setMessageBody:body isHTML:YES];

        [self.navigationController presentViewController:mailer animated:YES completion:nil];
    }
    else
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No email settings"
                                                        message:@"You can't send emails from this device"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }
}

- (void)sendEmail
{
    if ([MFMailComposeViewController canSendMail])
    {
        MFMailComposeViewController *mailer = [[MFMailComposeViewController alloc] init];
        
        mailer.mailComposeDelegate = self;
        
        NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
        
        [mailer setSubject:[NSString stringWithFormat:@"Feedback for %@", [infoDictionary objectForKey:@"CFBundleName"]]];
        
        NSString *body = [NSString stringWithFormat:@"\n\n\nApp version: %@ (%@)\niOS Version: %@\niOS Device: %@", [infoDictionary objectForKey:@"CFBundleShortVersionString"], [infoDictionary objectForKey:@"CFBundleVersion"], [[UIDevice currentDevice] systemVersion], [[UIDevice currentDevice] model]];
        [mailer setMessageBody:body isHTML:NO];
        
        [mailer setToRecipients:@[@"feedback@crayonsandbrownpaper.com"]];
         
        [self.navigationController presentViewController:mailer animated:YES completion:nil];
    }
    else
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No email settings"
                                                        message:@"You can't send emails from this device"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }
}

#pragma mark MFMailComposeViewControllerDelegate
- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error
{
    switch (result)
    {
        case MFMailComposeResultCancelled:
            DLog(@"Mail cancelled: you cancelled the operation and no email message was queued.");
            break;
        case MFMailComposeResultSaved:
            DLog(@"Mail saved: you saved the email message in the drafts folder.");
            break;
        case MFMailComposeResultSent:
            DLog(@"Mail send: the email message is queued in the outbox. It is ready to send.");
            break;
        case MFMailComposeResultFailed:
            DLog(@"Mail failed: the email message was not saved or queued, possibly due to an error.");
            break;
        default:
            DLog(@"Mail not sent.");
            break;
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma  mark UIActionSheetDelegate
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 3)
    {
        return;
    }
    
    switch (buttonIndex) {
        case 0:
        {
            [self postToFacebookFeed];
        }
            break;
        case 1:
        {
            [self postToTwitter];
        }
            break;
        case 2:
        {
            [self shareViaEmail];
        }
            break;
        default:
            break;
    }
}
@end
