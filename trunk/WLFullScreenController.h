//
//  LLFullScreenController.h
//  Welly
//
//  Created by gtCarrera @ 9# on 08-8-11.
//  Copyright 2008. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@protocol WLFullScreenProcessor;

@interface WLFullScreenController : NSObject {
	// Object to resize the target view and its super view
	// This design follows the strategy pattern...
	NSObject <WLFullScreenProcessor> *_processor;
	
	// The views necessary for full screen and reset
	NSView *_targetView;
	NSView *_superView;
	
	// NSWindows needed...
	NSWindow *_fullScreenWindow;
	NSWindow *_originalWindow;
	
	// State variable
	BOOL _isInFullScreen;
}
@property (readonly) BOOL isInFullScreen;
@property (readwrite, retain) id <WLFullScreenProcessor> processor;

// Init functions
- (id)initWithProcessor:(NSObject <WLFullScreenProcessor>*)pro 
			 targetView:(NSView*)tview 
			  superView:(NSView*)sview
		 originalWindow:(NSWindow*)owin;
- (id)initWithTargetView:(NSView*)tview 
				 superView:(NSView*)sview
			originalWindow:(NSWindow*)owin;
// Handle functions
- (void)handleFullScreen;
- (void)releaseFullScreen;
@end
