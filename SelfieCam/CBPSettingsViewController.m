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
@property (strong, nonatomic) UISwitch *smileActivation;
@property (strong, nonatomic) UISwitch *winkActivation;
@property (strong, nonatomic) NSUserDefaults *userDefaults;
@end

@implementation CBPSettingsViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
        self.title = NSLocalizedString(@"Settings", nil);
        
        self.userDefaults = [NSUserDefaults standardUserDefaults];
        
        self.changeNumberOfFaces = [UIStepper new];
        self.changeNumberOfFaces.minimumValue = 1;
        self.changeNumberOfFaces.maximumValue = 5;
        self.changeNumberOfFaces.stepValue = [self.userDefaults doubleForKey:@"faces"];
        [self.changeNumberOfFaces addTarget:self action:@selector(numberOfFacesChanged) forControlEvents:UIControlEventValueChanged];
        
        self.smileActivation = [UISwitch new];
        self.smileActivation.on = [self.userDefaults boolForKey:@"smile"];
        
        self.winkActivation = [UISwitch new];
        self.winkActivation.on = [self.userDefaults boolForKey:@"wink"];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                          target:self
                                                                                          action:@selector(done)];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)done
{
    [self.userDefaults setDouble:self.changeNumberOfFaces.value forKey:@"faces"];
    [self.userDefaults setBool:self.smileActivation.on forKey:@"smile"];
    [self.userDefaults setBool:self.winkActivation.on forKey:@"wink"];
    
    [self.userDefaults synchronize];
    
    [[self parentViewController] dismissViewControllerAnimated:YES completion:nil];
}

- (void)about
{
    CBPAboutViewController *vc = [[CBPAboutViewController alloc] initWithStyle:UITableViewStyleGrouped];
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    
    [self presentViewController:nav animated:YES completion:nil];
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
    return (section) ? 1 : 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if(cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
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
                cell.textLabel.text = NSLocalizedString(@"Take photo when you smile", nil);
                cell.accessoryView = self.smileActivation;
                break;
            case 2:
                cell.textLabel.text =  NSLocalizedString(@"Take photo when you wink", nil);
                cell.accessoryView = self.winkActivation;
                break;
            default:
                break;
        }
        
        
        
    } else {
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
    switch (indexPath.row) {
        case 0:
            [self about];
            break;
            
        default:
            break;
    }
}
@end
