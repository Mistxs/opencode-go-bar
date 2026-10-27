#import <Foundation/Foundation.h>
#import "GOStatus.h"

NS_ASSUME_NONNULL_BEGIN

@interface GOFormat : NSObject
+ (NSString *)usd:(double)value;
+ (NSString *)percent:(double)fraction;
+ (NSString *)bar:(double)fraction;
+ (NSString *)bar:(double)fraction width:(NSInteger)width;
+ (NSString *)resetSuffix:(GOMeter *)meter;
+ (NSString *)resetDescription:(GOMeter *)meter;
+ (NSString *)subscriptionEnd:(nullable NSDate *)date;
+ (NSString *)updated:(nullable NSDate *)date;
+ (NSString *)pad:(NSString *)value width:(NSInteger)width;
@end

NS_ASSUME_NONNULL_END
