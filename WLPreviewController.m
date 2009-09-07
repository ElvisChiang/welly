//
//  XIPreviewController.m
//  Welly
//
//  Created by boost @ 9# on 7/15/08.
//  Copyright 2008 Xi Wang. All rights reserved.
//

#import "WLPreviewController.h"
#import "WLQuickLookBridge.h"
#import "WLGrowlBridge.h"

#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
@interface WLDownloadDelegate : NSObject <NSWindowDelegate> {
#else
@interface WLDownloadDelegate : NSObject {
#endif
    // This progress bar is restored by gtCarrera
    // boost: don't put it in XIPreviewController
    HMBlkProgressIndicator *_indicator;
    NSPanel         *_window;
    long long _contentLength, _transferredLength;
    NSString *_filename, *_path;
    NSURLDownload *_download;
}
@property(readwrite, assign) NSURLDownload *download;
- (void)showLoadingWindow;
@end

@implementation WLPreviewController

// current downloading URLs
static NSMutableSet *sURLs;
static NSString *sCacheDir;
// current downloaded URLs
static NSMutableDictionary *downloadedURLInfo;

+ (void)initialize {
    sURLs = [[NSMutableSet alloc] initWithCapacity:10];
	downloadedURLInfo = [[NSMutableDictionary alloc] initWithCapacity:10];
    // locate the cache directory
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSAssert([paths count] > 0, @"~/Library/Caches");
    sCacheDir = [[[paths objectAtIndex:0] stringByAppendingPathComponent:@"Welly"] retain];
    // clean it at startup
    BOOL flag = NO;
    int pid = [[NSProcessInfo processInfo] processIdentifier];
    // detect if another Welly exists
    for (NSDictionary *dict in [[NSWorkspace sharedWorkspace] launchedApplications]) {
        if ([[dict objectForKey:@"NSApplicationName"] isEqual:@"Welly"] &&
            [[dict objectForKey:@"NSApplicationProcessIdentifier"] intValue] != pid) {
            flag = YES;
            break;
        }
    }
    // no other Welly
    if (!flag)
        [[NSFileManager defaultManager] removeFileAtPath:sCacheDir handler:nil];
}

- (IBAction)openPreview:(id)sender {
    [WLQuickLookBridge orderFront];
}

+ (NSURLDownload *)downloadWithURL:(NSURL *)URL {
    // already downloading
    if ([sURLs containsObject:URL])
        return nil;
    // check validity
    NSURLDownload *download;
    NSString *s = [URL absoluteString];
    NSString *suffix = [[s componentsSeparatedByString:@"."] lastObject];
    NSArray *suffixes = [NSArray arrayWithObjects:@"htm", @"html", @"shtml", @"com", @"net", @"org", nil];
    if ([s hasSuffix:@"/"] || [suffixes containsObject:suffix])
        download = nil;
    else {
		// Here, if a download is necessary, show the download window
        [sURLs addObject:URL];
        NSURLRequest *request = [NSURLRequest requestWithURL:URL
                                                 cachePolicy:NSURLRequestReturnCacheDataElseLoad
                                             timeoutInterval:30.0];
        WLDownloadDelegate *delegate = [[WLDownloadDelegate alloc] init];
        download = [[NSURLDownload alloc] initWithRequest:request delegate:delegate];
        [delegate setDownload:download];
        [delegate release];
    }
    if (download == nil)
        [[NSWorkspace sharedWorkspace] openURL:URL];
    return download;
}

@end

#pragma mark -
#pragma mark XIDownloadDelegate

@implementation WLDownloadDelegate
@synthesize download = _download;

static NSString * stringFromFileSize(long long size) {
    NSString *fmt;
    float fsize = size;
	if (size < 1023) {
        if (size > 1)
            fmt = @"%i bytes";
        else
            fmt = @"%i byte";
    }
    else {
        fsize /= 1024;
        if (fsize < 1023)
            fmt = @"%1.1f KB";
        else {
            fsize /= 1024;
            if (fsize < 1023)
                fmt = @"%1.1f MB";
            else {
                fsize /= 1024;
                fmt = @"%1.1f GB";
            }
        }
    }
    return [NSString stringWithFormat:fmt, fsize];
}

- (NSString *)stringFromTransfer {
    float p = 0;
    if (_contentLength > 0)
        p = 100.0f * _transferredLength / _contentLength;
    return [NSString stringWithFormat:@"%1.1f%% (%@ of %@)", p,
        stringFromFileSize(_transferredLength),
        stringFromFileSize(_contentLength)];
}

- init {
    if (self = [super init]) {
        [self showLoadingWindow];
    }
    return self;
}

- (void)dealloc {
    [_filename release];
    [_path release];
    // close window
    [_window close];
    [_indicator release];
    [_window release];
    [super dealloc];
}

- (void)showLoadingWindow {
    unsigned int style = NSTitledWindowMask
        | NSMiniaturizableWindowMask | NSClosableWindowMask
        | NSHUDWindowMask | NSUtilityWindowMask;

    // init
    _window = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 400, 30)
                                         styleMask:style
                                           backing:NSBackingStoreBuffered 
                                             defer:NO];
    [_window setFloatingPanel:YES];
    [_window setDelegate:self];
    [_window setOpaque:YES];
    [_window center];
    [_window setTitle:@"Loading..."];
    [_window setViewsNeedDisplay:NO];
    [_window makeKeyAndOrderFront:nil];
	[[_window windowController] setDelegate:self];

    // Init progress bar
    _indicator = [[HMBlkProgressIndicator alloc] initWithFrame:NSMakeRect(10, 10, 380, 10)];
    [[_window contentView] addSubview:_indicator];
    [_indicator startAnimation:self];
}

// Window delegate for _window, finallize the download 
- (BOOL)windowShouldClose:(id)window {
    NSURL *URL = [[_download request] URL];
    // Show the canceled message
    [WLGrowlBridge notifyWithTitle:[URL absoluteString]
                       description:NSLocalizedString(@"Canceled", @"Download canceled")
                  notificationName:@"File Transfer"
                          isSticky:NO
                        identifier:_download];
    // Remove current url from the url list
    [sURLs removeObject:URL];
    // Cancel the download
    [_download cancel];
    // Release if necessary
    [_download release];
    return YES;
}

- (void)downloadDidBegin:(NSURLDownload *)download {
    [WLGrowlBridge notifyWithTitle:[[[download request] URL] absoluteString]
                       description:NSLocalizedString(@"Connecting", @"Download begin")
                  notificationName:@"File Transfer"
                          isSticky:YES
                        identifier:download];
}

- (void)download:(NSURLDownload *)download didReceiveResponse:(NSURLResponse *)response { 
    _contentLength = [response expectedContentLength];
    _transferredLength = 0;

    // extract & fix incorrectly encoded filename (GB18030 only)
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    _filename = [response suggestedFilename];
    NSData *data = [_filename dataUsingEncoding:NSISOLatin1StringEncoding allowLossyConversion:YES];
    NSStringEncoding encoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    _filename = [[NSString alloc] initWithData:data encoding:encoding];
    [pool release];
    [WLGrowlBridge notifyWithTitle:_filename
                       description:[self stringFromTransfer]
                  notificationName:@"File Transfer"
                          isSticky:YES
                        identifier:download];

    // set local path
    [[NSFileManager defaultManager] createDirectoryAtPath:sCacheDir attributes:nil];
    _path = [[sCacheDir stringByAppendingPathComponent:_filename] retain];
	if([downloadedURLInfo objectForKey:[[[download request] URL] absoluteString]]) { // URL in cache
		// Get local file size
		NSString * tempPath = [downloadedURLInfo valueForKey:[[[download request] URL] absoluteString]];
		NSDictionary *fileAttributes = [[NSFileManager defaultManager] fileAttributesAtPath:tempPath traverseLink:YES];
		long long fileSizeOnDisk = -1;
		if (fileAttributes != nil)
			fileSizeOnDisk = [[fileAttributes objectForKey:NSFileSize] longLongValue];
		if(fileSizeOnDisk == _contentLength) { // If of the same size, use current cache
			[download cancel];
			[self downloadDidFinish:download];
			return;
		}
	}
    [download setDestination:_path allowOverwrite:YES];

	// dectect file type to avoid useless download
	// by gtCarrera @ 9#
	NSString *fileType = [[_filename pathExtension] lowercaseString];
	NSArray *allowedTypes = [NSArray arrayWithObjects:@"jpg", @"jpeg", @"bmp", @"png", @"gif", @"tiff", @"tif", @"pdf", nil];
	Boolean canView = [allowedTypes containsObject:fileType];
	if (!canView) {
		// Close the progress bar window
		[_window close];
		
        [self retain]; // "didFailWithError" may release the delegate
        [download cancel];
        [self download:download didFailWithError:nil];
        [self release];
        return; // or next may crash
	}

    // Or, set the window to show the download progress
    [_window setTitle:[NSString stringWithFormat:@"Loading %@...", _filename]];
    [_indicator setIndeterminate:NO];
    [_indicator setMaxValue:(double)_contentLength];
    [_indicator setDoubleValue:0];
}

- (void)download:(NSURLDownload *)download didReceiveDataOfLength:(NSUInteger)length { 
    _transferredLength += length;
    [WLGrowlBridge notifyWithTitle:_filename
                       description:[self stringFromTransfer]
                  notificationName:@"File Transfer"
                          isSticky:YES
                        identifier:download];
	// Add the incremented value
	[_indicator incrementBy: (double)length];
}

static void formatProps(NSMutableString *s, id *fmt, id *val) {
    for (; *fmt; ++fmt, ++val) {
        id obj = *val;
        if (obj == nil)
            continue;
        [s appendFormat:NSLocalizedString(*fmt, nil), obj];
    }
}

- (void)downloadDidFinish:(NSURLDownload *)download {
    [sURLs removeObject:[[download request] URL]];
	[downloadedURLInfo setValue:_path forKey:[[[download request] URL] absoluteString]];
    [WLQuickLookBridge add:[NSURL fileURLWithPath:_path]];
    [WLGrowlBridge notifyWithTitle:_filename
                       description:NSLocalizedString(@"Completed", "Download completed; will open previewer")
                  notificationName:@"File Transfer"
                          isSticky:NO
                        identifier:download];

    // For read exif info by gtCarrera
    // boost: pool (leaks), check nil (crash), readable values
    CGImageSourceRef exifSource = CGImageSourceCreateWithURL((CFURLRef)([NSURL fileURLWithPath:_path]), nil);
    if (exifSource) {
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSDictionary *metaData = (NSDictionary*) CGImageSourceCopyPropertiesAtIndex(exifSource, 0, nil);
		[metaData autorelease];
		NSMutableString *props = [NSMutableString string];
        NSDictionary *exifData = [metaData objectForKey:(NSString *)kCGImagePropertyExifDictionary];
		if (exifData) {
            NSString *dateTime = [exifData objectForKey:(NSString *)kCGImagePropertyExifDateTimeOriginal];
            NSNumber *eTime = [exifData objectForKey:(NSString *)kCGImagePropertyExifExposureTime];
            NSNumber *fLength = [exifData objectForKey:(NSString *)kCGImagePropertyExifFocalLength];
            NSNumber *fNumber = [exifData objectForKey:(NSString *)kCGImagePropertyExifFNumber];
            NSArray *isoArray = [exifData objectForKey:(NSString *)kCGImagePropertyExifISOSpeedRatings];
            // readable exposure time
            NSString *eTimeStr = nil;
            if (eTime) {
                double eTimeVal = [eTime doubleValue];
                // zero exposure time...
                if (eTimeVal < 1 && eTimeVal != 0) {
                    eTimeStr = [NSString stringWithFormat:@"1/%g", 1/eTimeVal];
                } else
                    eTimeStr = [eTime stringValue];
            }
            // iso
            NSNumber *iso = nil;
            if (isoArray && [isoArray count])
                iso = [isoArray objectAtIndex:0];
            // format
            id keys[] = {@"Original Date Time", @"Exposure Time", @"Focal Length", @"F Number", @"ISO", nil};
            id vals[] = {dateTime, eTimeStr, fLength, fNumber, iso};
            formatProps(props, keys,vals);
        }

        NSDictionary *tiffData = [metaData objectForKey:(NSString *)kCGImagePropertyTIFFDictionary];
        if (tiffData) {
            NSString *makeName = [tiffData objectForKey:(NSString *)kCGImagePropertyTIFFMake];
            NSString *modelName = [tiffData objectForKey:(NSString *)kCGImagePropertyTIFFModel];
            // some photos give null names
            if (makeName || modelName)
                [props appendFormat:NSLocalizedString(@"tiffStringFormat", "\nManufacturer and Model: \n%@ %@"), makeName, modelName];
        }

        if([props length]) 
            [WLGrowlBridge notifyWithTitle:_filename
                               description:props
                          notificationName:@"File Transfer"
                                  isSticky:NO
                                identifier:download];
        // release
        [pool release];
        CFRelease(exifSource);
    }

    [download release];
}

- (void)download:(NSURLDownload *)download didFailWithError:(NSError *)error {
    NSURL *URL = [[download request] URL];
    [sURLs removeObject:URL];
    [[NSWorkspace sharedWorkspace] openURL:URL];
    [WLGrowlBridge notifyWithTitle:[URL absoluteString]
                       description:NSLocalizedString(@"Opening browser", "Download failed or unsupported formats")
                  notificationName:@"File Transfer"
                          isSticky:NO
                        identifier:download];
    [download release];
}

@end
