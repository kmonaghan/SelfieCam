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

#define CAPTURE_FPS 30

static CGFloat DegreesToRadians(CGFloat degrees) {return degrees * M_PI / 180;};

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

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
	return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
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

#pragma mark -
// find where the video box is positioned within the preview layer based on the video size and gravity
+ (CGRect)videoPreviewBoxForGravity:(NSString *)gravity frameSize:(CGSize)frameSize apertureSize:(CGSize)apertureSize
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

// called asynchronously as the capture output is capturing sample buffers, this method asks the face detector (if on)
// to detect features and for each draw the red square in a layer and set appropriate orientation
- (void)drawFaceBoxesForFeatures:(NSArray *)features forVideoBox:(CGRect)clap orientation:(UIDeviceOrientation)orientation
{
    for (UIView *view in [cameraView subviews]) {
        [view removeFromSuperview];
    }
    
	NSArray *sublayers = [NSArray arrayWithArray:[previewLayer sublayers]];
	NSInteger sublayersCount = [sublayers count], currentSublayer = 0;
	NSInteger featuresCount = [features count], currentFeature = 0;
	
	[CATransaction begin];
	[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
	
	// hide all the face layers
	for ( CALayer *layer in sublayers ) {
		if ( [[layer name] isEqualToString:@"FaceLayer"] )
			[layer setHidden:YES];
	}
    
	CGSize parentFrameSize = [cameraView frame].size;
	NSString *gravity = [previewLayer videoGravity];
	BOOL isMirrored = [previewLayer isMirrored];
	CGRect previewBox = [CBPViewController videoPreviewBoxForGravity:gravity
                                                                 frameSize:parentFrameSize
                                                              apertureSize:clap.size];
	
	for ( CIFaceFeature *ff in features ) {
		// find the correct position for the square layer within the previewLayer
		// the feature box originates in the bottom left of the video frame.
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
		
		CALayer *featureLayer = nil;
		
		// re-use an existing layer if possible
		while ( !featureLayer && (currentSublayer < sublayersCount) ) {
			CALayer *currentLayer = [sublayers objectAtIndex:currentSublayer++];
			if ( [[currentLayer name] isEqualToString:@"FaceLayer"] ) {
				featureLayer = currentLayer;
				[currentLayer setHidden:NO];
			}
		}
		
		// create a new one if necessary
		if ( !featureLayer ) {
            UIView *view = [[UIView alloc] initWithFrame:faceRect];
            
            view.layer.borderWidth = 4.0f;
            
            view.layer.borderColor = [UIColor greenColor].CGColor;
            
            [cameraView addSubview:view];
		}
        
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
	// got an image
	CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
	CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
	CIImage *ciImage = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer options:(__bridge NSDictionary *)attachments];
	if (attachments)
		CFRelease(attachments);
	NSDictionary *imageOptions = nil;
	UIDeviceOrientation curDeviceOrientation = [[UIDevice currentDevice] orientation];
	int exifOrientation;
	
    /* kCGImagePropertyOrientation values
     The intended display orientation of the image. If present, this key is a CFNumber value with the same value as defined
     by the TIFF and EXIF specifications -- see enumeration of integer constants.
     The value specified where the origin (0,0) of the image is located. If not present, a value of 1 is assumed.
     
     used when calling featuresInImage: options: The value for this key is an integer NSNumber from 1..8 as found in kCGImagePropertyOrientation.
     If present, the detection will be done based on that orientation but the coordinates in the returned features will still be based on those of the image. */
    
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
	
	switch (curDeviceOrientation) {
		case UIDeviceOrientationPortraitUpsideDown:  // Device oriented vertically, home button on the top
			exifOrientation = PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM;
			break;
		case UIDeviceOrientationLandscapeLeft:       // Device oriented horizontally, home button on the right
			exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
			break;
		case UIDeviceOrientationLandscapeRight:      // Device oriented horizontally, home button on the left
			exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
			break;
		case UIDeviceOrientationPortrait:            // Device oriented vertically, home button on the bottom
		default:
			exifOrientation = PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP;
			break;
	}
    
	imageOptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:exifOrientation] forKey:CIDetectorImageOrientation];
	NSArray *features = [faceDetector featuresInImage:ciImage options:imageOptions];
	
    // get the clean aperture
    // the clean aperture is a rectangle that defines the portion of the encoded pixel dimensions
    // that represents image data valid for display.
	CMFormatDescriptionRef fdesc = CMSampleBufferGetFormatDescription(sampleBuffer);
	CGRect clap = CMVideoFormatDescriptionGetCleanAperture(fdesc, false /*originIsTopLeft == false*/);
	
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		[self drawFaceBoxesForFeatures:features forVideoBox:clap orientation:curDeviceOrientation];
	});
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
