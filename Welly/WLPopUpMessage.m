//
//  LLPopUpMessage.m
//  Welly
//
//  Created by gtCarrera @ 9# on 08-9-11.
//  Copyright 2008. All rights reserved.
//

#import "WLPopUpMessage.h"
#import "WLEffectView.h"

@implementation WLPopUpMessage

WLEffectView *_effectView;

#pragma mark Class methods
+ (void)hidePopUpMessage {
	if (_effectView) {
		[_effectView removePopUpMessage];
		[_effectView release];
	}
}

+ (void)showPopUpMessage:(NSString*)message 
				duration:(CGFloat)duration 
			  effectView:(WLEffectView *)effectView {
	[effectView drawPopUpMessage:message];
	_effectView = [effectView retain];
	[NSTimer scheduledTimerWithTimeInterval:duration 
									  target:self 
									selector:@selector(hidePopUpMessage)
									userInfo:nil
									 repeats:NO];
}

@end
