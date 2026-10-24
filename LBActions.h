#import <Foundation/Foundation.h>

@interface LBActions : NSObject
// Identifiers: none, spotlight, screenshot, screenrecord, lock, darkmode,
// controlcenter
+ (void)perform:(NSString *)action;
+ (NSString *)availabilityReport;
@end
