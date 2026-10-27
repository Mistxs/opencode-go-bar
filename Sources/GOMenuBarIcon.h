#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class GOMeter;

@interface GOMenuBarIcon : NSObject
+ (NSColor *)colorForRemainingFraction:(double)fraction;
+ (NSImage *)imageWithMeters:(nullable NSArray<GOMeter *> *)meters error:(BOOL)hasError;
@end

NS_ASSUME_NONNULL_END
