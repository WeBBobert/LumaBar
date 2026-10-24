#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "LBSettings.h"
#import "LBActions.h"
#import "LBDebug.h"

@interface SBHomeGrabberView : UIView
@end

static char kInstalledKey, kRawAlphaKey, kOverlayKey, kPillHiddenKey, kCatcherKey;
static NSHashTable *LBBars;

// ------------------------------------------------------------- catcher
// Taps are caught by our own transparent view placed next to the grabber
// (in its superview) instead of on the grabber itself, because the grabber's
// own interaction flags are controlled by SpringBoard.

@interface LBCatcherView : UIView
@end
@implementation LBCatcherView
- (void)touchesBegan:(NSSet *)t withEvent:(UIEvent *)e {
    LBNote(@"catcher touchesBegan");
    [super touchesBegan:t withEvent:e];
}
@end

@interface LBGestureHandler : NSObject <UIGestureRecognizerDelegate>
+ (instancetype)shared;
@end

@implementation LBGestureHandler
+ (instancetype)shared {
    static LBGestureHandler *h;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ h = [LBGestureHandler new]; });
    return h;
}

- (void)handle:(UIGestureRecognizer *)g {
    if (!LBSettings.shared.enabled) return;
    if (g.state != UIGestureRecognizerStateRecognized &&
        g.state != UIGestureRecognizerStateBegan) return;
    NSString *action = [LBSettings.shared actionForGesture:g.name];
    LBNote(@"gesture %@ -> %@", g.name, action);
    [LBActions perform:action];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)a
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)b {
    return YES; // never block the system home gesture
}
@end

static void LBPrepare(UIView *v, UIGestureRecognizer *g, NSString *name) {
    g.name = name;
    g.delegate = LBGestureHandler.shared;
    g.cancelsTouchesInView = NO;
    g.delaysTouchesBegan = NO;
    g.delaysTouchesEnded = NO;
    [v addGestureRecognizer:g];
}

static void LBInstallGestures(UIView *grabber) {
    if (objc_getAssociatedObject(grabber, &kInstalledKey)) return;
    objc_setAssociatedObject(grabber, &kInstalledKey, @YES,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    LBCatcherView *c = [LBCatcherView new];
    c.backgroundColor = UIColor.clearColor;
    objc_setAssociatedObject(grabber, &kCatcherKey, c,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    id h = LBGestureHandler.shared;
    SEL sel = @selector(handle:);

    UITapGestureRecognizer *dbl =
        [[UITapGestureRecognizer alloc] initWithTarget:h action:sel];
    dbl.numberOfTapsRequired = 2;
    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:h action:sel];
    [tap requireGestureRecognizerToFail:dbl];
    LBPrepare(c, tap, @"Tap");
    LBPrepare(c, dbl, @"DoubleTap");
    LBPrepare(c, [[UILongPressGestureRecognizer alloc]
                     initWithTarget:h action:sel], @"LongPress");

    NSDictionary *dirs = @{
        @"SwipeUp": @(UISwipeGestureRecognizerDirectionUp),
        @"SwipeDown": @(UISwipeGestureRecognizerDirectionDown),
        @"SwipeLeft": @(UISwipeGestureRecognizerDirectionLeft),
        @"SwipeRight": @(UISwipeGestureRecognizerDirectionRight),
    };
    for (NSString *name in dirs) {
        UISwipeGestureRecognizer *s =
            [[UISwipeGestureRecognizer alloc] initWithTarget:h action:sel];
        s.direction = [dirs[name] unsignedIntegerValue];
        LBPrepare(c, s, name);
    }
}

static void LBLayoutCatcher(UIView *grabber) {
    UIView *c = objc_getAssociatedObject(grabber, &kCatcherKey);
    UIView *sv = grabber.superview;
    if (!c || !sv) return;
    if (c.superview != sv) {
        [c removeFromSuperview];
        [sv addSubview:c];
    }
    CGRect r = CGRectInset([sv convertRect:grabber.bounds fromView:grabber], -30, -24);
    if (!CGRectEqualToRect(c.frame, r)) c.frame = r;
    LBSettings *s = LBSettings.shared;
    c.userInteractionEnabled = s.enabled && s.anyGestureAssigned;
}

// ------------------------------------------------------------- appearance

static CGFloat LBRawAlpha(UIView *v) {
    NSNumber *n = objc_getAssociatedObject(v, &kRawAlphaKey);
    return n ? n.doubleValue : 1.0;
}

static UIView *LBSearchPill(UIView *root, int depth) {
    if (depth > 3) return nil;
    for (UIView *s in root.subviews) {
        NSString *n = NSStringFromClass(s.class);
        if ([n containsString:@"Pill"] || [n containsString:@"Affordance"] ||
            [n containsString:@"Luma"]) return s;
    }
    for (UIView *s in root.subviews) {
        UIView *f = LBSearchPill(s, depth + 1);
        if (f) return f;
    }
    return nil;
}

// The visible bar is a child view whose name/keys differ across iOS versions.
static UIView *LBFindPill(UIView *grabber) {
    for (NSString *k in @[@"_homeAffordanceView", @"homeAffordanceView",
                          @"_pillView"]) {
        @try {
            id v = [grabber valueForKey:k];
            if ([v isKindOfClass:UIView.class] && v != grabber) return v;
        } @catch (NSException *e) {}
    }
    UIView *found = LBSearchPill(grabber, 0);
    return found ?: grabber.subviews.firstObject ?: grabber;
}

static void LBApply(UIView *v) {
    LBSettings *s = LBSettings.shared;
    UIView *pill = LBFindPill(v);
    UIView *overlay = objc_getAssociatedObject(v, &kOverlayKey);
    BOOL hiddenByUs = [objc_getAssociatedObject(v, &kPillHiddenKey) boolValue];

    if (!s.enabled) {
        v.transform = CGAffineTransformIdentity;
        overlay.hidden = YES;
        if (hiddenByUs) {
            pill.hidden = NO;
            objc_setAssociatedObject(v, &kPillHiddenKey, @NO,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        LBLayoutCatcher(v);
        return;
    }

    CGFloat w = s.widthScale, h = s.heightScale;
    CGAffineTransform t = CGAffineTransformMakeScale(w, h);
    t = CGAffineTransformTranslate(t, s.offsetX / w, s.offsetY / h);
    v.transform = t;

    if (s.color && pill != v) {
        // Draw our own bar: the system pill adapts to the background and
        // resists recoloring.
        if (!overlay) {
            overlay = [UIView new];
            overlay.userInteractionEnabled = NO;
            objc_setAssociatedObject(v, &kOverlayKey, overlay,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if (overlay.superview != pill.superview) [pill.superview addSubview:overlay];
        overlay.frame = pill.frame;
        overlay.backgroundColor = s.color;
        overlay.layer.cornerRadius = pill.bounds.size.height * s.radiusFraction;
        overlay.hidden = NO;
        pill.hidden = YES;
        objc_setAssociatedObject(v, &kPillHiddenKey, @YES,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else {
        overlay.hidden = YES;
        if (hiddenByUs) {
            pill.hidden = NO;
            objc_setAssociatedObject(v, &kPillHiddenKey, @NO,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if (s.color) v.backgroundColor = s.color; // pill == grabber fallback
        if (fabs(s.radiusFraction - 0.5) > 0.001)
            pill.layer.cornerRadius = pill.bounds.size.height * s.radiusFraction;
    }
    LBLayoutCatcher(v);
}

static void LBRefreshAll(void) {
    LBSettings *s = LBSettings.shared;
    for (UIView *v in LBBars.allObjects) {
        [UIView animateWithDuration:s.duration animations:^{
            LBApply(v);
            [v setAlpha:LBRawAlpha(v)];
        }];
    }
}

static void LBPrefsChanged(CFNotificationCenterRef c, void *o, CFStringRef n,
                           const void *obj, CFDictionaryRef info) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [LBSettings.shared reload];
        LBNote(@"prefs reloaded");
        LBRefreshAll();
    });
}

static void LBDumpRequested(CFNotificationCenterRef c, void *o, CFStringRef n,
                            const void *obj, CFDictionaryRef info) {
    dispatch_async(dispatch_get_main_queue(), ^{
        LBWriteReport(LBBars.allObjects);
    });
}

// ------------------------------------------------------------- hooks

%hook SBHomeGrabberView

- (void)didMoveToWindow {
    %orig;
    if (!self.window) {
        [objc_getAssociatedObject(self, &kCatcherKey) removeFromSuperview];
        return;
    }
    [LBBars addObject:self];
    LBInstallGestures(self);
    LBApply(self);
    [self setAlpha:LBRawAlpha(self)];

    // One automatic report shortly after the first grabber appears.
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 8 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{
            LBWriteReport(LBBars.allObjects);
        });
    });
}

- (void)layoutSubviews {
    %orig;
    LBApply(self);
}

// SpringBoard fades the bar itself; clamp instead of overriding.
- (void)setAlpha:(CGFloat)alpha {
    objc_setAssociatedObject(self, &kRawAlphaKey, @(alpha),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    LBSettings *s = LBSettings.shared;
    if (!s.enabled) { %orig(alpha); return; }
    %orig(s.hidden ? 0.0 : MIN(alpha, s.opacity));
}

%end

%ctor {
    LBBars = [NSHashTable weakObjectsHashTable];
    CFNotificationCenterRef nc = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterAddObserver(nc, NULL, LBPrefsChanged,
        CFSTR(LB_NOTIFY), NULL, CFNotificationSuspensionBehaviorCoalesce);
    CFNotificationCenterAddObserver(nc, NULL, LBDumpRequested,
        CFSTR(LB_DUMP_NOTIFY), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    LBNote(@"loaded in %@", NSBundle.mainBundle.bundleIdentifier);
}
