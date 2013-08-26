//
//  CBPSettingsViewController.m
//  SelfieCam
//
//  Created by Karl Monaghan on 19/08/2013.
//  Copyright (c) 2013 Karl Monaghan. All rights reserved.
//

#import "CBPSettingsViewController.h"
#import "CBPAboutViewController.h"

@interface CBPSettingsViewController ()
@property (strong, nonatomic) UIStepper *changeNumberOfFaces;
@property (strong, nonatomic) UIStepper *photoTimer;
@property (strong, nonatomic) UISwitch *smileActivation;
@property (strong, nonatomic) UISwitch *winkActivation;
@property (strong, nonatomic) UISwitch *showFaceBoxes;
@property (strong, nonatomic) UISwitch *facebookShare;
@property (strong, nonatomic) UISwitch *twitterShare;

@property (strong, nonatomic) NSUserDefaults *userDefaults;
@end

@implementation CBPSettingsViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
        self.title = NSLocalizedString(@"Settings", nil);
        
    }
    return self;
}

- (void)loadView
{
    [super loadView];
    
    self.userDefaults = [NSUserDefaults standardUserDefaults];
    
    self.changeNumberOfFaces = [UIStepper new];
    self.changeNumberOfFaces.minimumValue = 1;
    self.changeNumberOfFaces.maximumValue = 5;
    self.changeNumberOfFaces.value = [self.userDefaults doubleForKey:@"faces"];
    [self.changeNumberOfFaces addTarget:self action:@selector(numberOfFacesChanged) forControlEvents:UIControlEventValueChanged];
    
    self.photoTimer = [UIStepper new];
    self.photoTimer.minimumValue = 0;
    self.photoTimer.maximumValue = 5;
    self.photoTimer.value = [self.userDefaults doubleForKey:@"photo_timer"];
    [self.photoTimer addTarget:self action:@selector(photoTimerChanged) forControlEvents:UIControlEventValueChanged];
    
    self.smileActivation = [UISwitch new];
    self.smileActivation.on = [self.userDefaults boolForKey:@"smile"];
    
    self.winkActivation = [UISwitch new];
    self.winkActivation.on = [self.userDefaults boolForKey:@"wink"];
    
    self.showFaceBoxes = [UISwitch new];
    self.showFaceBoxes.on = [self.userDefaults boolForKey:@"boxes"];
    
    self.facebookShare = [UISwitch new];
    self.facebookShare.on = [self.userDefaults boolForKey:@"facebook"];
    
    self.twitterShare = [UISwitch new];
    self.twitterShare.on = [self.userDefaults boolForKey:@"twitter"];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                          target:self
                                                                                          action:@selector(done)];
}

- (void)done
{
    [self.userDefaults setDouble:self.changeNumberOfFaces.value forKey:@"faces"];
    [self.userDefaults setDouble:self.photoTimer.value forKey:@"photo_timer"];
    [self.userDefaults setBool:self.smileActivation.on forKey:@"smile"];
    [self.userDefaults setBool:self.winkActivation.on forKey:@"wink"];
    [self.userDefaults setBool:self.showFaceBoxes.on forKey:@"boxes"];
    [self.userDefaults setBool:self.facebookShare.on forKey:@"facebook"];
    [self.userDefaults setBool:self.twitterShare.on forKey:@"twitter"];
    
    [self.userDefaults synchronize];
    
    [[self parentViewController] dismissViewControllerAnimated:YES completion:nil];
}

- (void)about
{
    CBPAboutViewController *vc = [[CBPAboutViewController alloc] initWithStyle:UITableViewStyleGrouped];
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    
    [self presentViewController:nav animated:YES completion:nil];
}

#pragma mark -
- (void)photoTimerChanged
{
    [self.tableView reloadData];
}

- (void)numberOfFacesChanged
{
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    int rows = 0;
    
    switch (section) {
        case 0:
            rows = 5;
            break;
        case 1:
            rows = 1;
            break;
    }
    
    return rows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if(cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        cell.textLabel.minimumScaleFactor = 0.75f;
        cell.textLabel.adjustsFontSizeToFitWidth = YES;
    }
    
    if (indexPath.section == 0)
    {
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.accessoryView = nil;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        switch (indexPath.row) {
            case 0:
                cell.textLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Faces in view: %.f", nil), self.changeNumberOfFaces.value];
                cell.accessoryView = self.changeNumberOfFaces;
                break;
            case 1:
                if (self.photoTimer.value == 1)
                {
                    cell.textLabel.text = NSLocalizedString(@"Take photo after 1 second", nil);
                }
                else
                {
                    cell.textLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Take photo after %.f seconds", nil), self.photoTimer.value];
                }
                cell.accessoryView = self.photoTimer;
                break;
            case 2:
                cell.textLabel.text = NSLocalizedString(@"Take photo when you smile", nil);
                cell.accessoryView = self.smileActivation;
                break;
            case 3:
                cell.textLabel.text =  NSLocalizedString(@"Take photo when you wink", nil);
                cell.accessoryView = self.winkActivation;
                break;
            case 4:
                cell.textLabel.text =  NSLocalizedString(@"Show boxes around faces", nil);
                cell.accessoryView = self.showFaceBoxes;
                break;
            default:
                break;
        }
    } else if (indexPath.section == 1) {
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
        cell.accessoryType = UITableViewCellAccessoryNone;
        
        switch (indexPath.row) {
            case 0:
                cell.textLabel.text = NSLocalizedString(@"About", nil);
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                break;
                
            default:
                break;
        }
        
    }
        return cell;
}

#pragma mark - UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ((indexPath.section == 1) && (indexPath.row == 0))
    {
        [self about];
    }
}
@end
