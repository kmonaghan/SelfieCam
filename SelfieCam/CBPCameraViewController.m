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

#import "CBPCameraViewController.h"
#import "CBPSettingsViewController.h"

#define TOTALFACE_FRAMES 15

const CGFloat FACE_RECT_BORDER_WIDTH = 3;

static char * const AVCaptureStillImageIsCapturingStillImageContext = "AVCaptureStillImageIsCapturingStillImageContext";
static CGFloat DegreesToRadians(CGFloat degrees) {return degrees * M_PI / 180;};
void writeJPEGDataToCameraRoll(NSData* data, NSDictionary* metadata);
static AVCaptureVideoOrientation avOrientationForDeviceOrientation(UIDeviceOrientation deviceOrientation);
CGRect videoPreviewBoxForGravity(NSString *gravity, CGSize frameSize, CGSize apertureSize);

void displayErrorOnMainQueue(NSError *error, NSString *message);

@interface CBPCameraViewController ()
{
    UIView *cameraView;
    UIView *flashView;
    UIView *controlView;
    UILabel *countdownLabel;
    
    int count;
    BOOL isTakingPhoto;
    BOOL detectedFeature;
    BOOL useFrontCamera;
    
    UISwitch *autoPhoto;
    
    UIButton *takePhotoButton;
    UIButton *settingsButton;
    UIButton *doneButton;
    UIButton *switchCamerasButton;
    
    int faceFrameCount;
    CGFloat topOffset;
    CGFloat bottomOffset;
}

@property (strong,nonatomic) AVCaptureSession *session;
@property (strong,nonatomic) AVCaptureVideoPreviewLayer *previewLayer;
@property (strong,nonatomic) AVCaptureVideoDataOutput *videoDataOutput;
@property (strong,nonatomic) AVCaptureStillImageOutput *stillImageOutput;

@property (strong,nonatomic) CIDetector *faceDetector;
@property (strong,nonatomic) NSMutableArray *ciFaceLayers;

@property (strong, nonatomic) NSArray *controlButtonPortraitConstraints;
@property (strong, nonatomic) NSArray *controlPortraitConstraints;
@property (strong, nonatomic) NSArray *controlButtonLandscapeLeftConstraints;
@property (strong, nonatomic) NSArray *controlButtonLandscapeRightConstraints;
@property (strong, nonatomic) NSArray *controlLandscapeLeftConstraints;
@property (strong, nonatomic) NSArray *controlLandscapeRightConstraints;
@property (strong, nonatomic) NSArray *switchCameraPortraitConstraints;
@property (strong, nonatomic) NSArray *switchCameraLandscapeRightConstraints;

@property (strong, nonatomic) NSUserDefaults *userDefaults;
@end

@implementation CBPCameraViewController
- (void)dealloc
{
	[self teardownAVCapture];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    useFrontCamera = NO;
    
    isTakingPhoto = NO;
    
    autoPhoto.on = NO;
    
    self.userDefaults = [NSUserDefaults standardUserDefaults];
    
    [self loadSettings];
    
    [self setupAVCapture];
	NSDictionary *detectorOptions = @{CIDetectorAccuracy : CIDetectorAccuracyLow, CIDetectorTracking : @YES};
	self.faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:detectorOptions];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)loadView
{
    UIView *view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    //view.backgroundColor = [UIColor greenColor];
    
    if (view.frame.size.height == 480.0f)
    {
        topOffset = 0;
        bottomOffset = 53.0f;
    } else {
        topOffset = 44.0f;
        bottomOffset = 97.0f;
    }
    
    cameraView = [[UIView alloc] initWithFrame:CGRectMake(0, topOffset, 320.0f, 427.0f)];
    cameraView.backgroundColor = [UIColor whiteColor];
    
    [view addSubview:cameraView];
    
    switchCamerasButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [switchCamerasButton setTitle:NSLocalizedString(@"Switch", nil) forState:UIControlStateNormal];
    [switchCamerasButton addTarget:self action:@selector(updateCameraSelection) forControlEvents:UIControlEventTouchUpInside];
    [switchCamerasButton sizeToFit];
    switchCamerasButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    [view addSubview:switchCamerasButton];
    
    NSMutableArray *portraitButton = @[].mutableCopy;
    [portraitButton addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"[switchCamerasButton]-|"
                                                                                options:0
                                                                                metrics:nil
                                                                                  views:NSDictionaryOfVariableBindings(switchCamerasButton)]];
    
    [portraitButton addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(5)-[switchCamerasButton]"
                                                                                options:0
                                                                                metrics:nil
                                                                                  views:NSDictionaryOfVariableBindings(switchCamerasButton)]];
    
    [view addConstraints:portraitButton];
    
    self.switchCameraPortraitConstraints = portraitButton;
    
    NSMutableArray *landScapeButton = @[].mutableCopy;
    [landScapeButton addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[switchCamerasButton]"
                                                                                 options:0
                                                                                 metrics:nil
                                                                                   views:NSDictionaryOfVariableBindings(switchCamerasButton)]];
    
    [landScapeButton addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(5)-[switchCamerasButton]"
                                                                                 options:0
                                                                                 metrics:nil
                                                                                   views:NSDictionaryOfVariableBindings(switchCamerasButton)]];
    
    self.switchCameraLandscapeRightConstraints = landScapeButton;
    
    countdownLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    countdownLabel.font = [UIFont boldSystemFontOfSize:200.0f];
    countdownLabel.textColor = [UIColor whiteColor];
    countdownLabel.backgroundColor = [UIColor clearColor];
    countdownLabel.text = @"3";
    countdownLabel.textAlignment = NSTextAlignmentCenter;
    countdownLabel.center = view.center;
    countdownLabel.alpha = 0;
    countdownLabel.minimumScaleFactor = 0.01f;
    countdownLabel.adjustsFontSizeToFitWidth = YES;
    countdownLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    [view addSubview:countdownLabel];
    
    [view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|[countdownLabel]|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:NSDictionaryOfVariableBindings(countdownLabel)]];
    [view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[countdownLabel]|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:NSDictionaryOfVariableBindings(countdownLabel)]];
    
    flashView = [[UIView alloc] initWithFrame:CGRectZero];
    flashView.alpha = 0.0f;
    flashView.backgroundColor = [UIColor whiteColor];
    flashView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [view addSubview:flashView];
    
    [view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|[flashView]|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:NSDictionaryOfVariableBindings(flashView)]];
    [view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[flashView]|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:NSDictionaryOfVariableBindings(flashView)]];
    
    controlView = [[UIView alloc] initWithFrame:CGRectZero];
    controlView.translatesAutoresizingMaskIntoConstraints = NO;
    
    UIView *controlBackgroundView = [[UIView alloc] initWithFrame:CGRectZero];
    controlBackgroundView.backgroundColor = [UIColor whiteColor];
    controlBackgroundView.alpha = 0.5f;
    controlBackgroundView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [controlView addSubview:controlBackgroundView];
    
    [controlView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|[controlBackgroundView]|"
                                                                        options:0
                                                                        metrics:nil
                                                                          views:NSDictionaryOfVariableBindings(controlBackgroundView)]];
    [controlView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[controlBackgroundView]|"
                                                                        options:0
                                                                        metrics:nil
                                                                          views:NSDictionaryOfVariableBindings(controlBackgroundView)]];
    
    autoPhoto = [[UISwitch alloc] init];
    autoPhoto.translatesAutoresizingMaskIntoConstraints = NO;
    
    [controlView addSubview:autoPhoto];
    
    takePhotoButton = [UIButton buttonWithType:UIButtonTypeCustom];
    takePhotoButton.translatesAutoresizingMaskIntoConstraints = NO;
    [takePhotoButton setTitle:NSLocalizedString(@"Photo", nil) forState:UIControlStateNormal];
    [takePhotoButton addTarget:self
                        action:@selector(startCountdown)
              forControlEvents:UIControlEventTouchUpInside];
    [takePhotoButton sizeToFit];
    
    [controlView addSubview:takePhotoButton];
    
    settingsButton = [UIButton buttonWithType:UIButtonTypeCustom];
    settingsButton.translatesAutoresizingMaskIntoConstraints = NO;
    [settingsButton addTarget:self action:@selector(showSettings) forControlEvents:UIControlEventTouchUpInside];
    [settingsButton setTitle:NSLocalizedString(@"Settings", nil) forState:UIControlStateNormal];
    [settingsButton sizeToFit];
    
    [controlView addSubview:settingsButton];
    
    
    NSMutableArray *verticalbuttonConstraints = @[].mutableCopy;
    
    [verticalbuttonConstraints addObject:[NSLayoutConstraint constraintWithItem:autoPhoto
                                                                      attribute:NSLayoutAttributeCenterY
                                                                      relatedBy:NSLayoutRelationEqual
                                                                         toItem:controlView
                                                                      attribute:NSLayoutAttributeCenterY
                                                                     multiplier:1.0f
                                                                       constant:0.0f]];
    
    [verticalbuttonConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[autoPhoto]"
                                                                                           options:0
                                                                                           metrics:nil
                                                                                             views:NSDictionaryOfVariableBindings(autoPhoto)]];
    
    [verticalbuttonConstraints addObject:[NSLayoutConstraint constraintWithItem:takePhotoButton
                                                                      attribute:NSLayoutAttributeCenterX
                                                                      relatedBy:NSLayoutRelationEqual
                                                                         toItem:controlView
                                                                      attribute:NSLayoutAttributeCenterX
                                                                     multiplier:1.0f
                                                                       constant:0.0f]];
    [verticalbuttonConstraints addObject:[NSLayoutConstraint constraintWithItem:takePhotoButton
                                                                      attribute:NSLayoutAttributeCenterY
                                                                      relatedBy:NSLayoutRelationEqual
                                                                         toItem:controlView
                                                                      attribute:NSLayoutAttributeCenterY
                                                                     multiplier:1.0f
                                                                       constant:0.0f]];
    
    [verticalbuttonConstraints addObject:[NSLayoutConstraint constraintWithItem:settingsButton
                                                                      attribute:NSLayoutAttributeCenterY
                                                                      relatedBy:NSLayoutRelationEqual
                                                                         toItem:controlView
                                                                      attribute:NSLayoutAttributeCenterY
                                                                     multiplier:1.0f
                                                                       constant:0.0f]];
    
    [verticalbuttonConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"[settingsButton]-|"
                                                                                           options:0
                                                                                           metrics:nil
                                                                                             views:NSDictionaryOfVariableBindings(settingsButton)]];
    
    [controlView addConstraints:verticalbuttonConstraints];
    
    self.controlButtonPortraitConstraints = verticalbuttonConstraints;
    
    NSMutableArray *horizontalButtonConstraints = @[].mutableCopy;
    
    [horizontalButtonConstraints addObject:[NSLayoutConstraint constraintWithItem:autoPhoto
                                                                        attribute:NSLayoutAttributeCenterX
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:controlView
                                                                        attribute:NSLayoutAttributeCenterX
                                                                       multiplier:1.0f
                                                                         constant:0.0f]];
    
    [horizontalButtonConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[autoPhoto]"
                                                                                             options:0
                                                                                             metrics:nil
                                                                                               views:NSDictionaryOfVariableBindings(autoPhoto)]];
    
    [horizontalButtonConstraints addObject:[NSLayoutConstraint constraintWithItem:takePhotoButton
                                                                        attribute:NSLayoutAttributeCenterX
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:controlView
                                                                        attribute:NSLayoutAttributeCenterX
                                                                       multiplier:1.0f
                                                                         constant:0.0f]];
    
    [horizontalButtonConstraints addObject:[NSLayoutConstraint constraintWithItem:takePhotoButton
                                                                        attribute:NSLayoutAttributeCenterY
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:controlView
                                                                        attribute:NSLayoutAttributeCenterY
                                                                       multiplier:1.0f
                                                                         constant:0.0f]];
    
    
    [horizontalButtonConstraints addObject:[NSLayoutConstraint constraintWithItem:settingsButton
                                                                        attribute:NSLayoutAttributeCenterX
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:controlView
                                                                        attribute:NSLayoutAttributeCenterX
                                                                       multiplier:1.0f
                                                                         constant:0.0f]];
    
    [horizontalButtonConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[settingsButton]-|"
                                                                                             options:0
                                                                                             metrics:nil
                                                                                               views:NSDictionaryOfVariableBindings(settingsButton)]];
    
    self.controlButtonLandscapeLeftConstraints = horizontalButtonConstraints;
    
    NSMutableArray *horizontalRightButtonConstraints = @[].mutableCopy;
    
    [horizontalRightButtonConstraints addObject:[NSLayoutConstraint constraintWithItem:autoPhoto
                                                                        attribute:NSLayoutAttributeCenterX
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:controlView
                                                                        attribute:NSLayoutAttributeCenterX
                                                                       multiplier:1.0f
                                                                         constant:0.0f]];
    
    [horizontalRightButtonConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[autoPhoto]-|"
                                                                                             options:0
                                                                                             metrics:nil
                                                                                               views:NSDictionaryOfVariableBindings(autoPhoto)]];
    
    [horizontalRightButtonConstraints addObject:[NSLayoutConstraint constraintWithItem:takePhotoButton
                                                                        attribute:NSLayoutAttributeCenterX
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:controlView
                                                                        attribute:NSLayoutAttributeCenterX
                                                                       multiplier:1.0f
                                                                         constant:0.0f]];
    
    [horizontalRightButtonConstraints addObject:[NSLayoutConstraint constraintWithItem:takePhotoButton
                                                                        attribute:NSLayoutAttributeCenterY
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:controlView
                                                                        attribute:NSLayoutAttributeCenterY
                                                                       multiplier:1.0f
                                                                         constant:0.0f]];
    
    
    [horizontalRightButtonConstraints addObject:[NSLayoutConstraint constraintWithItem:settingsButton
                                                                        attribute:NSLayoutAttributeCenterX
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:controlView
                                                                        attribute:NSLayoutAttributeCenterX
                                                                       multiplier:1.0f
                                                                         constant:0.0f]];
    
    [horizontalRightButtonConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[settingsButton]"
                                                                                             options:0
                                                                                             metrics:nil
                                                                                               views:NSDictionaryOfVariableBindings(settingsButton)]];
    
    self.controlButtonLandscapeRightConstraints = horizontalRightButtonConstraints;
    
    [view addSubview:controlView];
    
    
    self.view = view;
    
    NSMutableArray *portrait = [NSLayoutConstraint constraintsWithVisualFormat:@"|[controlView]|"
                                                                       options:0
                                                                       metrics:nil
                                                                         views:NSDictionaryOfVariableBindings(controlView)].mutableCopy;
    
    [portrait addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:[NSString stringWithFormat:@"V:[controlView(%f)]|", bottomOffset]
                                                                          options:0
                                                                          metrics:nil
                                                                            views:NSDictionaryOfVariableBindings(controlView)]];
    
    self.controlPortraitConstraints = portrait;
    
    [view addConstraints:self.controlPortraitConstraints];
    
    NSMutableArray *landscapeLeft = [NSLayoutConstraint constraintsWithVisualFormat:[NSString stringWithFormat:@"|[controlView(%f)]", bottomOffset]
                                                                            options:0
                                                                            metrics:nil
                                                                              views:NSDictionaryOfVariableBindings(controlView)].mutableCopy;
    [landscapeLeft addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[controlView]|"
                                                                               options:0
                                                                               metrics:nil
                                                                                 views:NSDictionaryOfVariableBindings(controlView)]];
    
    self.controlLandscapeLeftConstraints = landscapeLeft;
    
    NSMutableArray *landscapeRight = [NSLayoutConstraint constraintsWithVisualFormat:[NSString stringWithFormat:@"[controlView(%f)]|", bottomOffset]
                                                                             options:0
                                                                             metrics:nil
                                                                               views:NSDictionaryOfVariableBindings(controlView)].mutableCopy;
    [landscapeRight addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[controlView]|"
                                                                                options:0
                                                                                metrics:nil
                                                                                  views:NSDictionaryOfVariableBindings(controlView)]];
    
    self.controlLandscapeRightConstraints = landscapeRight;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration;
{
    [UIView setAnimationsEnabled:NO];
    
    [[self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:NO];
}

//Inspired by http://stackoverflow.com/a/7284073/806442
- (void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    float rotation = 0;
    CGRect cameraframe = CGRectMake(0, topOffset, 320.0f, 427.0f);
    
    if (toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) {
        rotation = M_PI/2;
        cameraframe = CGRectMake(bottomOffset, 0, 427.0f, 320.0f);
    } else if (toInterfaceOrientation == UIInterfaceOrientationLandscapeRight) {
        rotation = -M_PI/2;
        cameraframe = CGRectMake(topOffset, 0, 427.0f, 320.0f);
    }
    
    if ((toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) || (toInterfaceOrientation == UIInterfaceOrientationLandscapeRight))
    {
        [self.view removeConstraints:self.controlPortraitConstraints];
        
        if (toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft)
        {
            [self.view removeConstraints:self.controlLandscapeRightConstraints];
            [self.view addConstraints:self.controlLandscapeLeftConstraints];
        }
        else
        {
            [self.view removeConstraints:self.controlLandscapeLeftConstraints];
            [self.view addConstraints:self.controlLandscapeRightConstraints];
        }
    }
    else
    {
        [self.view removeConstraints:self.controlLandscapeLeftConstraints];
        [self.view removeConstraints:self.controlLandscapeRightConstraints];
        [self.view addConstraints:self.controlPortraitConstraints];
    }
    
    [self.view layoutIfNeeded];
    
    [UIView animateWithDuration:duration animations:^{
        cameraView.transform = CGAffineTransformMakeRotation(rotation);
        cameraView.frame = cameraframe;
    }];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [[self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:YES];
    
    [UIView setAnimationsEnabled:YES];
    
    [controlView removeConstraints:self.controlButtonPortraitConstraints];
    [controlView removeConstraints:self.controlButtonLandscapeLeftConstraints];
    [controlView removeConstraints:self.controlButtonLandscapeRightConstraints];
    
    if ((self.interfaceOrientation == UIInterfaceOrientationPortrait) || (self.interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown))
    {
        [self.view removeConstraints:self.switchCameraLandscapeRightConstraints];
        [self.view addConstraints:self.switchCameraPortraitConstraints];
        [controlView addConstraints:self.controlButtonPortraitConstraints];
    }
    else
    {
        if (self.interfaceOrientation == UIInterfaceOrientationLandscapeRight)
        {
            [self.view removeConstraints:self.switchCameraPortraitConstraints];
            [self.view addConstraints:self.switchCameraLandscapeRightConstraints];
            [controlView addConstraints:self.controlButtonLandscapeRightConstraints];
        }
        else
        {
            [self.view removeConstraints:self.switchCameraLandscapeRightConstraints];
            [self.view addConstraints:self.switchCameraPortraitConstraints];
            [controlView addConstraints:self.controlButtonLandscapeLeftConstraints];
        }
    }
    
    [UIView animateWithDuration:0.3f animations:^{
        [controlView layoutIfNeeded];
    }];
}

#pragma mark - AV setup
- (void)setupAVCapture
{
	self.session = [AVCaptureSession new];
	[self.session setSessionPreset:AVCaptureSessionPresetPhoto]; // high-res stills, screen-size video
	
	[self updateCameraSelection];
	
	// For displaying live feed to screen
	CALayer *rootLayer = cameraView.layer;
	[rootLayer setMasksToBounds:YES];
	self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
	[self.previewLayer setBackgroundColor:[[UIColor blackColor] CGColor]];
	[self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
	[self.previewLayer setFrame:[rootLayer bounds]];
	[rootLayer addSublayer:self.previewLayer];
	
    self.stillImageOutput = [AVCaptureStillImageOutput new];
	if ( [self.session canAddOutput:self.stillImageOutput] ) {
		[self.session addOutput:self.stillImageOutput];
	} else {
		self.stillImageOutput = nil;
	}
    
	self.ciFaceLayers = [NSMutableArray arrayWithCapacity:10];
	
	NSDictionary *detectorOptions = @{ CIDetectorAccuracy : CIDetectorAccuracyLow, CIDetectorTracking : @(YES) };
	self.faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:detectorOptions];
	
	self.videoDataOutput = [AVCaptureVideoDataOutput new];
	NSDictionary *rgbOutputSettings = @{ (__bridge NSString*)kCVPixelBufferPixelFormatTypeKey : @(kCMPixelFormat_32BGRA) };
	[self.videoDataOutput setVideoSettings:rgbOutputSettings];
	
	if ( ! [self.session canAddOutput:self.videoDataOutput] ) {
		[self teardownAVCapture];
		return;
	}
    
	// CoreImage face detection is CPU intensive and runs at reduced framerate.
	// Thus we set AlwaysDiscardsLateVideoFrames, and operate a separate dispatch queue
	[self.videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
	dispatch_queue_t videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
	[self.videoDataOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];
	
	[self.session addOutput:self.videoDataOutput];
	
	[self updateCoreImageDetection:nil];
	
	// this will allow us to sync freezing the preview when the image is being captured
	[self.stillImageOutput addObserver:self
                            forKeyPath:@"capturingStillImage"
                               options:NSKeyValueObservingOptionNew
                               context:AVCaptureStillImageIsCapturingStillImageContext];
    
	[self.session startRunning];
}

- (void)teardownAVCapture
{
    [self.session stopRunning];
	
	[self.stillImageOutput removeObserver:self forKeyPath:@"capturingStillImage"];
	
    if ( self.videoDataOutput )
		[self.session removeOutput:self.videoDataOutput];
	self.videoDataOutput = nil;
	self.faceDetector = nil;
	[self resizeCoreImageFaceLayerCache:0];
	self.ciFaceLayers = nil;
	
	[self.previewLayer removeFromSuperlayer];
	self.previewLayer = nil;
	
	self.session = nil;
}

- (IBAction) updateCoreImageDetection:(UISwitch *)sender {
	if ( !self.videoDataOutput )
		return;
	
    BOOL detectFaces = YES;
    
	// enable/disable the AVCaptureVideoDataOutput to control the flow of AVCaptureVideoDataOutputSampleBufferDelegate calls
	[[self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:detectFaces];
	
	// update graphics associated with previously detected faces
	[CATransaction begin];
	[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
	[CATransaction commit];
	
	if ( ! detectFaces ) {
		// dispatch to the end of queue in case a delegate call was already pending before we stopped the output
		dispatch_async(dispatch_get_main_queue(), ^(void) { [self resizeCoreImageFaceLayerCache:0]; });
	}
}

- (void) updateCameraSelection
{
	// Changing the camera device will reset connection state, so we call the
	// update*Detection functions to resync them.  When making multiple
	// session changes, wrap in a beginConfiguration / commitConfiguration.
	// This will avoid consecutive session restarts for each configuration
	// change (noticeable delay and camera flickering)
	
	[self.session beginConfiguration];
	
	// have to remove old inputs before we test if we can add a new input
	NSArray* oldInputs = [self.session inputs];
	for (AVCaptureInput *oldInput in oldInputs)
		[self.session removeInput:oldInput];
	
    useFrontCamera = !useFrontCamera;
    
	AVCaptureDeviceInput* input = [self pickCamera];
	if ( ! input ) {
		// failed, restore old inputs
		for (AVCaptureInput *oldInput in oldInputs)
			[self.session addInput:oldInput];
	} else {
		// succeeded, set input and update connection states
		[self.session addInput:input];
		[self updateCoreImageDetection:nil];
	}
	[self.session commitConfiguration];
}

- (AVCaptureDeviceInput*) pickCamera
{
	AVCaptureDevicePosition desiredPosition = (useFrontCamera) ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack;
	BOOL hadError = NO;
	for (AVCaptureDevice *d in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
		if ([d position] == desiredPosition) {
			NSError *error = nil;
			AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:d error:&error];
			if (error) {
				hadError = YES;
				displayErrorOnMainQueue(error, @"Could not initialize for AVMediaTypeVideo");
			} else if ( [self.session canAddInput:input] ) {
				return input;
			}
		}
	}
	if ( ! hadError ) {
		// no errors, simply couldn't find a matching camera
		displayErrorOnMainQueue(nil, @"No camera found for requested orientation");
	}
	return nil;
}

#pragma mark -
- (void) resizeCoreImageFaceLayerCache:(NSInteger)newSize
{
	while( [self.ciFaceLayers count] < newSize) {
		// add required layers
		CALayer *featureLayer = [CALayer new];
        
		[featureLayer setBorderColor:[[UIColor redColor] CGColor]];
		[featureLayer setBorderWidth:FACE_RECT_BORDER_WIDTH];
		[self.previewLayer addSublayer:featureLayer];
		[self.ciFaceLayers addObject:featureLayer];
	}
	while(newSize < [self.ciFaceLayers count]) {
		// delete extra layers
		[(CALayer*)[self.ciFaceLayers lastObject] removeFromSuperlayer];
		[self.ciFaceLayers removeLastObject];
	}
}

// called asynchronously as the capture output is capturing sample buffers, this method asks the face detector (if on)
// to detect features and for each draw the red square in a layer and set appropriate orientation
- (void)drawFaceBoxesForFeatures:(NSArray *)features forVideoBox:(CGRect)clap orientation:(UIDeviceOrientation)orientation
{
    [self resizeCoreImageFaceLayerCache:[features count]];
    
    if (![features count])
    {
        return;
    }
    
	// Update the face graphics
	[CATransaction begin];
	[CATransaction setAnimationDuration:1];
    
	CGRect previewBox = videoPreviewBoxForGravity(self.previewLayer.videoGravity, cameraView.frame.size, clap.size);
    
	NSInteger currentFeature = 0;
    BOOL isMirrored = self.previewLayer.connection.isVideoMirrored;
    
	for ( CIFaceFeature *ff in features ) {
        if ((&CIDetectorEyeBlink != NULL) && !detectedFeature && autoPhoto.on)
        {
            if (ff.hasSmile && [self.userDefaults boolForKey:@"smile"])
            {
                detectedFeature = YES;
                
                [self updateCountdownLabel:NSLocalizedString(@"Smile!", nil) forDuration:1.0f onCompletion:^(){[self startCountdown];}];
            }
            if ((ff.rightEyeClosed || ff.leftEyeClosed) && [self.userDefaults boolForKey:@"wink"])
            {
                detectedFeature = YES;
                
                [self updateCountdownLabel:NSLocalizedString(@"Wink!", nil) forDuration:1.0f onCompletion:^(){[self startCountdown];}];
            }
        }
        
        if ([self.userDefaults boolForKey:@"boxes"])
        {
            // Find the correct position for the face layer within the previewLayer
            // The feature box originates in the bottom left of the video frame.
            // (Bottom right if mirroring is turned on)
            CGRect faceRect = [ff bounds];
            
            // flip preview width and height
            CGFloat temp = faceRect.size.width;
            faceRect.size.width = faceRect.size.height;
            faceRect.size.height = temp;
            temp = faceRect.origin.x;
            faceRect.origin.x = faceRect.origin.y;
            faceRect.origin.y = temp;
            // scale coordinates so they fit in the preview box, which may be scaled
            CGFloat widthScaleBy = previewBox.size.width / clap.size.height;
            CGFloat heightScaleBy = previewBox.size.height / clap.size.width;
            faceRect.size.width *= widthScaleBy;
            faceRect.size.height *= heightScaleBy;
            faceRect.origin.x *= widthScaleBy;
            faceRect.origin.y *= heightScaleBy;
            
            if ( isMirrored )
                faceRect = CGRectOffset(faceRect, previewBox.origin.x + previewBox.size.width - faceRect.size.width - (faceRect.origin.x * 2), previewBox.origin.y);
            else
                faceRect = CGRectOffset(faceRect, previewBox.origin.x, previewBox.origin.y);
            
            CALayer *featureLayer = [self.ciFaceLayers objectAtIndex:currentFeature];
            
            [featureLayer setFrame:faceRect];
            
            switch (orientation) {
                case UIDeviceOrientationPortrait:
                    [featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(0.))];
                    break;
                case UIDeviceOrientationPortraitUpsideDown:
                    [featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(180.))];
                    break;
                case UIDeviceOrientationLandscapeLeft:
                    [featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(90.))];
                    break;
                case UIDeviceOrientationLandscapeRight:
                    [featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(-90.))];
                    break;
                case UIDeviceOrientationFaceUp:
                case UIDeviceOrientationFaceDown:
                default:
                    break; // leave the layer in its last known orientation
            }
        }
		currentFeature++;
		
	}
    
	[CATransaction commit];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    // Got an image.
	CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
	NSDictionary* attachments = (__bridge_transfer NSDictionary*)CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
	CIImage *ciImage = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer options:attachments];
	UIDeviceOrientation curDeviceOrientation = [[UIDevice currentDevice] orientation];
	
	enum {
		PHOTOS_EXIF_0ROW_TOP_0COL_LEFT			= 1, //   1  =  0th row is at the top, and 0th column is on the left (THE DEFAULT).
		PHOTOS_EXIF_0ROW_TOP_0COL_RIGHT			= 2, //   2  =  0th row is at the top, and 0th column is on the right.
		PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT      = 3, //   3  =  0th row is at the bottom, and 0th column is on the right.
		PHOTOS_EXIF_0ROW_BOTTOM_0COL_LEFT       = 4, //   4  =  0th row is at the bottom, and 0th column is on the left.
		PHOTOS_EXIF_0ROW_LEFT_0COL_TOP          = 5, //   5  =  0th row is on the left, and 0th column is the top.
		PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP         = 6, //   6  =  0th row is on the right, and 0th column is the top.
		PHOTOS_EXIF_0ROW_RIGHT_0COL_BOTTOM      = 7, //   7  =  0th row is on the right, and 0th column is the bottom.
		PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM       = 8  //   8  =  0th row is on the left, and 0th column is the bottom.
	};
	
	int exifOrientation;
	switch (curDeviceOrientation) {
		case UIDeviceOrientationPortraitUpsideDown:  // Device oriented vertically, home button on the top
			exifOrientation = PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM;
			break;
		case UIDeviceOrientationLandscapeLeft:       // Device oriented horizontally, home button on the right
			if (useFrontCamera)
				exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
			else
				exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
			break;
		case UIDeviceOrientationLandscapeRight:      // Device oriented horizontally, home button on the left
			if (useFrontCamera)
				exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
			else
				exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
			break;
		case UIDeviceOrientationPortrait:            // Device oriented vertically, home button on the bottom
		default:
			exifOrientation = PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP;
			break;
	}
    
    
	NSDictionary *imageOptions;
    if (&CIDetectorEyeBlink != NULL)
    {
        imageOptions = @{CIDetectorImageOrientation: @(exifOrientation), CIDetectorSmile:@YES, CIDetectorEyeBlink:@YES};
    }
    else
    {
        imageOptions = @{CIDetectorImageOrientation: @(exifOrientation)};
    }
    
	NSArray *features = [self.faceDetector featuresInImage:ciImage options:imageOptions];
    
	CMFormatDescriptionRef fdesc = CMSampleBufferGetFormatDescription(sampleBuffer);
	CGRect clap = CMVideoFormatDescriptionGetCleanAperture(fdesc, false /*originIsTopLeft*/);
	
    if (([features count] == [self.userDefaults doubleForKey:@"faces"]) && autoPhoto.on) {
        faceFrameCount++;
        
        if (faceFrameCount > TOTALFACE_FRAMES) {
            [self startCountdown];
            
            faceFrameCount = 0;
        }
    } else {
        faceFrameCount = 0;
    }
    
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		[self drawFaceBoxesForFeatures:features forVideoBox:clap orientation:curDeviceOrientation];
	});
}


#pragma mark - Camera actions
- (void)startCountdown
{
    if (!isTakingPhoto) {
        [self.view bringSubviewToFront:countdownLabel];
        
        count = 3;
        takePhotoButton.enabled = NO;
        
        [self showCountDown];
        
        isTakingPhoto = YES;
    }
}

- (void)showCountDown
{
    if (count != 0) {
        [self updateCountdownLabel:[NSString stringWithFormat:@"%d", count] forDuration:1.0f onCompletion:^(){[self showCountDown];}];
        count--;
    } else {
        [self takePhoto];
    }
}

- (void)updateCountdownLabel:(NSString *)text forDuration:(CGFloat)duration onCompletion:(void (^)(void))complete
{
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        countdownLabel.text = text;
        
        countdownLabel.alpha = 1.0f;
        [UIView animateWithDuration:duration
                         animations:^() {
                             countdownLabel.alpha = 0;
                         }
                         completion:^(BOOL finished) {
                             complete();
                         }];
    });
}

- (void)takePhoto
{
	// Find out the current orientation and tell the still image output.
	AVCaptureConnection *stillImageConnection = [self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
	UIDeviceOrientation curDeviceOrientation = [[UIDevice currentDevice] orientation];
	AVCaptureVideoOrientation avcaptureOrientation = avOrientationForDeviceOrientation(curDeviceOrientation);
	[stillImageConnection setVideoOrientation:avcaptureOrientation];
	[stillImageConnection setVideoScaleAndCropFactor:1];
	[stillImageConnection setAutomaticallyAdjustsVideoMirroring:NO];
	[stillImageConnection setVideoMirrored:[self.previewLayer.connection isVideoMirrored]];
    
    [self.stillImageOutput setOutputSettings:@{AVVideoCodecKey: AVVideoCodecJPEG}];
    
	[self.stillImageOutput captureStillImageAsynchronouslyFromConnection:stillImageConnection
                                                       completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
                                                           if (error) {
                                                               displayErrorOnMainQueue(error, @"Take picture failed");
                                                           } else if ( ! imageDataSampleBuffer ) {
                                                               displayErrorOnMainQueue(nil, @"Take picture failed: received null sample buffer");
                                                           } else {
                                                               NSData *jpegData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                                                               NSDictionary* attachments = (__bridge_transfer NSDictionary*) CMCopyDictionaryOfAttachments(kCFAllocatorDefault, imageDataSampleBuffer, kCMAttachmentMode_ShouldPropagate);
                                                               writeJPEGDataToCameraRoll(jpegData, attachments);
                                                           }
                                                           
                                                           dispatch_async(dispatch_get_main_queue(), ^(void) {
                                                               [self unfreezePreview];
                                                           });
                                                       }];
}

// this will freeze the preview when a still image is captured, we will unfreeze it when the graphics code is finished processing the image
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ( context == AVCaptureStillImageIsCapturingStillImageContext ) {
		BOOL isCapturingStillImage = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
		
		if ( isCapturingStillImage ) {
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [UIView animateWithDuration:.2f
                                 animations:^{ flashView.alpha=1.0f; }
                 ];
            });
			self.previewLayer.connection.enabled = NO;
		}
	}
}

// Graphics code will call this when still image capture processing is complete
- (void) unfreezePreview
{
	self.previewLayer.connection.enabled = YES;
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [UIView animateWithDuration:.2f
                         animations:^{ flashView.alpha=0; }
                         completion:nil];
    });
    isTakingPhoto = NO;
    detectedFeature = NO;
    takePhotoButton.enabled = YES;
    faceFrameCount = 0;
    
    [autoPhoto setOn:NO animated:YES];
}

#pragma mark -
- (void)showSettings
{
    CBPSettingsViewController *vc = [[CBPSettingsViewController alloc] initWithStyle:UITableViewStyleGrouped];
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    
    [self presentViewController:nav animated:YES
                     completion:^(){
                         [self loadSettings];
                     }];
}

- (void)loadSettings
{
    [self.userDefaults synchronize];
    
    if ([self.userDefaults doubleForKey:@"faces"] < 1)
    {
        [self.userDefaults setDouble:1 forKey:@"faces"];
        [self.userDefaults synchronize];
    }
}

@end

// Finds where the video box is positioned within the preview layer based on the video size and gravity
CGRect videoPreviewBoxForGravity(NSString *gravity, CGSize frameSize, CGSize apertureSize)
{
    CGFloat apertureRatio = apertureSize.height / apertureSize.width;
    CGFloat viewRatio = frameSize.width / frameSize.height;
    
    CGSize size = CGSizeZero;
    if ([gravity isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
        if (viewRatio > apertureRatio) {
            size.width = frameSize.width;
            size.height = apertureSize.width * (frameSize.width / apertureSize.height);
        } else {
            size.width = apertureSize.height * (frameSize.height / apertureSize.width);
            size.height = frameSize.height;
        }
    } else if ([gravity isEqualToString:AVLayerVideoGravityResizeAspect]) {
        if (viewRatio > apertureRatio) {
            size.width = apertureSize.height * (frameSize.height / apertureSize.width);
            size.height = frameSize.height;
        } else {
            size.width = frameSize.width;
            size.height = apertureSize.width * (frameSize.width / apertureSize.height);
        }
    } else if ([gravity isEqualToString:AVLayerVideoGravityResize]) {
        size.width = frameSize.width;
        size.height = frameSize.height;
    }
	
	CGRect videoBox;
	videoBox.size = size;
	if (size.width < frameSize.width)
		videoBox.origin.x = (frameSize.width - size.width) / 2;
	else
		videoBox.origin.x = (size.width - frameSize.width) / 2;
	
	if ( size.height < frameSize.height )
		videoBox.origin.y = (frameSize.height - size.height) / 2;
	else
		videoBox.origin.y = (size.height - frameSize.height) / 2;
	
	return videoBox;
}

void displayErrorOnMainQueue(NSError *error, NSString *message)
{
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		UIAlertView* alert = [UIAlertView new];
		if(error) {
			alert.title = [NSString stringWithFormat:@"%@ (%zd)", message, error.code];
			alert.message = [error localizedDescription];
		} else {
			alert.title = message;
		}
		[alert addButtonWithTitle:@"Dismiss"];
		[alert show];
	});
}

// writes the image to the asset library
void writeJPEGDataToCameraRoll(NSData* data, NSDictionary* metadata)
{
	ALAssetsLibrary *library = [ALAssetsLibrary new];
	[library writeImageDataToSavedPhotosAlbum:data metadata:metadata completionBlock:^(NSURL *assetURL, NSError *error) {
		if (error) {
			displayErrorOnMainQueue(error, @"Save to camera roll failed");
		}
	}];
}

// converts UIDeviceOrientation to AVCaptureVideoOrientation
static AVCaptureVideoOrientation avOrientationForDeviceOrientation(UIDeviceOrientation deviceOrientation)
{
	AVCaptureVideoOrientation result = AVCaptureVideoOrientationPortrait;
	if ( deviceOrientation == UIDeviceOrientationLandscapeLeft )
		result = AVCaptureVideoOrientationLandscapeRight;
	else if ( deviceOrientation == UIDeviceOrientationLandscapeRight )
		result = AVCaptureVideoOrientationLandscapeLeft;
	return result;
}
