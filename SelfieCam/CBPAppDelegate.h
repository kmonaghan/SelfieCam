//
//  CBPAppDelegate.h
//  SelfieCam
//
//  Created by Karl Monaghan on 02/08/2013.
//  Copyright (c) 2013 Karl Monaghan. All rights reserved.
//

#import <UIKit/UIKit.h>

@class CBPCameraViewController;

@interface CBPAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) CBPCameraViewController *viewController;

@end
