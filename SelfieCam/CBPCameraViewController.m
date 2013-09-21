//
//  CBPViewController.m
//  SelfieCam
//
//  Created by Karl Monaghan on 02/08/2013.
//  Copyright (c) 2013 Karl Monaghan. All rights reserved.
//
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>
#import <AssertMacros.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <Social/Social.h>
#import <QuartzCore/QuartzCore.h>

#import "NYXImagesKit.h"

#import "CBPCameraViewController.h"
#import "CBPSettingsViewController.h"

const CGFloat FACE_RECT_BORDER_WIDTH = 3;

static char * const AVCaptureStillImageIsCapturingStillImageContext = "AVCaptureStillImageIsCapturingStillImageContext";
static CGFloat DegreesToRadians(CGFloat degrees) {return degrees * M_PI / 180;};
void writeJPEGDataToCameraRoll(NSData* data, NSDictionary* metadata);

CGRect videoPreviewBoxForGravity(NSString *gravity, CGSize frameSize, CGSize apertureSize);

void displayErrorOnMainQueue(NSError *error, NSString *message);


typedef NS_ENUM(NSInteger, CBPPhotoExif) {
    PHOTOS_EXIF_0ROW_TOP_0COL_LEFT			= 1, //   1  =  0th row is at the top, and 0th column is on the left (THE DEFAULT).
    PHOTOS_EXIF_0ROW_TOP_0COL_RIGHT			= 2, //   2  =  0th row is at the top, and 0th column is on the right.
    PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT      = 3, //   3  =  0th row is at the bottom, and 0th column is on the right.
    PHOTOS_EXIF_0ROW_BOTTOM_0COL_LEFT       = 4, //   4  =  0th row is at the bottom, and 0th column is on the left.
    PHOTOS_EXIF_0ROW_LEFT_0COL_TOP          = 5, //   5  =  0th row is on the left, and 0th column is the top.
    PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP         = 6, //   6  =  0th row is on the right, and 0th column is the top.
    PHOTOS_EXIF_0ROW_RIGHT_0COL_BOTTOM      = 7, //   7  =  0th row is on the right, and 0th column is the bottom.
    PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM       = 8  //   8  =  0th row is on the left, and 0th column is the bottom.
};

@interface CBPCameraViewController ()
@property (strong, nonatomic) UIView *cameraView;
@property (strong, nonatomic) UIView *flashView;
@property (strong, nonatomic) UIView *controlView;
@property (strong, nonatomic) UIView *controlBackgroundView;
@property (strong, nonatomic) UIView *thumbViewContainer;
@property (strong, nonatomic) UIImageView *thumbView;

@property (strong, nonatomic) UILabel *countdownLabel;

@property (strong, nonatomic) UISwitch *autoPhoto;

@property (strong, nonatomic) UIButton *settingsButton;
@property (strong, nonatomic) UIButton *switchCamerasButton;
@property (strong, nonatomic) UIButton *share;

@property (assign, nonatomic) CGFloat topOffset;
@property (assign, nonatomic) CGFloat bottomOffset;
@property (assign, nonatomic) double count;
@property (assign, nonatomic) NSInteger faceFrameCount;
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
@property (strong, nonatomic) ASMediaFocusManager *mediaFocusManager;

@property (strong, nonatomic) ALAssetsLibrary *library;

@property (strong, nonatomic) NSMutableDictionary *smileCounter;
@property (strong, nonatomic) NSMutableDictionary *winkCounter;

@property (strong, nonatomic) CMPopTipView *roundRectButtonPopTipView;

@property (strong, nonatomic) UIImageView *smile1;
@property (strong, nonatomic) UIImageView *smile2;
@property (strong, nonatomic) UIImageView *smile3;

@property (strong, nonatomic) UIView *explaination;

@end

@implementation CBPCameraViewController
- (void)dealloc
{
	[self teardownAVCapture];
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
    
    self.switchCamerasButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.switchCamerasButton setImage:[UIImage imageNamed:@"switch-camera.png"] forState:UIControlStateNormal];
    [self.switchCamerasButton addTarget:self action:@selector(updateCameraSelection) forControlEvents:UIControlEventTouchUpInside];
    self.switchCamerasButton.frame = CGRectMake(0, 0, 44.0f, 44.0f);
    self.switchCamerasButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.switchCamerasButton.accessibilityLabel = NSLocalizedString(@"Switch between the front and rear cameras", nil);
    
    [view addSubview:self.switchCamerasButton];
    
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
    
    self.controlView = [[UIView alloc] initWithFrame:CGRectZero];
    self.controlView.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.controlBackgroundView = [[UIView alloc] initWithFrame:CGRectZero];
    self.controlBackgroundView.backgroundColor = [UIColor whiteColor];
    self.controlBackgroundView.alpha = 0.5f;
    self.controlBackgroundView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.controlView addSubview:self.controlBackgroundView];
    
    self.thumbViewContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 50.0f, 50.f)];
    self.thumbViewContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.thumbViewContainer.clipsToBounds = YES;
    
    self.thumbView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 50.0f, 50.f)];
    self.thumbView.translatesAutoresizingMaskIntoConstraints = NO;
    self.thumbView.image = [UIImage imageNamed:@"default_thumb.png"];
    
    [self.thumbViewContainer addSubview:self.thumbView];
    
    [self.controlView addSubview:self.thumbViewContainer];
    
    self.share = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.share setImage:[UIImage imageNamed:@"702-share.png"] forState:UIControlStateNormal];
    [self.share setImage:[UIImage imageNamed:@"702-share-selected.png"] forState:UIControlStateSelected];
    
    [self.share addTarget:self action:@selector(shareImage) forControlEvents:UIControlEventTouchUpInside];
    self.share.frame = CGRectMake(0, 0, 44.0f, 44.0f);
    self.share.translatesAutoresizingMaskIntoConstraints = NO;
    self.share.hidden = YES;
    self.share.accessibilityLabel = NSLocalizedString(@"Share your beautiful smile", @"Accessiblity label for sharing button");
    
    [self.controlView addSubview:self.share];
    
    self.autoPhoto = [[UISwitch alloc] init];
    [self.autoPhoto addTarget:self action:@selector(updateCoreImageDetection) forControlEvents:UIControlEventValueChanged];
    self.autoPhoto.translatesAutoresizingMaskIntoConstraints = NO;
    self.autoPhoto.accessibilityLabel = NSLocalizedString(@"Start taking photos of your beautiful smile", @"Accessiblity label for ");
    self.autoPhoto.on = YES;
    self.autoPhoto.hidden = YES;
    
    [self.controlView addSubview:self.autoPhoto];
    
    self.settingsButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.settingsButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.settingsButton addTarget:self action:@selector(showSettings) forControlEvents:UIControlEventTouchUpInside];
    //[self.settingsButton setTitle:NSLocalizedString(@"Settings", nil) forState:UIControlStateNormal];
    //[self.settingsButton sizeToFit];
    [self.settingsButton setImage:[UIImage imageNamed:@"740-gear.png"] forState:UIControlStateNormal];
    [self.settingsButton setImage:[UIImage imageNamed:@"740-gear-selected.png"] forState:UIControlStateSelected];
    self.settingsButton.frame = CGRectMake(0, 0, 44.0f, 44.0f);
    self.settingsButton.accessibilityLabel = NSLocalizedString(@"Change the app settings", @"Accessibility label for settings button");
    [self.controlView addSubview:self.settingsButton];
    
    [view addSubview:self.controlView];
    
    self.smile1 = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"870-smile-grey.png"]];
    self.smile1.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:self.smile1];
    
    self.smile2 = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"870-smile-grey.png"]];
    self.smile2.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:self.smile2];
    
    self.smile3 = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"870-smile-grey.png"]];
    self.smile3.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:self.smile3];
    
    self.explaination = [[UIView alloc] initWithFrame:CGRectZero];
    self.explaination.hidden = YES;
    self.explaination.backgroundColor = [UIColor whiteColor];
    self.explaination.layer.cornerRadius = 5.0f;
    
    UILabel *explainationLabel = [UILabel new];
    explainationLabel.numberOfLines = 0;
    explainationLabel.textAlignment = NSTextAlignmentCenter;
    explainationLabel.text = NSLocalizedString(@"All you need to do to take a photo is show off your beautiful smile.\n\nWhy don't you try it now?", nil);
    CGSize labelSize = [explainationLabel sizeThatFits:CGSizeMake(240.0f, MAXFLOAT)];
    explainationLabel.frame = CGRectMake(15.0f, 15.0f, labelSize.width, labelSize.height);
    
    self.explaination.frame = CGRectMake(0, 0, labelSize.width + 30.0f, labelSize.height + 30.0f);
    
    [self.explaination addSubview:explainationLabel];
    
    [view addSubview:self.explaination];
    
    self.view = view;
}

- (void)updateViewConstraints
{
    [super updateViewConstraints];
    
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|[_flashView]|"
                                                                      options:0
                                                                      metrics:nil
                                                                        views:NSDictionaryOfVariableBindings(_flashView)]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_flashView]|"
                                                                      options:0
                                                                      metrics:nil
                                                                        views:NSDictionaryOfVariableBindings(_flashView)]];
    
    NSMutableArray *portraitButton = @[].mutableCopy;
    [portraitButton addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"[_switchCamerasButton]-|"
                                                                                options:0
                                                                                metrics:nil
                                                                                  views:NSDictionaryOfVariableBindings(_switchCamerasButton)]];
    
    [portraitButton addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(5)-[_switchCamerasButton]"
                                                                                options:0
                                                                                metrics:nil
                                                                                  views:NSDictionaryOfVariableBindings(_switchCamerasButton)]];
    
    [self.view addConstraints:portraitButton];
    
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(5)-[_smile1]"
                                                                      options:0
                                                                      metrics:nil
                                                                        views:NSDictionaryOfVariableBindings(_smile1)]];
    
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(5)-[_smile2]"
                                                                      options:0
                                                                      metrics:nil
                                                                        views:NSDictionaryOfVariableBindings(_smile2)]];
    
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(5)-[_smile3]"
                                                                      options:0
                                                                      metrics:nil
                                                                        views:NSDictionaryOfVariableBindings(_smile3)]];
    
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.smile2
                                                          attribute:NSLayoutAttributeCenterX
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.view
                                                          attribute:NSLayoutAttributeCenterX
                                                         multiplier:1.0f
                                                           constant:0.0f]];
    
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[_smile1]-[_smile2]-[_smile3]"
                                                                      options:0
                                                                      metrics:nil
                                                                        views:NSDictionaryOfVariableBindings(_smile1, _smile2, _smile3)]];
    
    [self.controlView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|[_controlBackgroundView]|"
                                                                             options:0
                                                                             metrics:nil
                                                                               views:NSDictionaryOfVariableBindings(_controlBackgroundView)]];
    [self.controlView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_controlBackgroundView]|"
                                                                             options:0
                                                                             metrics:nil
                                                                               views:NSDictionaryOfVariableBindings(_controlBackgroundView)]];
    
    [self.controlView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[_thumbViewContainer(50)]-[_share]"
                                                                             options:0
                                                                             metrics:nil
                                                                               views:NSDictionaryOfVariableBindings(_thumbViewContainer, _share)]];
    
    [self.controlView addConstraint:[NSLayoutConstraint constraintWithItem:self.share
                                                                 attribute:NSLayoutAttributeCenterY
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:self.controlView
                                                                 attribute:NSLayoutAttributeCenterY
                                                                multiplier:1.0f
                                                                  constant:0.0f]];
    
    NSMutableArray *verticalbuttonConstraints = @[].mutableCopy;
    
    [verticalbuttonConstraints addObject:[NSLayoutConstraint constraintWithItem:self.thumbViewContainer
                                                                      attribute:NSLayoutAttributeCenterY
                                                                      relatedBy:NSLayoutRelationEqual
                                                                         toItem:self.controlView
                                                                      attribute:NSLayoutAttributeCenterY
                                                                     multiplier:1.0f
                                                                       constant:0.0f]];
    
    [verticalbuttonConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[_thumbViewContainer(50)]"
                                                                                           options:0
                                                                                           metrics:nil
                                                                                             views:NSDictionaryOfVariableBindings(_thumbViewContainer)]];
    
    [verticalbuttonConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[_thumbViewContainer(50)]"
                                                                                           options:0
                                                                                           metrics:nil
                                                                                             views:NSDictionaryOfVariableBindings(_thumbViewContainer)]];
    
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
    
    NSMutableArray *portrait = [NSLayoutConstraint constraintsWithVisualFormat:@"|[_controlView]|"
                                                                       options:0
                                                                       metrics:nil
                                                                         views:NSDictionaryOfVariableBindings(_controlView)].mutableCopy;
    
    [portrait addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:[NSString stringWithFormat:@"V:[_controlView(%f)]|", self.bottomOffset]
                                                                          options:0
                                                                          metrics:nil
                                                                            views:NSDictionaryOfVariableBindings(_controlView)]];
    
    [self.view addConstraints:portrait];
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    self.useFrontCamera = NO;
    
    self.isTakingPhoto = NO;
    
    //self.autoPhoto.on = NO;
    
    self.cancelPicture = NO;
    
    self.userDefaults = [NSUserDefaults standardUserDefaults];
    
    [self loadSettings];
    
    [self setupAVCapture];
    
    [self lastPhoto];
    
    self.mediaFocusManager = [ASMediaFocusManager new];
    self.mediaFocusManager.delegate = self;
    [self.mediaFocusManager installOnView:self.thumbView];
    
    self.library = [ALAssetsLibrary new];
    
    self.smileCounter = @{}.mutableCopy;
    self.winkCounter = @{}.mutableCopy;
    
    if (![self.userDefaults boolForKey:@"first_help"])
    {
        self.explaination.center = self.view.center;
        self.explaination.hidden = NO;
        
        [self.userDefaults setBool:YES forKey:@"first_help"];
    }
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

- (BOOL)shouldAutorotate
{
    return NO;
}

#pragma mark -
- (double)rotation
{
    UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
    double rotation;
    
    switch (orientation) {
        case UIDeviceOrientationPortrait:
            //break;
        case UIDeviceOrientationPortraitUpsideDown:
            rotation = 0;
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

- (NSInteger)exifOrientation:(UIDeviceOrientation)curDeviceOrientation
{
	CBPPhotoExif exifOrientation;
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
    
    return exifOrientation;
}

#pragma mark - Notifications
// Inspired by http://stackoverflow.com/a/15967305/806442
- (void)orientationChanged:(NSNotification *)notification
{
    CGAffineTransform transform = CGAffineTransformMakeRotation([self rotation]);
    [UIView animateWithDuration:0.3f
                          delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState animations:^{
                            self.thumbView.transform = transform;
                            self.share.transform = transform;
                            self.autoPhoto.transform = transform;
                            self.settingsButton.transform = transform;
                            self.switchCamerasButton.transform = transform;
                            self.countdownLabel.transform = transform;
                            self.smile1.transform = transform;
                            self.smile2.transform = transform;
                            self.smile3.transform = transform;
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
	self.previewLayer.backgroundColor = [[UIColor blackColor] CGColor];
	self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspect;
	self.previewLayer.frame = rootLayer.bounds;
	[rootLayer addSublayer:self.previewLayer];
	
    self.stillImageOutput = [AVCaptureStillImageOutput new];
	if ( [self.session canAddOutput:self.stillImageOutput] ) {
		[self.session addOutput:self.stillImageOutput];
	} else {
		self.stillImageOutput = nil;
	}
    
	self.ciFaceLayers = [NSMutableArray arrayWithCapacity:10];
	
	NSDictionary *detectorOptions = @{ CIDetectorAccuracy : CIDetectorAccuracyHigh, CIDetectorTracking : @(YES) };
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
	
	[self updateCoreImageDetection];
	
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

- (void)updateCoreImageDetection {
	if ( !self.videoDataOutput )
		return;
    
	// enable/disable the AVCaptureVideoDataOutput to control the flow of AVCaptureVideoDataOutputSampleBufferDelegate calls
	[[self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:self.autoPhoto.on];
	
	// update graphics associated with previously detected faces
	[CATransaction begin];
	[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
	[CATransaction commit];
	
	if ( ! self.autoPhoto.on ) {
		// dispatch to the end of queue in case a delegate call was already pending before we stopped the output
		dispatch_async(dispatch_get_main_queue(), ^(void) { [self resizeCoreImageFaceLayerCache:0]; });
	}
}

- (void)updateCameraSelection
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
		[self updateCoreImageDetection];
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
				displayErrorOnMainQueue(error, NSLocalizedString(@"Could not start up camera", nil));
			} else if ( [self.session canAddInput:input] ) {
				return input;
			}
		}
	}
	if ( ! hadError ) {
		// no errors, simply couldn't find a matching camera
        NSString *error = [NSString stringWithFormat:@"You've no %@ to use", ((self.useFrontCamera) ? @"front" : @"rear")];
        
		displayErrorOnMainQueue(nil, NSLocalizedString(error, @"Tells the use they don't have a useable camera - options are 'front' and 'rear'"));
	}
	return nil;
}

#pragma mark -
- (void) resizeCoreImageFaceLayerCache:(NSInteger)newSize
{
	while( [self.ciFaceLayers count] < newSize) {
		// add required layers
		CALayer *featureLayer = [CALayer new];
        
		[featureLayer setBorderColor:[[UIColor greenColor] CGColor]];
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
- (void)detectFaceFeatures:(NSArray *)features forVideoBox:(CGRect)clap
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
    
	for ( CIFaceFeature *ff in features )
    {
        /*
         DLog(@"ff bounds: %@", NSStringFromCGRect(ff.bounds));
         DLog(@"ff leftEyePosition: %@", NSStringFromCGPoint(ff.leftEyePosition));
         DLog(@"ff rightEyePosition: %@", NSStringFromCGPoint(ff.rightEyePosition));
         DLog(@"ff mouthPosition: %@", NSStringFromCGPoint(ff.mouthPosition));
         DLog(@"ff leftEyeClosed: %@", (ff.leftEyeClosed) ? @"Yes" : @"No" );
         DLog(@"ff rightEyeClosed: %@", (ff.rightEyeClosed) ? @"Yes" : @"No");
         DLog(@"ff hasSmile: %@", (ff.hasSmile) ? @"Yes" : @"No" );
         DLog(@"ff tracking ID: %d", ff.trackingID );
         */
        
        BOOL smileDetected = NO;
        BOOL winkDetected = NO;
        
        if (!self.detectedFeature && self.autoPhoto.on)
        {
            if (ff.hasSmile)
            {
                smileDetected = YES;
            }
            
            if ((ff.rightEyeClosed || ff.leftEyeClosed))
            {
                winkDetected = YES;
            }
            
            NSString *tracker = [NSString stringWithFormat:@"%d", ff.trackingID];
            
            if ([self.userDefaults boolForKey:@"smile"])
            {
                if (smileDetected)
                {
                    int smiles = 0;
                    if (self.smileCounter[tracker])
                    {
                        smiles = [self.smileCounter[tracker] intValue];
                        smiles++;
                        
                        [self updateSmiles:smiles];
                    }
                    
                    if ((smiles == 3) && ([features count] >= [self.userDefaults doubleForKey:@"faces"]))
                    {
                        if (!self.explaination.hidden)
                        {
                            self.explaination.hidden = YES;
                        }
                        
                        self.detectedFeature = YES;
                        
                        [self updateCountdownLabel:NSLocalizedString(@"Smile!", nil) forDuration:0.5f onCompletion:^(){[self startCountdown];}];
                    }
                    else
                    {
                        self.smileCounter[tracker] = [NSNumber numberWithInt:smiles];
                    }
                }
                else
                {
                    self.smileCounter[tracker] = [NSNumber numberWithInt:0];
                    
                    [self updateSmiles:0];
                }
            }
            
            if ([self.userDefaults boolForKey:@"wink"])
            {
                if (winkDetected)
                {
                    int winks = 0;
                    if (self.smileCounter[tracker])
                    {
                        winks = [self.smileCounter[tracker] intValue];
                        winks++;
                        
                        [self updateSmiles:winks];
                    }
                    
                    if ((winks == 3) && ([features count] >= [self.userDefaults doubleForKey:@"faces"]))
                    {
                        self.detectedFeature = YES;
                        
                        [self updateCountdownLabel:NSLocalizedString(@"Wink!", nil) forDuration:0.5f onCompletion:^(){[self startCountdown];}];
                    }
                    else
                    {
                        self.smileCounter[tracker] = [NSNumber numberWithInt:winks];
                    }
                }
                else
                {
                    self.smileCounter[tracker] = [NSNumber numberWithInt:0];
                    
                    [self updateSmiles:0];
                }
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
    if (![self.userDefaults boolForKey:@"showed_smile_help"])
    {
        self.roundRectButtonPopTipView = [[CMPopTipView alloc] initWithMessage:NSLocalizedString(@"When all three faces light up, we've found your beautiful smile and will take a photo", nil)];
        self.roundRectButtonPopTipView.delegate = self;
        self.roundRectButtonPopTipView.backgroundColor = [UIColor lightGrayColor];
        self.roundRectButtonPopTipView.textColor = [UIColor darkTextColor];
        self.roundRectButtonPopTipView.dismissTapAnywhere = YES;
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self.roundRectButtonPopTipView presentPointingAtView:self.smile2 inView:self.view animated:YES];
        });
        [self.userDefaults setBool:YES forKey:@"showed_smile_help"];
        [self.userDefaults synchronize];
    }
    
    // Got an image.
	CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
	NSDictionary* attachments = (__bridge_transfer NSDictionary*)CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
	CIImage *ciImage = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer options:attachments];
	UIDeviceOrientation curDeviceOrientation = [UIDevice currentDevice].orientation;
	
    
    NSInteger exifOrientation = [self exifOrientation:curDeviceOrientation];
    
	NSDictionary *imageOptions = @{CIDetectorImageOrientation: @(exifOrientation), CIDetectorSmile:@YES, CIDetectorEyeBlink:@YES};
    
	NSArray *features = [self.faceDetector featuresInImage:ciImage options:imageOptions];
    
	CMFormatDescriptionRef fdesc = CMSampleBufferGetFormatDescription(sampleBuffer);
	CGRect clap = CMVideoFormatDescriptionGetCleanAperture(fdesc, false /*originIsTopLeft*/);
	
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self detectFaceFeatures:features forVideoBox:clap];
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
        
        self.count = [self.userDefaults doubleForKey:@"photo_timer"];
        
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
        [self updateCountdownLabel:[NSString stringWithFormat:@"%.f", self.count] forDuration:1.0f onCompletion:^(){[self showCountDown];}];
        self.count--;
    } else {
        [self updateCountdownLabel:NSLocalizedString(@"Photo!", nil) forDuration:0.3f onCompletion:^(){[self takePhoto];}];
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
    
    AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
    
	// Find out the current orientation and tell the still image output.
	AVCaptureConnection *stillImageConnection = [self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
	UIDeviceOrientation curDeviceOrientation = [UIDevice currentDevice].orientation;
    
    AVCaptureVideoOrientation avcaptureOrientation = AVCaptureVideoOrientationPortrait;
	if (curDeviceOrientation == UIDeviceOrientationLandscapeLeft)
    {
		avcaptureOrientation = AVCaptureVideoOrientationLandscapeRight;
	}
    else if ( curDeviceOrientation == UIDeviceOrientationLandscapeRight)
    {
		avcaptureOrientation = AVCaptureVideoOrientationLandscapeLeft;
    }
    else if ( curDeviceOrientation == UIDeviceOrientationPortraitUpsideDown)
    {
		avcaptureOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
    }
    
	[stillImageConnection setVideoOrientation:avcaptureOrientation];
	[stillImageConnection setVideoScaleAndCropFactor:1];
	[stillImageConnection setAutomaticallyAdjustsVideoMirroring:NO];
	[stillImageConnection setVideoMirrored:[self.previewLayer.connection isVideoMirrored]];
    
    [self.stillImageOutput setOutputSettings:@{AVVideoCodecKey: AVVideoCodecJPEG}];
    
	[self.stillImageOutput captureStillImageAsynchronouslyFromConnection:stillImageConnection
                                                       completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
                                                           if ((error) || ( ! imageDataSampleBuffer ))
                                                           {
                                                               displayErrorOnMainQueue(error, NSLocalizedString(@"Oh oh, something went wrong taking your picture. Try again in a second. The world needs to see your smile!", ));
                                                           }
                                                           else
                                                           {
                                                               [self processImage:imageDataSampleBuffer withOrientation:curDeviceOrientation];
                                                           }
                                                           
                                                           dispatch_async(dispatch_get_main_queue(), ^(void) {
                                                               [self unfreezePreview];
                                                           });
                                                       }];
}

- (void)processImage:(CMSampleBufferRef)imageDataSampleBuffer withOrientation:(UIDeviceOrientation)curDeviceOrientation
{
    NSData *jpegData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
    
    NSDictionary* metadata = (__bridge_transfer NSDictionary*) CMCopyDictionaryOfAttachments(kCFAllocatorDefault, imageDataSampleBuffer, kCMAttachmentMode_ShouldPropagate);
    
    NSInteger saveOrientation = [self exifOrientation:curDeviceOrientation];
    
    NSMutableDictionary *temp = [[NSMutableDictionary alloc] initWithDictionary:metadata];
    [temp setObject:[NSNumber numberWithInt:saveOrientation] forKey:@"Orientation"];
    
    [self.library writeImageDataToSavedPhotosAlbum:jpegData metadata:temp completionBlock:^(NSURL *assetURL, NSError *error) {
        if (error) {
            displayErrorOnMainQueue(error, NSLocalizedString(@"Saving your smile has failed. Great disappointment.", nil));
        }
        else
        {
            [[NSUserDefaults standardUserDefaults] setObject:[assetURL absoluteString] forKey:@"last_photo"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    }];
    
    self.lastSelfie = [UIImage imageWithData:jpegData];
    
    [self displayLastSelfieThumb];
    
    if (![self.userDefaults boolForKey:@"showed_share"])
    {
        self.roundRectButtonPopTipView = [[CMPopTipView alloc] initWithMessage:NSLocalizedString(@"Share your beautiful smile with the world", nil)];
        self.roundRectButtonPopTipView.delegate = self;
        self.roundRectButtonPopTipView.backgroundColor = [UIColor lightGrayColor];
        self.roundRectButtonPopTipView.textColor = [UIColor darkTextColor];
        self.roundRectButtonPopTipView.dismissTapAnywhere = YES;
        
        [self.roundRectButtonPopTipView presentPointingAtView:self.share inView:self.view animated:YES];
        
        [self.userDefaults setBool:YES forKey:@"showed_share"];
        [self.userDefaults synchronize];
    }
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
    self.faceFrameCount = 0;
    
    [self.smileCounter removeAllObjects];
    [self.winkCounter removeAllObjects];
    
    //[self.autoPhoto setOn:NO animated:YES];
    
    [self updateSmiles:0];
}

#pragma mark -
- (void)lastPhoto
{
    NSString *mediaurl = [self.userDefaults objectForKey:@"last_photo"];
    
    if (!mediaurl)
    {
        return;
    }
    
    ;
    ALAssetsLibrary* assetslibrary = [[ALAssetsLibrary alloc] init];
    
    [assetslibrary assetForURL:[NSURL URLWithString:mediaurl]
                   resultBlock:^(ALAsset *myasset)
     {
         ALAssetRepresentation *representation = [myasset defaultRepresentation];
         
         
         self.lastSelfie = [UIImage imageWithCGImage:[representation fullScreenImage]];
         
         [self displayLastSelfieThumb];
     }
                  failureBlock:^(NSError *error)
     {
         DLog(@"Error getting last photo %@", error);
     }];
    
}

- (void)displayLastSelfieThumb
{
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        self.share.hidden = NO;
        
        UIImage *thumbImage = [self.lastSelfie scaleToCoverSize:CGSizeMake(50.0f, 50.0f)];
        
        
        switch (self.lastSelfie.imageOrientation) {
            case UIImageOrientationDown:
                DLog(@"UIImageOrientationDown");
                //thumbImage = [thumbImage rotateImagePixelsInRadians:-M_PI];
                break;
            case UIImageOrientationLeft:
                DLog(@"UIImageOrientationLeft");
                break;
            case UIImageOrientationRight:
                DLog(@"UIImageOrientationRight");
                //thumbImage = [thumbImage rotateImagePixelsInRadians:-M_PI];
                break;
            case UIImageOrientationLeftMirrored:
                DLog(@"UIImageOrientationLeftMirrored");
                //thumbImage = [thumbImage rotateImagePixelsInRadians:M_PI];
                break;
            case UIImageOrientationRightMirrored:
                DLog(@"UIImageOrientationRightMirrored");
                break;
            case UIImageOrientationUp:
                DLog(@"UIImageOrientationUp");
                //thumbImage = [thumbImage rotateImagePixelsInRadians:-M_PI];
                break;
            case UIImageOrientationUpMirrored:
                DLog(@"UIImageOrientationUpMirrored");
                //thumbImage = [thumbImage rotateImagePixelsInRadians:-M_PI];
                break;
            case UIImageOrientationDownMirrored:
                DLog(@"UIImageOrientationDownMirrored");
                //thumbImage = [thumbImage rotateImagePixelsInRadians:M_PI];
                break;
            default:
                break;
        }
        
        self.thumbView.image = thumbImage;
    });
}
- (void)shareImage
{
    NSString *defaultText = NSLocalizedString(([self.userDefaults doubleForKey:@"faces"] == 1) ? @"Look at my beautiful smile! #selfiecam" : @"Look at our beautiful smiles! #selfiecam", nil) ;
    
    NSArray *activityItems = [NSArray arrayWithObjects:defaultText, self.lastSelfie, nil];
    
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
    activityViewController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    
    [self presentViewController:activityViewController animated:YES completion:nil];
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
        [self.userDefaults setDouble:3 forKey:@"photo_timer"];
        
        [self.userDefaults synchronize];
    }
}

#pragma mark - ASMediasFocusDelegate
- (UIImage *)mediaFocusManager:(ASMediaFocusManager *)mediaFocusManager imageForView:(UIView *)view
{
    return ((UIImageView *)view).image;
}

// Returns the final focused frame for this media view. This frame is usually a full screen frame.
- (CGRect)mediaFocusManager:(ASMediaFocusManager *)mediaFocusManager finalFrameforView:(UIView *)view
{
    return self.view.bounds;
}

// Returns the view controller in which the focus controller is going to be added.
// This can be any view controller, full screen or not.
- (UIViewController *)parentViewControllerForMediaFocusManager:(ASMediaFocusManager *)mediaFocusManager
{
    return self;
}

- (NSURL *)mediaFocusManager:(ASMediaFocusManager *)mediaFocusManager mediaURLForView:(UIView *)view;
{
    return nil;
}

- (UIImage *)mediaFocusManager:(ASMediaFocusManager *)mediaFocusManager fullImageForView:(UIView *)view
{
    return self.lastSelfie;
}

// Returns the title for this media view. Return nil if you don't want any title to appear.
- (NSString *)mediaFocusManager:(ASMediaFocusManager *)mediaFocusManager titleForView:(UIView *)view
{
    return nil;
}

#pragma mark - CMPopTipViewDelegate methods
- (void)popTipViewWasDismissedByUser:(CMPopTipView *)popTipView {
    // User can tap CMPopTipView to dismiss it
    self.roundRectButtonPopTipView = nil;
}

#pragma mark -
- (void)updateSmiles:(NSInteger)count
{
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        self.smile1.image = (count >= 1) ? [UIImage imageNamed:@"870-smile.png"] : [UIImage imageNamed:@"870-smile-grey.png"];
        self.smile2.image = (count >= 2) ? [UIImage imageNamed:@"870-smile.png"] : [UIImage imageNamed:@"870-smile-grey.png"];
        self.smile3.image = (count >= 3) ? [UIImage imageNamed:@"870-smile.png"] : [UIImage imageNamed:@"870-smile-grey.png"];
    });
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
