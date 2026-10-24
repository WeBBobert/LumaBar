#import <UIKit/UIKit.h>

#define LB_DOMAIN @"com.lumabar.tweak"
#define LB_NOTIFY "com.lumabar.tweak/prefsChanged"

@interface LBSettings : NSObject
+ (instancetype)shared;
- (void)reload;
@property (nonatomic, readonly) BOOL enabled;
@property (nonatomic, readonly) BOOL hidden;
@property (nonatomic, readonly) BOOL anyGestureAssigned;
@property (nonatomic, readonly) CGFloat widthScale;
@property (nonatomic, readonly) CGFloat heightScale;
@property (nonatomic, readonly) CGFloat radiusFraction; // 0...0.5 of bar height
@property (nonatomic, readonly) CGFloat opacity;
@property (nonatomic, readonly) CGFloat offsetX;
@property (nonatomic, readonly) CGFloat offsetY;
@property (nonatomic, readonly) CGFloat duration;
@property (nonatomic, readonly, strong) UIColor *color; // nil = system default
- (NSString *)actionForGesture:(NSString *)gesture;
@end
