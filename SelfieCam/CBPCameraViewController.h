//
//  CBPViewController.h
//  SelfieCam
//
//  Created by Karl Monaghan on 02/08/2013.
//  Copyright (c) 2013 Karl Monaghan. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

#import "ASMediaFocusManager.h"

@interface CBPCameraViewController : UIViewController <AVCaptureVideoDataOutputSampleBufferDelegate, ASMediasFocusDelegate>

@end
