#import <UIKit/UIKit.h>

#define LB_DUMP_NOTIFY "com.lumabar.tweak/dumpDebug"
#define LB_REPORT_PATH @"/var/mobile/Documents/LumaBar-debug.txt"

// Appends to an in-memory ring buffer (last 60 events) and NSLog.
void LBNote(NSString *fmt, ...) NS_FORMAT_FUNCTION(1, 2);

// Writes a diagnostic report (device/iOS info, grabber view hierarchy,
// window info, matching private classes, action selector availability,
// recent events) to LB_REPORT_PATH.
void LBWriteReport(NSArray *grabbers);
