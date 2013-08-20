//
//  UIImage+Thumbnail.m
//  SelfieCam
//
//  Created by Karl Monaghan on 20/08/2013.
//  Copyright (c) 2013 Karl Monaghan. All rights reserved.
//
//  Via: https://gist.github.com/djbriane/160791

#import "UIImage+Thumbnail.h"

@implementation UIImage (Thumbnail)
+ (UIImage *)generatePhotoThumbnail:(UIImage *)image ratio:(CGFloat)ratio
{
	// Create a thumbnail version of the image for the event object.
	CGSize size = image.size;
	CGSize croppedSize;

	CGFloat offsetX = 0.0;
	CGFloat offsetY = 0.0;
	
	// check the size of the image, we want to make it
	// a square with sides the size of the smallest dimension
	if (size.width > size.height) {
		offsetX = (size.height - size.width) / 2;
		croppedSize = CGSizeMake(size.height, size.height);
	} else {
		offsetY = (size.width - size.height) / 2;
		croppedSize = CGSizeMake(size.width, size.width);
	}
	
	// Crop the image before resize
	CGRect clippedRect = CGRectMake(offsetX * -1, offsetY * -1, croppedSize.width, croppedSize.height);
	CGImageRef imageRef = CGImageCreateWithImageInRect([image CGImage], clippedRect);
	// Done cropping
	
	// Resize the image
	CGRect rect = CGRectMake(0.0, 0.0, ratio, ratio);
	
	UIGraphicsBeginImageContext(rect.size);
	[[UIImage imageWithCGImage:imageRef] drawInRect:rect];
	UIImage *thumbnail = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	// Done Resizing
	
	return thumbnail;
}
@end
