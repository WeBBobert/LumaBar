#import <Preferences/PSListController.h>
#import <UIKit/UIKit.h>

#define LB_DOMAIN @"com.lumabar.tweak"
#define LB_NOTIFY "com.lumabar.tweak/prefsChanged"
#define LB_DUMP_NOTIFY "com.lumabar.tweak/dumpDebug"

@interface LBRootListController : PSListController
@end

@implementation LBRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)resetSettings {
    UIAlertController *a = [UIAlertController
        alertControllerWithTitle:@"Reset LumaBar?"
                         message:@"All settings return to their defaults."
                  preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                          style:UIAlertActionStyleCancel
                                        handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"Reset"
                                          style:UIAlertActionStyleDestructive
                                        handler:^(UIAlertAction *x) {
        NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:LB_DOMAIN];
        [d removePersistentDomainForName:LB_DOMAIN];
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFSTR(LB_NOTIFY), NULL, NULL, YES);
        [self reloadSpecifiers];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)writeDebugReport {
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR(LB_DUMP_NOTIFY), NULL, NULL, YES);
    UIAlertController *a = [UIAlertController
        alertControllerWithTitle:@"Debug report requested"
                         message:@"Written to\n/var/mobile/Documents/LumaBar-debug.txt\n"
                                  "Open it with Filza and send me the contents."
                  preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK"
                                          style:UIAlertActionStyleDefault
                                        handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
@end
