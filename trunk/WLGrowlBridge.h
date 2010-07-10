//
//  TYGrowlBridge.h
//  Welly
//
//  Created by aqua9 on 20/3/2008.
//  Copyright 2008 TANG Yang. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Growl/GrowlApplicationBridge.h>

NSString *const WLGrowlNotificationNameFileTransfer;
NSString *const WLGrowlNotificationNameEXIFInformation;
NSString *const WLGrowlNotificationNameNewMessageReceived;

#define kGrowlNotificationNameFileTransfer			NSLocalizedString(WLGrowlNotificationNameFileTransfer, @"Growl Notification Name")
#define kGrowlNotificationNameEXIFInformation		NSLocalizedString(WLGrowlNotificationNameEXIFInformation, @"Growl Notification Name")
#define kGrowlNotificationNameNewMessageReceived	NSLocalizedString(WLGrowlNotificationNameNewMessageReceived, @"Growl Notification Name")

@interface WLGrowlBridge : NSObject <GrowlApplicationBridgeDelegate>

// iconData:nil priority:0 isSticky:NO
+ (void)notifyWithTitle:(NSString *)title
            description:(NSString *)description
       notificationName:(NSString *)notifName;

// iconData:nil priority:0
// identifier can be any object, not restricted to NSString
+ (void)notifyWithTitle:(NSString *)title
            description:(NSString *)description
       notificationName:(NSString *)notifName
               isSticky:(BOOL)isSticky
             identifier:(id)identifier;

+ (void)notifyWithTitle:(NSString *)title
            description:(NSString *)description
       notificationName:(NSString *)notifName
               isSticky:(BOOL)isSticky
           clickContext:(id)clickContext
          clickSelector:(SEL)clickSelector
             identifier:(id)identifier;

// clickContext can be any object, not restricted to plist-encodable
+ (void)notifyWithTitle:(NSString *)title
            description:(NSString *)description
       notificationName:(NSString *)notifName
               iconData:(NSData *)iconData
               priority:(signed int)priority
               isSticky:(BOOL)isSticky
           clickContext:(id)clickContext
          clickSelector:(SEL)clickSelector
             identifier:(id)identifier;

@end
