//
//  CBPViewController.m
//  SelfieCam
//
//  Created by Karl Monaghan on 02/08/2013.
//  Copyright (c) 2013 Karl Monaghan. All rights reserved.
//

#import "UIImage+Thumbnail.h"

#import <AssertMacros.h>
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>
#import <AssertMacros.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <Social/Social.h>

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
@property (strong, nonatomic) UIView *cameraView;
@property (strong, nonatomic) UIView *flashView;
@property (strong, nonatomic) UIView *controlView;
@property (strong, nonatomic) UIImageView *thumbView;

@property (strong, nonatomic) UILabel *countdownLabel;

@property (strong, nonatomic) UISwitch *autoPhoto;

@property (strong, nonatomic) UIButton *takePhotoButton;
@property (strong, nonatomic) UIButton *settingsButton;
@property (strong, nonatomic) UIButton *switchCamerasButton;
@property (strong, nonatomic) UIButton *sharePhotoOnTwitter;
@property (strong, nonatomic) UIButton *sharePhotoOnFacebook;

@property (assign, nonatomic) CGFloat topOffset;
@property (assign, nonatomic) CGFloat bottomOffset;
@property (assign, nonatomic) int count;
@property (assign, nonatomic) int faceFrameCount;
@property (assign, nonatomic) BOOL isTakingPhoto;
@property (assign, nonatomic) BOOL detectedFeature;
@property (assign, nonatomic) BOOL useFrontCamera;
@property (assign, nonatomic) BOOL cancelPicture;

@property (strong, nonatomic) AVCaptureSession *session;
@property (strong, nonatomic) AVCaptureVideoPreviewLayer *previewLayer;
@property (strong, nonatomic) AVCaptureVideoDataOutput *videoDataOutput;
@property (strong, nonatomic) AVCaptureStillImageOutput *stillImageOutput;

@property (strong, nonatomic) CIDetector *faceDetector;
@property (strong, nonatomic) NSMutableArray *ciFaceLayers;

@property (strong, nonatomic) NSUserDefaults *userDefaults;

@property (strong, nonatomic) UIImage *lastSelfie;
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
    self.useFrontCamera = NO;
    
    self.isTakingPhoto = NO;
    
    self.autoPhoto.on = NO;
    
    self.cancelPicture = NO;
    
    self.userDefaults = [NSUserDefaults standardUserDefaults];
    
    [self loadSettings];
    
    [self setupAVCapture];
	NSDictionary *detectorOptions = @{CIDetectorAccuracy : CIDetectorAccuracyLow, CIDetectorTracking : @YES};
	self.faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:detectorOptions];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.cancelPicture = NO;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(orientationChanged:)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    self.cancelPicture = YES;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIDeviceOrientationDidChangeNotification
                                                  object:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)loadView
{
    UIView *view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    
    if (view.frame.size.height == 480.0f)
    {
        self.topOffset = 0;
        self.bottomOffset = 53.0f;
    } else {
        self.topOffset = 44.0f;
        self.bottomOffset = 97.0f;
    }
    
    self.cameraView = [[UIView alloc] initWithFrame:CGRectMake(0, self.topOffset, 320.0f, 427.0f)];
    self.cameraView.backgroundColor = [UIColor whiteColor];
    
    [view addSubview:self.cameraView];
    
    self.switchCamerasButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.switchCamerasButton setTitle:NSLocalizedString(@"Switch", nil) forState:UIControlStateNormal];
    [self.switchCamerasButton addTarget:self action:@selector(updateCameraSelection) forControlEvents:UIControlEventTouchUpInside];
    [self.switchCamerasButton sizeToFit];
    self.switchCamerasButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    [view addSubview:self.switchCamerasButton];
    
    NSMutableArray *portraitButton = @[].mutableCopy;
    [portraitButton addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"[_switchCamerasButton]-|"
                                                                                options:0
                                                                                metrics:nil
                                                                                  views:NSDictionaryOfVariableBindings(_switchCamerasButton)]];
    
    [portraitButton addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(5)-[_switchCamerasButton]"
                                                                                options:0
                                                                                metrics:nil
                                                                                  views:NSDictionaryOfVariableBindings(_switchCamerasButton)]];
    
    [view addConstraints:portraitButton];
    
    self.countdownLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.countdownLabel.font = [UIFont boldSystemFontOfSize:200.0f];
    self.countdownLabel.textColor = [UIColor whiteColor];
    self.countdownLabel.backgroundColor = [UIColor clearColor];
    self.countdownLabel.text = @"3";
    self.countdownLabel.textAlignment = NSTextAlignmentCenter;
    self.countdownLabel.center = view.center;
    self.countdownLabel.alpha = 0;
    self.countdownLabel.minimumScaleFactor = 0.01f;
    self.countdownLabel.adjustsFontSizeToFitWidth = YES;
    self.countdownLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    [view addSubview:self.countdownLabel];
    
    [view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|[_countdownLabel]|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:NSDictionaryOfVariableBindings(_countdownLabel)]];
    [view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_countdownLabel]|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:NSDictionaryOfVariableBindings(_countdownLabel)]];
    
    self.flashView = [[UIView alloc] initWithFrame:CGRectZero];
    self.flashView.alpha = 0.0f;
    self.flashView.backgroundColor = [UIColor whiteColor];
    self.flashView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [view addSubview:self.flashView];
    
    [view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|[_flashView]|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:NSDictionaryOfVariableBindings(_flashView)]];
    [view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_flashView]|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:NSDictionaryOfVariableBindings(_flashView)]];
    
    self.controlView = [[UIView alloc] initWithFrame:CGRectZero];
    self.controlView.translatesAutoresizingMaskIntoConstraints = NO;
    
    UIView *controlBackgroundView = [[UIView alloc] initWithFrame:CGRectZero];
    controlBackgroundView.backgroundColor = [UIColor whiteColor];
    controlBackgroundView.alpha = 0.5f;
    controlBackgroundView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.controlView addSubview:controlBackgroundView];
    
    [self.controlView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|[controlBackgroundView]|"
                                                                        options:0
                                                                        metrics:nil
                                                                          views:NSDictionaryOfVariableBindings(controlBackgroundView)]];
    [self.controlView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[controlBackgroundView]|"
                                                                        options:0
                                                                        metrics:nil
                                                                          views:NSDictionaryOfVariableBindings(controlBackgroundView)]];
    
    self.thumbView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
    self.thumbView.translatesAutoresizingMaskIntoConstraints = NO;
    self.thumbView.image = [UIImage imageNamed:@"default.png"];
    
    [self.controlView addSubview:self.thumbView];
    
    self.sharePhotoOnTwitter = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.sharePhotoOnTwitter setImage:[UIImage imageNamed:@"twitter.png"] forState:UIControlStateNormal];
    [self.sharePhotoOnTwitter addTarget:self action:@selector(shareOnTwitter) forControlEvents:UIControlEventTouchUpInside];
    self.sharePhotoOnTwitter.frame = CGRectMake(0, 0, 40.0f, 40.0f);
    self.sharePhotoOnTwitter.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.controlView addSubview:self.sharePhotoOnTwitter];
    
    self.sharePhotoOnFacebook = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.sharePhotoOnFacebook setImage:[UIImage imageNamed:@"facebook.png"] forState:UIControlStateNormal];
    [self.sharePhotoOnFacebook addTarget:self action:@selector(shareOnFacebook) forControlEvents:UIControlEventTouchUpInside];
    self.sharePhotoOnFacebook.frame = CGRectMake(0, 0, 40.0f, 40.0f);

    self.sharePhotoOnFacebook.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.controlView addSubview:self.sharePhotoOnFacebook];

    [self.controlView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[_sharePhotoOnTwitter][_sharePhotoOnFacebook]"
                                                                        options:0
                                                                        metrics:nil
                                                                          views:NSDictionaryOfVariableBindings(_sharePhotoOnTwitter, _sharePhotoOnFacebook)]];
    
    [self.controlView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[_thumbView]-[_sharePhotoOnTwitter]"
                                                                        options:0
                                                                        metrics:nil
                                                                          views:NSDictionaryOfVariableBindings(_thumbView, _sharePhotoOnTwitter)]];
    
    [self.controlView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[_thumbView]-[_sharePhotoOnFacebook]"
                                                                        options:0
                                                                        metrics:nil
                                                                          views:NSDictionaryOfVariableBindings(_thumbView, _sharePhotoOnFacebook)]];
    
    self.autoPhoto = [[UISwitch alloc] init];
    self.autoPhoto.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.controlView addSubview:self.autoPhoto];
    /*
    takePhotoButton = [UIButton buttonWithType:UIButtonTypeCustom];
    takePhotoButton.translatesAutoresizingMaskIntoConstraints = NO;
    [takePhotoButton setTitle:NSLocalizedString(@"Photo", nil) forState:UIControlStateNormal];
    [takePhotoButton addTarget:self
                        action:@selector(startCountdown)
              forControlEvents:UIControlEventTouchUpInside];
    [takePhotoButton sizeToFit];
    
    [self.controlView addSubview:takePhotoButton];
    */
    self.settingsButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.settingsButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.settingsButton addTarget:self action:@selector(showSettings) forControlEvents:UIControlEventTouchUpInside];
    [self.settingsButton setTitle:NSLocalizedString(@"Settings", nil) forState:UIControlStateNormal];
    [self.settingsButton sizeToFit];
    
    [self.controlView addSubview:self.settingsButton];
    
    
    NSMutableArray *verticalbuttonConstraints = @[].mutableCopy;
    
    [verticalbuttonConstraints addObject:[NSLayoutConstraint constraintWithItem:self.thumbView
                                                                      attribute:NSLayoutAttributeCenterY
                                                                      relatedBy:NSLayoutRelationEqual
                                                                         toItem:self.controlView
                                                                      attribute:NSLayoutAttributeCenterY
                                                                     multiplier:1.0f
                                                                       constant:0.0f]];
    
    [verticalbuttonConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[_thumbView]"
                                                                                           options:0
                                                                                           metrics:nil
                                                                                             views:NSDictionaryOfVariableBindings(_thumbView)]];
    
    [verticalbuttonConstraints addObject:[NSLayoutConstraint constraintWithItem:self.autoPhoto
                                                                      attribute:NSLayoutAttributeCenterX
                                                                      relatedBy:NSLayoutRelationEqual
                                                                         toItem:self.controlView
                                                                      attribute:NSLayoutAttributeCenterX
                                                                     multiplier:1.0f
                                                                       constant:0.0f]];
    [verticalbuttonConstraints addObject:[NSLayoutConstraint constraintWithItem:self.autoPhoto
                                                                      attribute:NSLayoutAttributeCenterY
                                                                      relatedBy:NSLayoutRelationEqual
                                                                         toItem:self.controlView
                                                                      attribute:NSLayoutAttributeCenterY
                                                                     multiplier:1.0f
                                                                       constant:0.0f]];
    
    [verticalbuttonConstraints addObject:[NSLayoutConstraint constraintWithItem:self.settingsButton
                                                                      attribute:NSLayoutAttributeCenterY
                                                                      relatedBy:NSLayoutRelationEqual
                                                                         toItem:self.controlView
                                                                      attribute:NSLayoutAttributeCenterY
                                                                     multiplier:1.0f
                                                                       constant:0.0f]];
    
    [verticalbuttonConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"[_settingsButton]-|"
                                                                                           options:0
                                                                                           metrics:nil
                                                                                             views:NSDictionaryOfVariableBindings(_settingsButton)]];
    
    [self.controlView addConstraints:verticalbuttonConstraints];

    
    [view addSubview:self.controlView];
    
    
    self.view = view;
    
    NSMutableArray *portrait = [NSLayoutConstraint constraintsWithVisualFormat:@"|[_controlView]|"
                                                                       options:0
                                                                       metrics:nil
                                                                         views:NSDictionaryOfVariableBindings(_controlView)].mutableCopy;
    
    [portrait addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:[NSString stringWithFormat:@"V:[_controlView(%f)]|", self.bottomOffset]
                                                                          options:0
                                                                          metrics:nil
                                                                            views:NSDictionaryOfVariableBindings(_controlView)]];

    [view addConstraints:portrait];
    

}

- (BOOL)shouldAutorotate
{
    return NO;
}

#pragma mark -
- (double)rotation
{
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    double rotation = 0;
    
    switch (orientation) {
        case UIDeviceOrientationPortrait:
            rotation = 0;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            rotation = M_PI;
            break;
        case UIDeviceOrientationLandscapeLeft:
            rotation = M_PI_2;
            break;
        case UIDeviceOrientationLandscapeRight:
            rotation = -M_PI_2;
            break;
        case UIDeviceOrientationFaceDown:
        case UIDeviceOrientationFaceUp:
        case UIDeviceOrientationUnknown:
        default:
            rotation = 0;

    }
    
    return rotation;
}

#pragma mark - Notifications
// From http://stackoverflow.com/a/15967305/806442
- (void)orientationChanged:(NSNotification *)notification
{
    CGAffineTransform transform = CGAffineTransformMakeRotation([self rotation]);
    [UIView animateWithDuration:0.3f
                          delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState animations:^{
                            self.thumbView.transform = transform;
                            self.sharePhotoOnTwitter.transform = transform;
                            self.sharePhotoOnFacebook.transform = transform;
                            self.autoPhoto.transform = transform;
                            self.settingsButton.transform = transform;
                            self.switchCamerasButton.transform = transform;
                            self.countdownLabel.transform = transform;
                        }
                     completion:nil];
}

#pragma mark - AV setup
- (void)setupAVCapture
{
	self.session = [AVCaptureSession new];
	[self.session setSessionPreset:AVCaptureSessionPresetPhoto]; // high-res stills, screen-size video
	
	[self updateCameraSelection];
	
	// For displaying live feed to screen
	CALayer *rootLayer = self.cameraView.layer;
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
	
    self.useFrontCamera = !self.useFrontCamera;
    
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
	AVCaptureDevicePosition desiredPosition = (self.useFrontCamera) ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack;
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
- (void)drawFaceBoxesForFeatures:(NSArray *)features forVideoBox:(CGRect)clap
{
    [self resizeCoreImageFaceLayerCache:[features count]];
    
    if (![features count])
    {
        return;
    }
    
	// Update the face graphics
	[CATransaction begin];
	[CATransaction setAnimationDuration:1];
    
	CGRect previewBox = videoPreviewBoxForGravity(self.previewLayer.videoGravity, self.cameraView.frame.size, clap.size);
    
	NSInteger currentFeature = 0;
    BOOL isMirrored = self.previewLayer.connection.isVideoMirrored;
    
	for ( CIFaceFeature *ff in features ) {
        if ((&CIDetectorEyeBlink != NULL) && !self.detectedFeature && self.autoPhoto.on)
        {
            if (ff.hasSmile && [self.userDefaults boolForKey:@"smile"])
            {
                self.detectedFeature = YES;
                
                [self updateCountdownLabel:NSLocalizedString(@"Smile!", nil) forDuration:1.0f onCompletion:^(){[self startCountdown];}];
            }
            if ((ff.rightEyeClosed || ff.leftEyeClosed) && [self.userDefaults boolForKey:@"wink"])
            {
                self.detectedFeature = YES;
                
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
            
            [featureLayer setAffineTransform:CGAffineTransformMakeRotation([self rotation])];
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
			if (self.useFrontCamera)
				exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
			else
				exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
			break;
		case UIDeviceOrientationLandscapeRight:      // Device oriented horizontally, home button on the left
			if (self.useFrontCamera)
				exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
			else
				exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
			break;
		case UIDeviceOrientationPortrait:            // Device oriented vertically, home button on the bottom
		default:
			exifOrientation = PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP;
			break;
	}
    
    
	NSDictionary *imageOptions = @{CIDetectorImageOrientation: @(exifOrientation), CIDetectorSmile:@YES, CIDetectorEyeBlink:@YES};
    
	NSArray *features = [self.faceDetector featuresInImage:ciImage options:imageOptions];
    
	CMFormatDescriptionRef fdesc = CMSampleBufferGetFormatDescription(sampleBuffer);
	CGRect clap = CMVideoFormatDescriptionGetCleanAperture(fdesc, false /*originIsTopLeft*/);
	
    /*
    if (([features count] == [self.userDefaults doubleForKey:@"faces"]) && self.autoPhoto.on) {
        self.faceFrameCount++;
        
        if (self.faceFrameCount > TOTALFACE_FRAMES) {
            [self startCountdown];
            
            self.faceFrameCount = 0;
        }
    } else {
        self.faceFrameCount = 0;
    }
    */
    
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		[self drawFaceBoxesForFeatures:features forVideoBox:clap];
	});
}


#pragma mark - Camera actions
- (void)startCountdown
{
    if (self.cancelPicture)
    {
        [self resetCamera];
        return;
    }
    
    if (!self.isTakingPhoto)
    {
        self.isTakingPhoto = YES;
        
        [self.view bringSubviewToFront:self.countdownLabel];
        
        self.count = 3;
        self.takePhotoButton.enabled = NO;
        
        [self showCountDown];
    }
}

- (void)showCountDown
{
    if (self.cancelPicture)
    {
        [self resetCamera];
        return;
    }
    
    if (self.count != 0)
    {
        [self updateCountdownLabel:[NSString stringWithFormat:@"%d", self.count] forDuration:1.0f onCompletion:^(){[self showCountDown];}];
        self.count--;
    } else {
        [self takePhoto];
    }
}

- (void)updateCountdownLabel:(NSString *)text forDuration:(CGFloat)duration onCompletion:(void (^)(void))complete
{
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        self.countdownLabel.text = text;
        
        self.countdownLabel.alpha = 1.0f;
        [UIView animateWithDuration:duration
                         animations:^() {
                             self.countdownLabel.alpha = 0;
                         }
                         completion:^(BOOL finished) {
                             complete();
                         }];
    });
}

- (void)takePhoto
{
    if (self.cancelPicture)
    {
        [self resetCamera];
        return;
    }
    
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
                                                           if ((error) || ( ! imageDataSampleBuffer ))
                                                           {
                                                               displayErrorOnMainQueue(error, @"Take picture failed");
                                                           }
                                                           else
                                                           {
                                                               NSData *jpegData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                                                               NSDictionary* attachments = (__bridge_transfer NSDictionary*) CMCopyDictionaryOfAttachments(kCFAllocatorDefault, imageDataSampleBuffer, kCMAttachmentMode_ShouldPropagate);

                                                               writeJPEGDataToCameraRoll(jpegData, attachments);
                                                               
                                                               self.lastSelfie = [UIImage imageWithData:jpegData];
                                                               dispatch_async(dispatch_get_main_queue(), ^(void) {
                                                                   self.thumbView.image = [UIImage generatePhotoThumbnail:self.lastSelfie
                                                                                                                    ratio:self.thumbView.frame.size.width];
                                                                });
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
                                 animations:^{ self.flashView.alpha=1.0f; }
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
                         animations:^{ self.flashView.alpha = 0; }
                         completion:nil];
    });

    [self resetCamera];
}

- (void)resetCamera
{
    self.cancelPicture = NO;
    self.isTakingPhoto = NO;
    self.detectedFeature = NO;
    self.takePhotoButton.enabled = YES;
    self.faceFrameCount = 0;
    
    [self.autoPhoto setOn:NO animated:YES];
}

#pragma mark -
- (void)shareOnTwitter
{
    if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeTwitter])
    {
        SLComposeViewController *tweetSheet = [SLComposeViewController
                                               composeViewControllerForServiceType:SLServiceTypeTwitter];
        NSString *defaultText = ([self.userDefaults doubleForKey:@"faces"] == 1) ? @"Look at my beautiful smile! #selfiecam" : @"Look at our beautiful smiles! #selfiecam" ;
        [tweetSheet setInitialText:NSLocalizedString(defaultText, nil)];
        
        [tweetSheet addURL: [NSURL URLWithString:@""]];
        [tweetSheet addImage:self.lastSelfie];
        [self presentViewController:tweetSheet animated:YES completion:nil];
    }
    else
    {
        UIAlertView *alertView = [[UIAlertView alloc]
                                  initWithTitle:NSLocalizedString(@"No Facebook Twitter", nil)
                                  message:NSLocalizedString(@"You must set up at least one account in Settings > Twitter before you can share via Facebook", nil)
                                  delegate:self
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil];
        [alertView show];
    }
}

- (void)shareOnFacebook
{
    if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeFacebook])
    {
        SLComposeViewController *facebookSheet = [SLComposeViewController
                                                  composeViewControllerForServiceType:SLServiceTypeFacebook];
        
        NSString *defaultText = ([self.userDefaults doubleForKey:@"faces"] == 1) ? @"Look at my beautiful smile! #selfiecam" : @"Look at our beautiful smiles! #selfiecam" ;
        [facebookSheet setInitialText:NSLocalizedString(defaultText, nil)];
        [facebookSheet addImage:self.lastSelfie];
        [facebookSheet addURL: [NSURL URLWithString:@""]];
        
        [self presentViewController:facebookSheet animated:YES completion:nil];
    }
    else
    {
        UIAlertView *alertView = [[UIAlertView alloc]
                                  initWithTitle:NSLocalizedString(@"No Facebook Account", nil)
                                  message:NSLocalizedString(@"You must set an account in Settings > Facebook before you can share via Facebook", nil)
                                  delegate:self
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil];
        [alertView show];
    }
}

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
    
    if (![self.userDefaults doubleForKey:@"faces"])
    {
        [self.userDefaults setDouble:1 forKey:@"faces"];
        [self.userDefaults setDouble:1 forKey:@"smile"];
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
