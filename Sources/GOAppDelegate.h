#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface GOAppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate>
/// Служебный режим: собрать меню и напечатать его содержимое (для отладки и тестов).
- (void)dumpMenuToStandardOutput;
@end

NS_ASSUME_NONNULL_END
