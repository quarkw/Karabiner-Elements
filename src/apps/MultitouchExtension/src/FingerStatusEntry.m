#import "FingerStatusEntry.h"

@implementation FingerStatusEntry

- (instancetype)initWithDevice:(MTDeviceRef)device
                    identifier:(int)identifier {
  self = [super init];

  if (self) {
    _device = device;
    _identifier = identifier;
    _frame = 0;
    _state = 0;
    _size = 0.0;
    _pressure = 0;
    _point = NSMakePoint(0, 0);
    _touchedPhysically = NO;
    _touchedFixed = NO;
    _ignored = YES;
    _delayTimer = nil;
    _timerMode = FingerStatusEntryTimerModeNone;
  }

  return self;
}

- (instancetype)copyWithZone:(NSZone*)zone {
  FingerStatusEntry* e = [[FingerStatusEntry alloc] initWithDevice:self.device identifier:self.identifier];

  e.frame = self.frame;
  e.state = self.state;
  e.size = self.size;
  e.pressure= self.pressure;
  e.point = self.point;
  e.touchedPhysically = self.touchedPhysically;
  e.touchedFixed = self.touchedFixed;
  e.ignored = self.ignored;
  // e.delayTimer is nil
  e.timerMode = FingerStatusEntryTimerModeNone;

  return e;
}

@end
