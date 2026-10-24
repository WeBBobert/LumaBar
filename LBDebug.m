#import "LBDebug.h"
#import "LBActions.h"
#import "LBSettings.h"
#import <objc/runtime.h>
#import <sys/utsname.h>

static NSMutableArray *LBRing(void) {
    static NSMutableArray *r;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ r = [NSMutableArray array]; });
    return r;
}

void LBNote(NSString *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    NSString *m = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    NSLog(@"[LumaBar] %@", m);
    NSMutableArray *r = LBRing();
    @synchronized (r) {
        [r addObject:[NSString stringWithFormat:@"%@  %@", [NSDate date], m]];
        if (r.count > 60) [r removeObjectAtIndex:0];
    }
}

static void LBDumpView(UIView *v, int depth, NSMutableString *out) {
    if (depth > 6) return;
    [out appendFormat:@"%*s%@ frame=%@ alpha=%.2f hidden=%d interaction=%d clips=%d\n",
        depth * 2, "", NSStringFromClass(v.class),
        NSStringFromCGRect(v.frame), v.alpha, v.hidden,
        v.userInteractionEnabled, v.clipsToBounds];
    for (UIView *s in v.subviews) LBDumpView(s, depth + 1, out);
}

static NSString *LBMatchingClasses(void) {
    NSArray *keys = @[@"HomeGrabber", @"HomeAffordance", @"Spotlight",
                      @"ScreenRecord", @"Screenshot", @"ControlCenterController",
                      @"LockScreenManager", @"UserInterfaceStyleArbiter",
                      @"HomeGesture"];
    unsigned n = 0;
    Class *list = objc_copyClassList(&n);
    NSMutableArray *hits = [NSMutableArray array];
    for (unsigned i = 0; i < n; i++) {
        NSString *name = NSStringFromClass(list[i]);
        for (NSString *k in keys) {
            if ([name containsString:k]) { [hits addObject:name]; break; }
        }
    }
    free(list);
    [hits sortUsingSelector:@selector(compare:)];
    if (hits.count > 250) [hits removeObjectsInRange:NSMakeRange(250, hits.count - 250)];
    return [hits componentsJoinedByString:@"\n"];
}

static NSString *LBBuildReport(NSArray *grabbers) {
    struct utsname u;
    uname(&u);
    NSMutableString *o = [NSMutableString string];
    [o appendFormat:@"LumaBar debug report  %@\n", [NSDate date]];
    [o appendFormat:@"iOS %@  device %s\n\n", UIDevice.currentDevice.systemVersion,
        u.machine];

    LBSettings *s = LBSettings.shared;
    [o appendFormat:@"Settings: enabled=%d hidden=%d w=%.2f h=%.2f radius=%.2f "
        "opacity=%.2f color=%@ anyGesture=%d\n\n",
        s.enabled, s.hidden, s.widthScale, s.heightScale, s.radiusFraction,
        s.opacity, s.color, s.anyGestureAssigned];

    [o appendFormat:@"== Home grabber instances: %lu ==\n", (unsigned long)grabbers.count];
    for (UIView *g in grabbers) {
        [o appendString:@"-- grabber subtree --\n"];
        LBDumpView(g, 0, o);
        [o appendString:@"-- superview chain --\n"];
        for (UIView *p = g.superview; p; p = p.superview) {
            [o appendFormat:@"%@ frame=%@ interaction=%d clips=%d\n",
                NSStringFromClass(p.class), NSStringFromCGRect(p.frame),
                p.userInteractionEnabled, p.clipsToBounds];
        }
        UIWindow *win = g.window;
        [o appendFormat:@"-- window: %@ level=%.1f scene=%@ frame=%@ interaction=%d --\n",
            NSStringFromClass(win.class), win.windowLevel,
            NSStringFromClass(win.windowScene.class),
            NSStringFromCGRect(win.frame), win.userInteractionEnabled];
        for (UIView *sib in g.superview.subviews) {
            if ([NSStringFromClass(sib.class) isEqualToString:@"LBCatcherView"]) {
                [o appendFormat:@"-- gesture catcher: frame=%@ interaction=%d "
                    "recognizers=%lu --\n", NSStringFromCGRect(sib.frame),
                    sib.userInteractionEnabled,
                    (unsigned long)sib.gestureRecognizers.count];
            }
        }
        [o appendString:@"\n"];
    }

    [o appendString:@"== Action selector availability ==\n"];
    [o appendString:[LBActions availabilityReport]];

    [o appendString:@"\n== Matching private classes ==\n"];
    [o appendString:LBMatchingClasses()];

    [o appendString:@"\n\n== Recent events ==\n"];
    NSMutableArray *r = LBRing();
    @synchronized (r) { [o appendString:[r componentsJoinedByString:@"\n"]]; }
    [o appendString:@"\n"];
    return o;
}

void LBWriteReport(NSArray *grabbers) {
    NSString *text = LBBuildReport(grabbers);
    [NSFileManager.defaultManager
        createDirectoryAtPath:@"/var/mobile/Documents"
        withIntermediateDirectories:YES attributes:nil error:nil];
    NSError *err = nil;
    BOOL ok = [text writeToFile:LB_REPORT_PATH atomically:YES
                       encoding:NSUTF8StringEncoding error:&err];
    LBNote(@"report %@ (%@)", ok ? @"written" : @"FAILED",
           ok ? LB_REPORT_PATH : err.localizedDescription);
}
