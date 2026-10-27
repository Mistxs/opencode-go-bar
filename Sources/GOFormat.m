#import "GOFormat.h"

static NSDateFormatter *GOFormatter(NSString *format) {
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"ru_RU"];
    formatter.dateFormat = format;
    return formatter;
}

@implementation GOFormat

+ (NSString *)usd:(double)value {
    return [NSString stringWithFormat:@"$%.2f", value];
}

+ (NSString *)percent:(double)fraction {
    double clamped = MIN(1, MAX(0, fraction));
    return [NSString stringWithFormat:@"%ld%%", (long)llround(clamped * 100)];
}

+ (NSString *)bar:(double)fraction {
    return [self bar:fraction width:10];
}

+ (NSString *)bar:(double)fraction width:(NSInteger)width {
    double clamped = MIN(1, MAX(0, fraction));
    NSInteger filled = (NSInteger)llround(clamped * (double)width);
    filled = MAX(0, MIN(width, filled));
    NSString *full = [@"" stringByPaddingToLength:(NSUInteger)filled withString:@"█" startingAtIndex:0];
    NSString *empty = [@"" stringByPaddingToLength:(NSUInteger)(width - filled) withString:@"░" startingAtIndex:0];
    return [full stringByAppendingString:empty];
}

+ (NSString *)resetSuffix:(GOMeter *)meter {
    if (!meter.resetsAt) return @"";
    NSDateFormatter *formatter;
    switch (meter.kind) {
        case GOWindowKindFiveHour:
            formatter = GOFormatter(@"HH:mm");
            break;
        case GOWindowKindWeek:
            formatter = GOFormatter(@"EEE HH:mm");
            break;
        case GOWindowKindMonth:
            formatter = GOFormatter(@"d MMM");
            break;
    }
    NSString *value = [formatter stringFromDate:meter.resetsAt];
    if (meter.kind == GOWindowKindWeek) value = [value lowercaseString];
    return [NSString stringWithFormat:@"↻ %@", value];
}

+ (NSString *)resetDescription:(GOMeter *)meter {
    if (!meter.resetsAt) return @"сброс неизвестен";
    NSDateFormatter *formatter;
    NSString *prefix;
    switch (meter.kind) {
        case GOWindowKindFiveHour:
            formatter = GOFormatter(@"HH:mm");
            prefix = @"сброс в";
            break;
        case GOWindowKindWeek:
            formatter = GOFormatter(@"EEE HH:mm");
            prefix = @"сброс";
            break;
        case GOWindowKindMonth:
            formatter = GOFormatter(@"d MMM");
            prefix = @"сброс";
            break;
    }
    NSString *value = [formatter stringFromDate:meter.resetsAt];
    if (meter.kind == GOWindowKindWeek) value = [value lowercaseString];
    return [NSString stringWithFormat:@"%@ %@", prefix, value];
}

+ (NSString *)subscriptionEnd:(NSDate *)date {
    if (!date) return @"";
    return [NSString stringWithFormat:@"до %@", [GOFormatter(@"d MMMM") stringFromDate:date]];
}

+ (NSString *)updated:(NSDate *)date {
    if (!date) return @"ещё не обновлялось";
    return [NSString stringWithFormat:@"обновлено в %@", [GOFormatter(@"HH:mm:ss") stringFromDate:date]];
}

+ (NSString *)pad:(NSString *)value width:(NSInteger)width {
    NSUInteger length = value.length;
    if (length >= (NSUInteger)width) return value;
    return [value stringByPaddingToLength:(NSUInteger)width withString:@" " startingAtIndex:0];
}

@end
