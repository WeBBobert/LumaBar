#import "LBActions.h"
#import "LBDebug.h"
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

// Every target below is a private SpringBoard/UIKit API, and names move
// between iOS releases. Each action has an ordered candidate list; the first
// candidate whose class and selector exist is invoked. Missing candidates are
// silent no-ops (never crashes). The debug report lists which ones exist on
// the device so the table can be corrected from real data.

typedef struct { const char *cls; const char *sel; long arg; } LBCandidate;
typedef struct { const char *name; const LBCandidate *list; size_t count; } LBDef;

#define LBN(a) (sizeof(a) / sizeof((a)[0]))

static const LBCandidate kLock[] = {
    {"UIApplication", "_simulateLockButtonPress", 0},
    {"SBLockScreenManager", "lockUIFromSource:withOptions:", 1},
};
static const LBCandidate kScreenshot[] = {
    {"SBScreenshotManager", "saveScreenshots", 0},
    {"SBScreenshotManager", "saveScreenshotsWithCompletion:", 0},
};
static const LBCandidate kControlCenter[] = {
    {"SBControlCenterController", "presentAnimated:", 0},
    {"SBControlCenterController", "presentAnimated:completion:", 0},
};
static const LBCandidate kDark[] = {
    {"UIUserInterfaceStyleArbiter", "toggleCurrentStyle", 0},
};
static const LBCandidate kSpotlight[] = {
    {"SBIconController", "presentSpotlightAnimated:", 0},
    {"SBIconController", "presentSpotlight", 0},
};

static const LBDef kDefs[] = {
    {"lock", kLock, LBN(kLock)},
    {"screenshot", kScreenshot, LBN(kScreenshot)},
    {"controlcenter", kControlCenter, LBN(kControlCenter)},
    {"darkmode", kDark, LBN(kDark)},
    {"spotlight", kSpotlight, LBN(kSpotlight)},
};

static id LBTarget(const char *cls) {
    if (strcmp(cls, "UIApplication") == 0) return UIApplication.sharedApplication;
    Class c = NSClassFromString([NSString stringWithUTF8String:cls]);
    if (!c) return nil;
    for (NSString *s in @[@"sharedInstance", @"sharedManager"]) {
        SEL sel = NSSelectorFromString(s);
        if ([c respondsToSelector:sel])
            return ((id (*)(id, SEL))objc_msgSend)(c, sel);
    }
    return nil;
}

static BOOL LBInvoke(id obj, NSString *name, long intArg) {
    SEL s = NSSelectorFromString(name);
    if (!obj || ![obj respondsToSelector:s]) return NO;
    NSMethodSignature *sig = [obj methodSignatureForSelector:s];
    if (!sig) return NO;
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.target = obj;
    inv.selector = s;
    for (NSUInteger i = 2; i < sig.numberOfArguments; i++) {
        const char *t = [sig getArgumentTypeAtIndex:i];
        if (t[0] == 'B' || t[0] == 'c') {
            BOOL y = YES;
            [inv setArgument:&y atIndex:i];
        } else if (t[0] == '@' || t[0] == '^') {
            id n = nil;
            [inv setArgument:&n atIndex:i];
        } else if (strchr("qQiIlLsS", t[0])) {
            long v = intArg;
            [inv setArgument:&v atIndex:i];
        } else {
            return NO; // unsupported argument type
        }
    }
    [inv invoke];
    return YES;
}

static BOOL LBDarkFallback(void) {
    id arb = LBTarget("UIUserInterfaceStyleArbiter");
    SEL get = NSSelectorFromString(@"currentStyle");
    SEL set = NSSelectorFromString(@"setCurrentStyle:");
    if (![arb respondsToSelector:get] || ![arb respondsToSelector:set]) return NO;
    NSInteger cur = ((NSInteger (*)(id, SEL))objc_msgSend)(arb, get);
    ((void (*)(id, SEL, NSInteger))objc_msgSend)(arb, set, cur == 2 ? 1 : 2);
    return YES;
}

@implementation LBActions

+ (void)perform:(NSString *)action {
    if (!action.length || [action isEqualToString:@"none"]) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([action isEqualToString:@"screenrecord"]) {
            // Not implemented: look at the debug report's "ScreenRecord"
            // class matches to find the Control Center recording module.
            LBNote(@"action screenrecord: not implemented");
            return;
        }
        for (size_t d = 0; d < LBN(kDefs); d++) {
            if (strcmp(kDefs[d].name, action.UTF8String) != 0) continue;
            for (size_t i = 0; i < kDefs[d].count; i++) {
                const LBCandidate *c = &kDefs[d].list[i];
                id t = LBTarget(c->cls);
                if (LBInvoke(t, [NSString stringWithUTF8String:c->sel], c->arg)) {
                    LBNote(@"action %@: invoked %s %s", action, c->cls, c->sel);
                    return;
                }
            }
            if ([action isEqualToString:@"darkmode"] && LBDarkFallback()) {
                LBNote(@"action darkmode: used get/set fallback");
                return;
            }
            LBNote(@"action %@: no candidate responded", action);
            return;
        }
    });
}

+ (NSString *)availabilityReport {
    NSMutableString *o = [NSMutableString string];
    for (size_t d = 0; d < LBN(kDefs); d++) {
        [o appendFormat:@"[%s]\n", kDefs[d].name];
        for (size_t i = 0; i < kDefs[d].count; i++) {
            const LBCandidate *c = &kDefs[d].list[i];
            Class cls = NSClassFromString([NSString stringWithUTF8String:c->cls]);
            id t = LBTarget(c->cls);
            BOOL resp = t && [t respondsToSelector:
                NSSelectorFromString([NSString stringWithUTF8String:c->sel])];
            [o appendFormat:@"  %s %s  class=%d instance=%d responds=%d\n",
                c->cls, c->sel, cls != nil, t != nil, resp];
        }
    }
    [o appendString:@"[screenrecord]\n  not implemented\n"];
    return o;
}
@end
