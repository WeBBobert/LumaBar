#import "LBSettings.h"

static CGFloat LBClamp(CGFloat v, CGFloat lo, CGFloat hi) {
    return MAX(lo, MIN(hi, v));
}

static UIColor *LBColorFromHex(NSString *hex) {
    if (![hex isKindOfClass:NSString.class]) return nil;
    hex = [hex stringByReplacingOccurrencesOfString:@"#" withString:@""];
    if (hex.length != 6) return nil;
    unsigned v = 0;
    if (![[NSScanner scannerWithString:hex] scanHexInt:&v]) return nil;
    return [UIColor colorWithRed:((v >> 16) & 255) / 255.0
                           green:((v >> 8) & 255) / 255.0
                            blue:(v & 255) / 255.0
                           alpha:1.0];
}

@implementation LBSettings {
    NSUserDefaults *_d;
}

+ (instancetype)shared {
    static LBSettings *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [LBSettings new]; });
    return s;
}

- (instancetype)init {
    if ((self = [super init])) {
        _d = [[NSUserDefaults alloc] initWithSuiteName:LB_DOMAIN];
        // Keep in sync with lumabarprefs/Resources/Root.plist
        [_d registerDefaults:@{
            @"Enabled": @YES, @"Hidden": @NO,
            @"WidthScale": @1.0, @"HeightScale": @1.0,
            @"RadiusFraction": @0.5, @"Opacity": @1.0,
            @"OffsetX": @0.0, @"OffsetY": @0.0, @"Duration": @0.25,
            @"CustomColor": @NO, @"ColorPreset": @"#FFFFFF",
            @"ColorHex": @"#FFFFFF",
            @"Gesture_Tap": @"none", @"Gesture_DoubleTap": @"lock",
            @"Gesture_LongPress": @"spotlight", @"Gesture_SwipeUp": @"none",
            @"Gesture_SwipeDown": @"controlcenter",
            @"Gesture_SwipeLeft": @"none", @"Gesture_SwipeRight": @"none",
        }];
        [self reload];
    }
    return self;
}

- (void)reload {
    _enabled = [_d boolForKey:@"Enabled"];
    _hidden = [_d boolForKey:@"Hidden"];
    _widthScale = LBClamp([_d doubleForKey:@"WidthScale"], 0.3, 3.0);
    _heightScale = LBClamp([_d doubleForKey:@"HeightScale"], 0.3, 3.0);
    _radiusFraction = LBClamp([_d doubleForKey:@"RadiusFraction"], 0.0, 0.5);
    _opacity = LBClamp([_d doubleForKey:@"Opacity"], 0.0, 1.0);
    _offsetX = LBClamp([_d doubleForKey:@"OffsetX"], -100, 100);
    _offsetY = LBClamp([_d doubleForKey:@"OffsetY"], -30, 30);
    _duration = LBClamp([_d doubleForKey:@"Duration"], 0.0, 1.0);

    _anyGestureAssigned = [self computeAnyGesture];

    if ([_d boolForKey:@"CustomColor"]) {
        NSString *preset = [_d stringForKey:@"ColorPreset"];
        _color = LBColorFromHex([preset isEqualToString:@"custom"]
                                ? [_d stringForKey:@"ColorHex"] : preset);
    } else {
        _color = nil;
    }
}

- (BOOL)computeAnyGesture {
    for (NSString *g in @[@"Tap", @"DoubleTap", @"LongPress", @"SwipeUp",
                          @"SwipeDown", @"SwipeLeft", @"SwipeRight"]) {
        if (![[self actionForGesture:g] isEqualToString:@"none"]) return YES;
    }
    return NO;
}

- (NSString *)actionForGesture:(NSString *)gesture {
    return [_d stringForKey:[@"Gesture_" stringByAppendingString:gesture]] ?: @"none";
}
@end
