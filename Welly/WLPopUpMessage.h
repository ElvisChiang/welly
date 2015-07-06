//
//  LLPopUpMessage.h
//  Welly
//
//  Created by gtCarrera @ 9# on 08-9-11.
//  Copyright 2008. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class WLEffectView;
@interface WLPopUpMessage:NSObject {
}

+ (void)showPopUpMessage:(NSString*)message 
				duration:(CGFloat)duration 
			  effectView:(WLEffectView *)effectView;

+ (void)hidePopUpMessage;

@end
