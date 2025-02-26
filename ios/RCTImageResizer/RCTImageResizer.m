//
//  ImageResize.m
//  ChoozItApp
//
//  Created by Florian Rival on 19/11/15.
//

#include "RCTImageResizer.h"

#if __has_include(<React/RCTBridgeModule.h>)
#import <React/RCTBridgeModule.h>
#import <React/RCTImageLoader.h>
#else
#import "RCTBridgeModule.h"
#import "RCTImageLoader.h"
#endif

#import <AssetsLibrary/AssetsLibrary.h>
#import <MobileCoreServices/MobileCoreServices.h>

@implementation ImageResizer

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE();

bool saveImage(NSString * fullPath, UIImage * image, NSString * format, float quality, NSMutableDictionary *metadata)
{
    if(metadata == nil){
        NSData* data = nil;
        if ([format isEqualToString:@"JPEG"]) {
            data = UIImageJPEGRepresentation(image, quality / 100.0);
        } else if ([format isEqualToString:@"PNG"]) {
            data = UIImagePNGRepresentation(image);
        }

        if (data == nil) {
            return NO;
        }

        NSFileManager* fileManager = [NSFileManager defaultManager];
        return [fileManager createFileAtPath:fullPath contents:data attributes:nil];
    }

    // process / write metadata together with image data
    else{

        CFStringRef imgType = kUTTypeJPEG;

        if ([format isEqualToString:@"JPEG"]) {
            [metadata setObject:@(quality / 100.0) forKey:(__bridge NSString *)kCGImageDestinationLossyCompressionQuality];
        }
        else if([format isEqualToString:@"PNG"]){
            imgType = kUTTypePNG;
        }
        else{
            return NO;
        }

        NSMutableData * destData = [NSMutableData data];

        CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)destData, imgType, 1, NULL);

        @try{
            CGImageDestinationAddImage(destination, image.CGImage, (__bridge CFDictionaryRef) metadata);

            // write final image data with metadata to our destination
            if (CGImageDestinationFinalize(destination)){

                NSFileManager* fileManager = [NSFileManager defaultManager];
                return [fileManager createFileAtPath:fullPath contents:destData attributes:nil];
            }
            else{
                return NO;
            }
        }
        @finally{
            @try{
                CFRelease(destination);
            }
            @catch(NSException *exception){
                NSLog(@"Failed to release CGImageDestinationRef: %@", exception);
            }
        }
    }
}

NSString * generateFilePath(NSString * ext, NSString * outputPath, NSString * fileName)
{
    NSString* directory;

    if ([outputPath length] == 0) {
        NSArray* paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        directory = [paths firstObject];
    } else {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        if ([outputPath hasPrefix:documentsDirectory]) {
            directory = outputPath;
        } else {
            directory = [documentsDirectory stringByAppendingPathComponent:outputPath];
        }

        NSError *error;
        [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            NSLog(@"Error creating documents subdirectory: %@", error);
            @throw [NSException exceptionWithName:@"InvalidPathException" reason:[NSString stringWithFormat:@"Error creating documents subdirectory: %@", error] userInfo:nil];
        }
    }

    NSString* name;
    if ([fileName length] == 0) {
        name = [[NSUUID UUID] UUIDString];
    } else {
        name = fileName;
    }

    NSString* fullName = [NSString stringWithFormat:@"%@.%@", name, ext];
    NSString* fullPath = [directory stringByAppendingPathComponent:fullName];

    return fullPath;
}

UIImage * rotateImage(UIImage *inputImage, float rotationDegrees)
{

    // We want only fixed 0, 90, 180, 270 degree rotations.
    const int rotDiv90 = (int)round(rotationDegrees / 90);
    const int rotQuadrant = rotDiv90 % 4;
    const int rotQuadrantAbs = (rotQuadrant < 0) ? rotQuadrant + 4 : rotQuadrant;

    // Return the input image if no rotation specified.
    if (0 == rotQuadrantAbs) {
        return inputImage;
    } else {
        // Rotate the image by 80, 180, 270.
        UIImageOrientation orientation = UIImageOrientationUp;

        switch(rotQuadrantAbs) {
            case 1:
                orientation = UIImageOrientationRight; // 90 deg CW
                break;
            case 2:
                orientation = UIImageOrientationDown; // 180 deg rotation
                break;
            default:
                orientation = UIImageOrientationLeft; // 90 deg CCW
                break;
        }

        return [[UIImage alloc] initWithCGImage: inputImage.CGImage
                                                  scale: 1.0
                                                  orientation: orientation];
    }
}

float getScaleForProportionalResize( CGSize theSize, CGSize intoSize, bool onlyScaleDown, bool maximize )
{
    float    sx = theSize.width;
    float    sy = theSize.height;
    float    dx = intoSize.width;
    float    dy = intoSize.height;
    float    scale    = 1;

    if( sx != 0 && sy != 0 )
    {
        dx    = dx / sx;
        dy    = dy / sy;

        // if maximize is true, take LARGER of the scales, else smaller
        if( maximize )        scale    = (dx > dy)    ? dx : dy;
        else                scale    = (dx < dy)    ? dx : dy;

        if( scale > 1 && onlyScaleDown )    // reset scale
            scale    = 1;
    }
    else
    {
        scale     = 0;
    }
    return scale;
}


// returns a resized image keeping aspect ratio and considering
// any :image scale factor.
// The returned image is an unscaled image (scale = 1.0)
// so no additional scaling math needs to be done to get its pixel dimensions
UIImage* scaleImage (UIImage* image, CGSize toSize)
{

    // Need to do scaling corrections
    // based on scale, since UIImage width/height gives us
    // a possibly scaled image (dimensions in points)
    // Idea taken from RNCamera resize code
    CGSize imageSize = CGSizeMake(image.size.width * image.scale, image.size.height * image.scale);

    float scale = getScaleForProportionalResize(imageSize, toSize, false, false);

    // using this instead of ImageHelpers allows us to consider
    // rotation variations
    float newWidth = (int)(roundf(imageSize.width * scale) / 2) * 2;
    float newHeight = (int)(roundf(imageSize.height * scale) / 2) * 2;
    CGSize newSize = CGSizeMake(newWidth, newHeight);


    UIGraphicsBeginImageContextWithOptions(newSize, NO, 1.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

// Returns the image's metadata, or nil if failed to retrieve it.
NSMutableDictionary * getImageMeta(NSString * path)
{
    if([path hasPrefix:@"assets-library"]) {

        __block NSMutableDictionary* res = nil;

        ALAssetsLibraryAssetForURLResultBlock resultblock = ^(ALAsset *myasset)
        {

            NSDictionary *exif = [[myasset defaultRepresentation] metadata];
            res = [exif mutableCopy];

        };

        ALAssetsLibrary* assetslibrary = [[ALAssetsLibrary alloc] init];
        NSURL *url = [NSURL URLWithString:[path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];

        [assetslibrary assetForURL:url resultBlock:resultblock failureBlock:^(NSError *error) { NSLog(@"error couldn't image from assets library"); }];

        return res;

    } else {

        NSData* imageData = nil;

        if ([path hasPrefix:@"data:"] || [path hasPrefix:@"file:"]) {
            NSURL *imageUrl = [[NSURL alloc] initWithString:path];
            imageData = [NSData dataWithContentsOfURL:imageUrl];

        } else {
            imageData = [NSData dataWithContentsOfFile:path];
        }

        if(imageData == nil){
            NSLog(@"Could not get image file data to extract metadata.");
            return nil;
        }

        CGImageSourceRef source = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);


        if(source != nil){

            CFDictionaryRef metaRef = CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);

            // release CF image
            CFRelease(source);

            CFMutableDictionaryRef metaRefMutable = CFDictionaryCreateMutableCopy(NULL, 0, metaRef);

            // release the source meta ref now that we've copie it
            CFRelease(metaRef);

            // bridge CF object so it auto releases
            NSMutableDictionary* res = (NSMutableDictionary *)CFBridgingRelease(metaRefMutable);

            return res;

        }
        else{
            return nil;
        }

    }
}

void transformImage(UIImage *image,
                    NSString * originalPath,
                    RCTResponseSenderBlock callback,
                    int rotation,
                    CGSize newSize,
                    NSString* fullPath,
                    NSString* format,
                    int quality,
                    BOOL keepMeta)
{
    if (image == nil) {
        callback(@[@"Can't retrieve the file from the path.", @""]);
        return;
    }

    // Rotate image if rotation is specified.
    if (0 != (int)rotation) {
        image = rotateImage(image, rotation);
        if (image == nil) {
            callback(@[@"Can't rotate the image.", @""]);
            return;
        }
    }

    // Do the resizing
    UIImage * scaledImage = scaleImage(image, newSize);

    if (scaledImage == nil) {
        callback(@[@"Can't resize the image.", @""]);
        return;
    }


    NSMutableDictionary *metadata = nil;

    // to be consistent with Android, we will only allow JPEG
    // to do this.
    if(keepMeta && [format isEqualToString:@"JPEG"]){

        metadata = getImageMeta(originalPath);

        // remove orientation (since we fix it)
        // width/height meta is adjusted automatically
        // NOTE: This might still leave some stale values due to resize
        metadata[(NSString*)kCGImagePropertyOrientation] = @(1);

    }

    // Compress and save the image
    if (!saveImage(fullPath, scaledImage, format, quality, metadata)) {
        callback(@[@"Can't save the image. Check your compression format and your output path", @""]);
        return;
    }

    NSURL *fileUrl = [[NSURL alloc] initFileURLWithPath:fullPath];
    NSString *fileName = fileUrl.lastPathComponent;
    NSError *attributesError = nil;
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:fullPath error:&attributesError];
    NSNumber *fileSize = fileAttributes == nil ? 0 : [fileAttributes objectForKey:NSFileSize];
    NSDictionary *response = @{@"path": fullPath,
                               @"uri": fileUrl.absoluteString,
                               @"name": fileName,
                               @"size": fileSize == nil ? @(0) : fileSize,
                               @"width": @(scaledImage.size.width),
                               @"height": @(scaledImage.size.height)
                               };

    callback(@[[NSNull null], response]);
}

RCT_EXPORT_METHOD(createResizedImage:(NSString *)path
                  width:(float)width
                  height:(float)height
                  format:(NSString *)format
                  quality:(float)quality
                  rotation:(float)rotation
                  outputPath:(NSString *)outputPath
                  fileName:(NSString *)fileName
                  keepMeta:(BOOL)keepMeta
                  callback:(RCTResponseSenderBlock)callback)
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        CGSize newSize = CGSizeMake(width, height);

        //Set image extension
        NSString *extension = @"jpg";
        if ([format isEqualToString:@"PNG"]) {
            extension = @"png";
        }

        NSString* fullPath;
        @try {
            fullPath = generateFilePath(extension, outputPath, fileName);
        } @catch (NSException *exception) {
            callback(@[@"Invalid output path.", @""]);
            return;
        }


        [[self.bridge moduleForName:@"ImageLoader" lazilyLoadIfNecessary:YES] loadImageWithURLRequest:[RCTConvert NSURLRequest:path] callback:^(NSError *error, UIImage *image) {
            if (error) {
                callback(@[@"Can't retrieve the file from the path.", @""]);
                return;
            }

            transformImage(image, path, callback, rotation, newSize, fullPath, format, quality, keepMeta);
        }];
    });
}

RCT_EXPORT_METHOD(copyExif:(NSString *)imageSrc
                  imageDest:(NSString *)imageDest
                  callback:(RCTResponseSenderBlock)callback)
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        NSMutableDictionary * metadata = getImageMeta(imageSrc);

        if (metadata == nil){
            callback(@[@"Can't retrieve the metadata from the path.", @""]);
            return;
        }

        NSURL *fileUrl = [[NSURL alloc] initFileURLWithPath:imageDest];
        
        [[self.bridge moduleForName:@"ImageLoader" lazilyLoadIfNecessary:YES] loadImageWithURLRequest:[[NSURLRequest alloc] initWithURL:fileUrl] callback:^(NSError *error, UIImage *image) {
            if (error) {
                callback(@[@"Can't retrieve the file from the path.", @""]);
                return;
            }

            NSMutableData * destData = [NSMutableData data];

            CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)destData, kUTTypeJPEG, 1, NULL);

            @try{
                CGImageDestinationAddImage(destination, image.CGImage, (__bridge CFDictionaryRef) metadata);

                // write final image data with metadata to our destination
                if (CGImageDestinationFinalize(destination)){
                    NSFileManager* fileManager = [NSFileManager defaultManager];
                    [fileManager createFileAtPath:imageDest contents:destData attributes:nil];
                }
                else{
                    callback(@[@"Failed to write image at specified path.", @""]);
                    return;
                }
            }
            @finally{
                @try{
                    CFRelease(destination);
                }
                @catch(NSException *exception){
                    NSLog(@"Failed to release CGImageDestinationRef: %@", exception);
                }
                
                NSDictionary *response = @{@"path": imageDest };
                callback(@[[NSNull null], response]);
            }
        }];
    });
}

@end
