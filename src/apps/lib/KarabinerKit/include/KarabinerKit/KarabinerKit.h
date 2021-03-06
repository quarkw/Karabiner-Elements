// -*- mode: objective-c -*-

@import Foundation;
#import "KarabinerKit/ComplexModificationsAssetsFileModel.h"
#import "KarabinerKit/ComplexModificationsAssetsManager.h"
#import "KarabinerKit/ComplexModificationsAssetsRuleModel.h"
#import "KarabinerKit/ConfigurationManager.h"
#import "KarabinerKit/ConnectedDevices.h"
#import "KarabinerKit/CoreConfigurationModel.h"
#import "KarabinerKit/DeviceManager.h"
#import "KarabinerKit/JsonUtility.h"
#import "KarabinerKit/NotificationKeys.h"
#import "KarabinerKit/SmartObserverContainer.h"

@interface KarabinerKit : NSObject

+ (void)setup;
+ (void)endAllAttachedSheets:(NSWindow*)window;

+ (void)observeConsoleUserServerIsDisabledNotification;

+ (void)relaunch;
+ (BOOL)quitKarabinerWithConfirmation;

@end
