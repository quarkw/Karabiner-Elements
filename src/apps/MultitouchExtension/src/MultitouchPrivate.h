// -*- mode: objective-c -*-

typedef struct {
  float x;
  float y;
} mtPoint;

typedef struct {
  mtPoint position;
  mtPoint velocity;
} mtReadout;

typedef struct {
  int frame;
  double timestamp;
  int identifier;
  int state;
  int fingerId;
  int handId;
  mtReadout normalized;
  float size;
  int pressure;
  float angle;
  float majorAxis;
  float minorAxis;
  mtReadout absoluteVector;
  int unknown1[2];
  float zDensity;
} Finger;

typedef void* MTDeviceRef;
typedef int (*MTContactCallbackFunction)(MTDeviceRef, Finger*, int, double, int);

CFMutableArrayRef MTDeviceCreateList(void);
void MTRegisterContactFrameCallback(MTDeviceRef, MTContactCallbackFunction);
void MTUnregisterContactFrameCallback(MTDeviceRef, MTContactCallbackFunction);
void MTDeviceStart(MTDeviceRef, int);
void MTDeviceStop(MTDeviceRef, int);
