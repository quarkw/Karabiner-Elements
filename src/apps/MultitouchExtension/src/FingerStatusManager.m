#import <Cocoa/Cocoa.h>
#import "FingerStatusManager.h"
#import "NotificationKeys.h"
#import "PreferencesController.h"
#import "PreferencesKeys.h"
#import <pqrs/weakify.h>
// @import Foundation;
// @import IOKit;

// CF_EXPORT CFTypeRef MTActuatorCreateFromDeviceID(UInt64 arg0);
// CF_EXPORT IOReturn MTActuatorOpen(CFTypeRef actuatorRef);
// CF_EXPORT IOReturn MTActuatorClose(CFTypeRef actuatorRef);
// CF_EXPORT IOReturn MTActuatorActuate(CFTypeRef actuatorRef, SInt32 actuationID, int unknown1, float unknown2, float unknown3);
// CF_EXPORT bool MTActuatorIsOpen(CFTypeRef actuatorRef);

// static void release(CFTypeRef *typeRefRef) {
//     CFTypeRef typeRef = *typeRefRef;
//     if (typeRef) {
//         CFRelease(typeRef);
//     }
// }

@interface FingerStatusManager ()

@property NSMutableArray<FingerStatusEntry*>* entries;
@end

@implementation FingerStatusManager

- (instancetype)init {
  self = [super init];

  if (self) {
    _entries = [NSMutableArray new];
  }

  return self;
}

+ (instancetype)sharedFingerStatusManager {
  static dispatch_once_t once;
  static FingerStatusManager* manager;

  dispatch_once(&once, ^{
    manager = [FingerStatusManager new];
  });

  return manager;
}

- (void)update:(MTDeviceRef)device
          data:(Finger*)data
       fingers:(int)fingers
     timestamp:(double)timestamp
         frame:(int)frame {
  BOOL callFixedFingerStateChanged = NO;

  @synchronized(self) {
    //
    // Update physical touched fingers
    //
    //CFTypeRef actuatorRef __attribute__((cleanup(release))) = MTActuatorCreateFromDeviceID(0x200000001000000);

    for (int i = 0; i < fingers; ++i) {
      int identifier = data[i].identifier;

      // state values:
      //   4: touched
      //   1-3,5-7: near
      BOOL touched = NO;
      // NSLog(@"state %i", data[i].state);
      // NSLog(@"fingerId %i", data[i].fingerId);
      // NSLog(@"handId %i", data[i].handId);
      // NSLog(@"size %f", data[i].size);
      // NSLog(@"pressure %i ", data[i].pressure);
      // NSLog(@"zDensity %f", data[i].zDensity);
      // if(data[i].size > 3.0) {
      //   MTActuatorActuate(actuatorRef, 4, 0, 0.0, 2.0);
      // } else {
      //   MTActuatorClose(actuatorRef);
      // }
      if (data[i].state == 4) {
        touched = YES;
      } else {
        touched = NO;
      }

      FingerStatusEntry* e = [self findEntry:device identifier:identifier];
      if (!e) {
        if (!touched) {
          continue;
        } else {
          e = [[FingerStatusEntry alloc] initWithDevice:device identifier:identifier];
          [self.entries addObject:e];
        }
      }

      e.state = data[i].state;
      e.size = data[i].size;
      e.pressure = data[i].pressure;
      e.frame = frame;
      e.point = NSMakePoint(data[i].normalized.position.x, data[i].normalized.position.y);

      // Note:
      // Once the point in targetArea, keep `ignored == NO`.
      if (e.ignored) {
        NSRect targetArea = [PreferencesController makeTargetArea];
        if (NSPointInRect(e.point, targetArea)) {
          e.ignored = NO;
          callFixedFingerStateChanged = YES;
        }
      }

      if (e.touchedPhysically != touched) {
        e.touchedPhysically = touched;

        [self setFingerStatusEntryDelayTimer:e touched:touched];
      }
    }

    //
    // Update physical untouched fingers
    //

    for (FingerStatusEntry* e in self.entries) {
      if (e.device == device &&
          e.frame != frame &&
          e.touchedPhysically) {
        e.touchedPhysically = NO;

        [self setFingerStatusEntryDelayTimer:e touched:NO];
      }
    }
  }

  //
  // Post notifications
  //
  // Note:
  // This method might be called on a background thread.
  // We use dispatch_async to ensure the notification is post on the main thread
  // in order to avoid a deadlock at quitting app.
  //

  @weakify(self);
  dispatch_async(dispatch_get_main_queue(), ^{
    @strongify(self);
    if (!self) {
      return;
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:kPhysicalFingerStateChanged
                                                        object:self];

    if (callFixedFingerStateChanged) {
      [[NSNotificationCenter defaultCenter] postNotificationName:kFixedFingerStateChanged
                                                          object:self];
    }
  });
}

// Note: This method is called in @synchronized(self)
- (FingerStatusEntry*)findEntry:(MTDeviceRef)device
                     identifier:(int)identifier {
  for (FingerStatusEntry* e in self.entries) {
    if (e.device == device &&
        e.identifier == identifier) {
      return e;
    }
  }

  return nil;
}

// Note: This method is called in @synchronized(self)
- (void)setFingerStatusEntryDelayTimer:(FingerStatusEntry*)entry
                               touched:(BOOL)touched {
  enum FingerStatusEntryTimerMode timerMode = FingerStatusEntryTimerModeNone;
  if (touched) {
    timerMode = FingerStatusEntryTimerModeTouched;
  } else {
    timerMode = FingerStatusEntryTimerModeUntouched;
  }

  if (entry.timerMode != timerMode) {
    entry.timerMode = timerMode;

    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

    double delay = 0;
    if (touched) {
      delay = [defaults integerForKey:kDelayBeforeTurnOn];
    } else {
      delay = [defaults integerForKey:kDelayBeforeTurnOff];
    }

    [entry.delayTimer invalidate];

    @weakify(self);
    entry.delayTimer = [NSTimer timerWithTimeInterval:delay / 1000.0
                                              repeats:NO
                                                block:^(NSTimer* timer) {
                                                  @strongify(self);
                                                  if (!self) {
                                                    return;
                                                  }

                                                  @synchronized(self) {
                                                    entry.touchedFixed = touched;

                                                    if (!touched) {
                                                      [self.entries removeObjectIdenticalTo:entry];
                                                    }
                                                  }

                                                  [[NSNotificationCenter defaultCenter] postNotificationName:kFixedFingerStateChanged
                                                                                                      object:self];
                                                }];
    [[NSRunLoop mainRunLoop] addTimer:entry.delayTimer forMode:NSRunLoopCommonModes];
  }
}

- (NSArray<FingerStatusEntry*>*)copyEntries {
  @synchronized(self) {
    return [[NSArray alloc] initWithArray:self.entries copyItems:YES];
  }
}

- (MTInteractionCount*)createMTInteractionCount {
  @synchronized(self) {
    MTInteractionCount* mtInteractionCount = [MTInteractionCount new];

    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    double palmThreshold = 2.0;
    palmThreshold = [defaults doubleForKey:kPalmSizeBeforeTurnOn];

    for (FingerStatusEntry* e in self.entries) {
      if (e.ignored) {
        continue;
      }

      if (!e.touchedFixed) {
        continue;
      }

      NSLog(@"%f", palmThreshold);
      if (e.size > palmThreshold) {
        // NSLog(@"TRIGGERED");
        // [[NSHapticFeedbackManager defaultPerformer] 
        //   performFeedbackPattern:NSHapticFeedbackPatternGeneric 
        //   performanceTime:NSHapticFeedbackPerformanceTimeNow];
        if (e.point.x < 0.5) {
          ++mtInteractionCount.leftHalfAreaPalmCount;
        } else {
          ++mtInteractionCount.rightHalfAreaPalmCount;
        }

        if (e.point.y < 0.5) {
          ++mtInteractionCount.lowerHalfAreaPalmCount;
        } else {
          ++mtInteractionCount.upperHalfAreaPalmCount;
        }     

        ++mtInteractionCount.totalPalmCount;
      }
              NSLog(@"size %f", e.size);
        NSLog(@"pressure %i ", e.pressure);

      if (e.point.x < 0.5) {
        ++mtInteractionCount.leftHalfAreaFingerCount;
      } else {
        ++mtInteractionCount.rightHalfAreaFingerCount;
      }

      if (e.point.y < 0.5) {
        ++mtInteractionCount.lowerHalfAreaFingerCount;
      } else {
        ++mtInteractionCount.upperHalfAreaFingerCount;
      }

      ++mtInteractionCount.totalFingerCount;
    }

    return mtInteractionCount;
  }
}

@end
