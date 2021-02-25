// -*- mode: objective-c -*-

@import Cocoa;
#import "MTInteractionCount.h"
#import "FingerStatusEntry.h"
#import "MultitouchPrivate.h"

@interface FingerStatusManager : NSObject

+ (instancetype)sharedFingerStatusManager;

- (void)update:(MTDeviceRef)device
          data:(Finger*)data
       fingers:(int)fingers
     timestamp:(double)timestamp
         frame:(int)frame;

- (NSArray<FingerStatusEntry*>*)copyEntries;

- (MTInteractionCount*)createMTInteractionCount;

@end
