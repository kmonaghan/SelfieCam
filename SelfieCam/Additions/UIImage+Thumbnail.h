//
//  UIImage+Thumbnail.h
//  SelfieCam
//
//  Created by Karl Monaghan on 20/08/2013.
//  Copyright (c) 2013 Karl Monaghan. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (Thumbnail)
+ (UIImage *)generatePhotoThumbnail:(UIImage *)image ratio:(CGFloat)ratio;
@end
