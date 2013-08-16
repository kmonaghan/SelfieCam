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

#define TOTALFACE_FRAMES 15

const CGFloat FACE_RECT_BORDER_WIDTH = 3;

static char * const AVCaptureStillImageIsCapturingStillImageContext = "AVCaptureStillImageIsCapturingStillImageContext";
static CGFloat DegreesToRadians(CGFloat degrees) {return degrees * M_PI / 180;};
void writeJPEGDataToCameraRoll(NSData* data, NSDictionary* metadata);
static AVCaptureVideoOrientation avOrientationForDeviceOrientation(UIDeviceOrientation deviceOrientation);
CGRect videoPreviewBoxForGravity(NSString *gravity, CGSize frameSize, CGSize apertureSize);

void displayErrorOnMainQueue(NSError *error, NSString *message);
    
@interface CBPViewController ()
{
    UIView *cameraView;
    UIView *flashView;
    UIView *settingsView;
    UILabel *countdownLabel;
    
    int count;
    BOOL isTakingPhoto;
    BOOL detectedFeature;
    
    UISwitch *autoPhoto;
    UISwitch *faceActivation;
    UISwitch *smileActivation;
    UISwitch *winkActivation;
    
    UILabel *numberOfFacesLabel;
    UIStepper *changeNumberOfFaces;
    
    UIButton *takePhotoButton;
    UIButton *settingsButton;
    UIButton *aboutButton;
    UIButton *doneButton;
    
    int faceFrameCount;
}

@property (strong,nonatomic) AVCaptureSession *session;
@property (strong,nonatomic) AVCaptureVideoPreviewLayer *previewLayer;
@property (strong,nonatomic) AVCaptureVideoDataOutput *videoDataOutput;
@property (strong,nonatomic) AVCaptureStillImageOutput *stillImageOutput;

@property (strong,nonatomic) CIDetector *faceDetector;
@property (strong,nonatomic) NSMutableArray *ciFaceLayers;

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
	NSDictionary *detectorOptions = @{CIDetectorAccuracy : CIDetectorAccuracyLow, CIDetectorTracking : @YES};
	self.faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:detectorOptions];
    
    isTakingPhoto = NO;
    
    autoPhoto.on = NO;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)loadView
{
    UIView *view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        
    cameraView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320.0f, 427.0f)];
    cameraView.backgroundColor = [UIColor whiteColor];
    
    [view addSubview:cameraView];
    
    countdownLabel = [[UILabel alloc] initWithFrame:[UIScreen mainScreen].bounds];
    countdownLabel.font = [UIFont boldSystemFontOfSize:200.0f];
    countdownLabel.textColor = [UIColor whiteColor];
    countdownLabel.backgroundColor = [UIColor clearColor];
    countdownLabel.text = @"3";
    countdownLabel.textAlignment = NSTextAlignmentCenter;
    countdownLabel.center = view.center;
    countdownLabel.alpha = 0;
    countdownLabel.minimumScaleFactor = 0.01f;
    countdownLabel.adjustsFontSizeToFitWidth = YES;
    
    [view addSubview:countdownLabel];
    
    flashView = [[UIView alloc] initWithFrame:cameraView.frame];
    flashView.alpha = 0.0f;
    flashView.backgroundColor = [UIColor whiteColor];
    [view addSubview:flashView];
    
    UIView *controlView = [[UIView alloc] initWithFrame:CGRectMake(0, [UIScreen mainScreen].bounds.size.height - 50.0f, [UIScreen mainScreen].bounds.size.width, 50.0f)];
    
    UIView *controlBackgroundView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320.0f, 50.0f)];
    controlBackgroundView.backgroundColor = [UIColor whiteColor];
    controlBackgroundView.alpha = 0.5f;
    
    [controlView addSubview:controlBackgroundView];
    
    autoPhoto = [[UISwitch alloc] init];
    autoPhoto.center = CGPointMake(controlView.frame.size.width / 4, controlView.frame.size.height / 2);
    [controlView addSubview:autoPhoto];
    
    takePhotoButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [takePhotoButton setTitle:NSLocalizedString(@"Photo", nil) forState:UIControlStateNormal];
    [takePhotoButton addTarget:self
                        action:@selector(startCountdown)
              forControlEvents:UIControlEventTouchUpInside];
    [takePhotoButton sizeToFit];
    takePhotoButton.center = CGPointMake(controlView.frame.size.width / 2, controlView.frame.size.height / 2);
    
    [controlView addSubview:takePhotoButton];
    
    settingsButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [settingsButton addTarget:self action:@selector(showSettings) forControlEvents:UIControlEventTouchUpInside];
    [settingsButton setTitle:NSLocalizedString(@"Settings", nil) forState:UIControlStateNormal];
    [settingsButton sizeToFit];
    settingsButton.center = CGPointMake((controlView.frame.size.width / 4) * 3, controlView.frame.size.height / 2);

    [controlView addSubview:settingsButton];
    
    [view addSubview:controlView];
    
    settingsView = [[UIView alloc] initWithFrame:CGRectMake(0, view.frame.size.height, 320.0f, 220.0f)];
    settingsView.backgroundColor = [UIColor blackColor];
    
    UILabel *faceLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    faceLabel.text = NSLocalizedString(@"Take photo when a face in shot", nil);
    faceLabel.textColor = [UIColor whiteColor];
    faceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    faceLabel.numberOfLines = 2;
    [settingsView addSubview:faceLabel];
    
    faceActivation = [[UISwitch alloc] init];
    faceActivation.translatesAutoresizingMaskIntoConstraints = NO;
    [settingsView addSubview:faceActivation];
    
    [settingsView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[faceLabel][faceActivation]-|"
                                                                         options:0
                                                                         metrics:nil
                                                                           views:NSDictionaryOfVariableBindings(faceLabel, faceActivation)]];
    
    [settingsView addConstraint:[NSLayoutConstraint constraintWithItem:faceLabel
                                                             attribute:NSLayoutAttributeCenterY
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:faceActivation
                                                             attribute:NSLayoutAttributeCenterY
                                                            multiplier:1.0f
                                                              constant:0.0f]];
    
    numberOfFacesLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    numberOfFacesLabel.textColor = [UIColor whiteColor];
    numberOfFacesLabel.translatesAutoresizingMaskIntoConstraints = NO;
    numberOfFacesLabel.numberOfLines = 2;
    [settingsView addSubview:numberOfFacesLabel];
    
    changeNumberOfFaces = [[UIStepper alloc] init];
    changeNumberOfFaces.minimumValue = 1;
    changeNumberOfFaces.maximumValue = 5;
    [changeNumberOfFaces addTarget:self action:@selector(numberOfFacesChanged) forControlEvents:UIControlEventValueChanged];
    changeNumberOfFaces.translatesAutoresizingMaskIntoConstraints = NO;
    [settingsView addSubview:changeNumberOfFaces];
    
    [settingsView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[numberOfFacesLabel][changeNumberOfFaces]-|"
                                                                         options:0
                                                                         metrics:nil
                                                                           views:NSDictionaryOfVariableBindings(numberOfFacesLabel, changeNumberOfFaces)]];
    
    [self numberOfFacesChanged];
    
    [settingsView addConstraint:[NSLayoutConstraint constraintWithItem:numberOfFacesLabel
                                                             attribute:NSLayoutAttributeCenterY
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:changeNumberOfFaces
                                                             attribute:NSLayoutAttributeCenterY
                                                            multiplier:1.0f
                                                              constant:0.0f]];
    
    UILabel *smileLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    smileLabel.text = NSLocalizedString(@"Take photo when you smile", nil);
    smileLabel.textColor = [UIColor whiteColor];
    smileLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    [settingsView addSubview:smileLabel];
    
    smileActivation = [[UISwitch alloc] init];
    smileActivation.translatesAutoresizingMaskIntoConstraints = NO;
    [settingsView addSubview:smileActivation];
    
    [settingsView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[smileLabel][smileActivation]-|"
                                                                         options:0
                                                                         metrics:nil
                                                                           views:NSDictionaryOfVariableBindings(smileLabel, smileActivation)]];
    
    [settingsView addConstraint:[NSLayoutConstraint constraintWithItem:smileLabel
                                                             attribute:NSLayoutAttributeCenterY
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:smileActivation
                                                             attribute:NSLayoutAttributeCenterY
                                                            multiplier:1.0f
                                                              constant:0.0f]];


    UILabel *winkLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    winkLabel.text = NSLocalizedString(@"Take photo when you wink", nil);
    winkLabel.textColor = [UIColor whiteColor];
    winkLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    [settingsView addSubview:winkLabel];
    
    winkActivation = [[UISwitch alloc] init];
    winkActivation.translatesAutoresizingMaskIntoConstraints = NO;

    [settingsView addSubview:winkActivation];

    [settingsView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[winkLabel][winkActivation]-|"
                                                                         options:0
                                                                         metrics:nil
                                                                           views:NSDictionaryOfVariableBindings(winkLabel, winkActivation)]];
    
    [settingsView addConstraint:[NSLayoutConstraint constraintWithItem:winkLabel
                                                             attribute:NSLayoutAttributeCenterY
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:winkActivation
                                                             attribute:NSLayoutAttributeCenterY
                                                            multiplier:1.0f
                                                              constant:0.0f]];
    
    aboutButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [aboutButton setTitle:NSLocalizedString(@"About", nil) forState:UIControlStateNormal];
    [aboutButton addTarget:self action:@selector(about) forControlEvents:UIControlEventTouchUpInside];
    aboutButton.translatesAutoresizingMaskIntoConstraints = NO;
    [settingsView addSubview:aboutButton];
    
    doneButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [doneButton setTitle:NSLocalizedString(@"Done", nil) forState:UIControlStateNormal];
    [doneButton addTarget:self action:@selector(hideSettings) forControlEvents:UIControlEventTouchUpInside];
    doneButton.translatesAutoresizingMaskIntoConstraints = NO;
    [settingsView addSubview:doneButton];

    [settingsView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[aboutButton]-|"
                                                                         options:0
                                                                         metrics:nil
                                                                           views:NSDictionaryOfVariableBindings(aboutButton)]];
    
    [settingsView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[aboutButton(==doneButton)]-[doneButton]-|"
                                                                         options:0
                                                                         metrics:nil
                                                                           views:NSDictionaryOfVariableBindings(aboutButton, doneButton)]];

    [settingsView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[faceActivation]-[changeNumberOfFaces]-[smileActivation]-[winkActivation]-[doneButton]-|"
                                                                         options:0
                                                                         metrics:nil
                                                                           views:NSDictionaryOfVariableBindings(faceActivation, changeNumberOfFaces, smileActivation, winkActivation, doneButton)]];
     
    [view addSubview:settingsView];
    
    self.view = view;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
	return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
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
	[self.stillImageOutput addObserver:self forKeyPath:@"capturingStillImage" options:NSKeyValueObservingOptionNew context:AVCaptureStillImageIsCapturingStillImageContext];
    
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
	AVCaptureDevicePosition desiredPosition = (YES) ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack;
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
    if (![features count])
    {
        return;
    }
    
	// Update the face graphics
	[CATransaction begin];
	[CATransaction setAnimationDuration:1];

    [self resizeCoreImageFaceLayerCache:[features count]];
    
	CGRect previewBox = videoPreviewBoxForGravity(self.previewLayer.videoGravity, cameraView.frame.size, clap.size);
    
	NSInteger currentFeature = 0;
    BOOL isMirrored = self.previewLayer.connection.isVideoMirrored;
    
	for ( CIFaceFeature *ff in features ) {
		// Find the correct position for the mustache layer within the previewLayer
		// The feature box originates in the bottom left of the video frame.
		// (Bottom right if mirroring is turned on)
		CGRect faceRect = [ff bounds];
        
        if ((&CIDetectorEyeBlink != NULL) && !detectedFeature && autoPhoto.on)
        {
            if (ff.hasSmile && smileActivation.on)
            {
                detectedFeature = YES;
                
                [self updateCountdownLabel:NSLocalizedString(@"Smile!", nil) forDuration:1.0f onCompletion:^(){[self startCountdown];}];
            }
            
            if ((ff.rightEyeClosed || ff.leftEyeClosed) && winkActivation.on)
            {
                detectedFeature = YES;
                
                [self updateCountdownLabel:NSLocalizedString(@"Wink!", nil) forDuration:1.0f onCompletion:^(){[self startCountdown];}];
            }
        }
        
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
			if (YES) //UserDefaults.usingFrontCamera)
				exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
			else
				exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
			break;
		case UIDeviceOrientationLandscapeRight:      // Device oriented horizontally, home button on the left
			if (YES)//UserDefaults.usingFrontCamera)
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
	
    if (([features count] == changeNumberOfFaces.value) && autoPhoto.on) {
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
        [countdownLabel sizeThatFits:CGSizeMake(320.0f, MAXFLOAT)];
        countdownLabel.center = self.view.center;
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
    [UIView animateWithDuration:0.3f
                     animations:^() {
                         settingsView.frame = CGRectMake(0, self.view.frame.size.height - settingsView.frame.size.height, settingsView.frame.size.width, settingsView.frame.size.height);
                     }];
}

- (void)hideSettings
{
    [UIView animateWithDuration:0.3f
                     animations:^() {
                         settingsView.frame = CGRectMake(0, self.view.frame.size.height, settingsView.frame.size.width, settingsView.frame.size.height);
                     }];
}

- (void)numberOfFacesChanged
{
    NSString *facestring = [NSString stringWithFormat:@"%.f face%@ should be visible", changeNumberOfFaces.value, ((changeNumberOfFaces.value > 1) ? @"s": @"")];
    numberOfFacesLabel.text = NSLocalizedString(facestring, nil);
    //[numberOfFacesLabel sizeToFit];
}

- (void)about
{
    
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
