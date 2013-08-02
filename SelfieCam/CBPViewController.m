//
//  CBPViewController.m
//  SelfieCam
//
//  Created by Karl Monaghan on 02/08/2013.
//  Copyright (c) 2013 Karl Monaghan. All rights reserved.
//

#import <AssertMacros.h>
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>
#import <AssertMacros.h>
#import <AssetsLibrary/AssetsLibrary.h>

#import "CBPViewController.h"

@interface CBPViewController ()
{
    UILabel *countdownLabel;
    int count;
    
    UIButton *takePhotoButton;
    
    UIView *cameraView;
    
    AVCaptureStillImageOutput *stillImageOutput;
    AVCaptureVideoDataOutput *videoDataOutput;
    AVCaptureVideoPreviewLayer *previewLayer;
    
    dispatch_queue_t videoDataOutputQueue;
    
    CIDetector *faceDetector;
    
    int frameNum;
}
@end

@implementation CBPViewController
- (void)dealloc
{
	[self teardownAVCapture];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    [self setupAVCapture];
	NSDictionary *detectorOptions = @{CIDetectorAccuracy : CIDetectorAccuracyLow };
	faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:detectorOptions];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)loadView
{
    UIView *view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    
    CGFloat cameraHeight = [UIScreen mainScreen].bounds.size.height - 50.0f;
    
    UIView *controlView = [[UIView alloc] initWithFrame:CGRectMake(0, cameraHeight, [UIScreen mainScreen].bounds.size.width, 50.0f)];
    controlView.backgroundColor = [UIColor blackColor];
    
    takePhotoButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [takePhotoButton setTitle:@"Photo" forState:UIControlStateNormal];
    [takePhotoButton addTarget:self
                        action:@selector(startCountdown)
              forControlEvents:UIControlEventTouchUpInside];
    [takePhotoButton sizeToFit];
    takePhotoButton.center = CGPointMake([UIScreen mainScreen].bounds.size.width / 2, 25.0f);
    
    [controlView addSubview:takePhotoButton];
    
    [view addSubview:controlView];
    
    cameraView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, cameraHeight)];
    cameraView.backgroundColor = [UIColor whiteColor];
    
    [view addSubview:cameraView];
    
    countdownLabel = [[UILabel alloc] initWithFrame:[UIScreen mainScreen].bounds];
    countdownLabel.text = @"3";
    countdownLabel.font = [UIFont boldSystemFontOfSize:150.0f];
    countdownLabel.textColor = [UIColor whiteColor];
    countdownLabel.backgroundColor = [UIColor clearColor];
    [countdownLabel sizeToFit];
    countdownLabel.center = view.center;
    countdownLabel.alpha = 0;
    
    [view addSubview:countdownLabel];
    
    self.view = view;
}

#pragma mark - AV setup
- (void)setupAVCapture
{
	NSError *error = nil;
	
	AVCaptureSession *session = [AVCaptureSession new];
	[session setSessionPreset:AVCaptureSessionPresetPhoto];
	
    // Select a video device, make an input
	AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *d in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
		if ([d position] == AVCaptureDevicePositionFront) {
			device = d;
			break;
		}
	}
    
	AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
	require( error == nil, bail );
	{
        if ( [session canAddInput:deviceInput] )
            [session addInput:deviceInput];
        
        // Make a still image output
        stillImageOutput = [AVCaptureStillImageOutput new];
        
        if ( [session canAddOutput:stillImageOutput] )
            [session addOutput:stillImageOutput];
        
        // Make a video data output
        videoDataOutput = [AVCaptureVideoDataOutput new];
        
        // we want BGRA, both CoreGraphics and OpenGL work well with 'BGRA'
        NSDictionary *rgbOutputSettings = [NSDictionary dictionaryWithObject:
                                           [NSNumber numberWithInt:kCMPixelFormat_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
        [videoDataOutput setVideoSettings:rgbOutputSettings];
        [videoDataOutput setAlwaysDiscardsLateVideoFrames:YES]; // discard if the data output queue is blocked (as we process the still image)
        [[videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:YES];
        
        // create a serial dispatch queue used for the sample buffer delegate as well as when a still image is captured
        // a serial dispatch queue must be used to guarantee that video frames will be delivered in order
        // see the header doc for setSampleBufferDelegate:queue: for more information
        videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
        [videoDataOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];
        
        if ( [session canAddOutput:videoDataOutput] )
            [session addOutput:videoDataOutput];
        [[videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:NO];
        
        previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
        [previewLayer setBackgroundColor:[[UIColor blackColor] CGColor]];
        [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
        CALayer *rootLayer = [cameraView layer];
        [rootLayer setMasksToBounds:YES];
        [previewLayer setFrame:[rootLayer bounds]];
        [rootLayer addSublayer:previewLayer];
        [session startRunning];
        
        frameNum = 0;
    }
bail:
    {
        if (error) {
            [[[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"Failed with error %d", (int)[error code]]
                                        message:[error localizedDescription]
                                       delegate:nil
                              cancelButtonTitle:@"Dismiss"
                              otherButtonTitles:nil] show];
            
            [self teardownAVCapture];
        }
    }
    
    
}

- (void)teardownAVCapture
{
	[stillImageOutput removeObserver:self forKeyPath:@"isCapturingStillImage"];
    
	[previewLayer removeFromSuperlayer];
}

#pragma mark - Camera actions
- (void)startCountdown
{
    count = 3;
    takePhotoButton.enabled = NO;
    
    [self showCountDown];
}

- (void)showCountDown
{
    if (count != 0) {
        countdownLabel.text = [NSString stringWithFormat:@"%d", count];
        count--;
        countdownLabel.alpha = 1;
        
        [UIView animateWithDuration:1.0f
                         animations:^() {
                             countdownLabel.alpha = 0;
                         }
                         completion:^(BOOL finished) {
                             [self showCountDown];
                         }];
    } else {
        [self takePhoto];
    }
}

- (void)takePhoto
{
    takePhotoButton.enabled = YES;
    
    UIView *flashView = [[UIView alloc] initWithFrame:[self.view frame]];
    [flashView setBackgroundColor:[UIColor whiteColor]];
    [flashView setAlpha:0.f];
    [[[self view] window] addSubview:flashView];
    
    [UIView animateWithDuration:0.2f
                     animations:^{
                         [flashView setAlpha:1.f];
                     }
                     completion:^(BOOL finished) {
                         [flashView removeFromSuperview];
                     }
     ];
}

@end
