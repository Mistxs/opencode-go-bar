#import "GOStatus.h"

static NSDictionary *_Nullable GODictionary(id _Nullable value) {
    return [value isKindOfClass:[NSDictionary class]] ? (NSDictionary *)value : nil;
}

static NSString *_Nullable GOString(id _Nullable value) {
    return [value isKindOfClass:[NSString class]] ? (NSString *)value : nil;
}

static double GODouble(id _Nullable value) {
    if ([value isKindOfClass:[NSString class]]) return [(NSString *)value doubleValue];
    if ([value isKindOfClass:[NSNumber class]]) return [(NSNumber *)value doubleValue];
    return 0;
}

static NSDate *_Nullable GOParseDate(NSString *_Nullable string) {
    if (string.length == 0) return nil;

    static NSISO8601DateFormatter *fractional;
    static NSISO8601DateFormatter *plain;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        fractional = [NSISO8601DateFormatter new];
        fractional.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
        plain = [NSISO8601DateFormatter new];
        plain.formatOptions = NSISO8601DateFormatWithInternetDateTime;
    });

    NSDate *date = [fractional dateFromString:string];
    if (date) return date;
    return [plain dateFromString:string];
}

@implementation GOMeter

- (double)remaining {
    return MAX(0, self.limit - self.used);
}

- (double)remainingFraction {
    if (self.limit <= 0) return 0;
    return MIN(1, MAX(0, self.remaining / self.limit));
}

- (NSString *)kindTitle {
    switch (self.kind) {
        case GOWindowKindFiveHour: return @"5 часов";
        case GOWindowKindWeek: return @"Неделя";
        case GOWindowKindMonth: return @"Месяц";
    }
    return @"";
}

- (NSString *)shortTitle {
    switch (self.kind) {
        case GOWindowKindFiveHour: return @"5ч";
        case GOWindowKindWeek: return @"Нед";
        case GOWindowKindMonth: return @"Мес";
    }
    return @"";
}

@end

@implementation GOStatus

+ (instancetype)statusWithDictionary:(NSDictionary *)dictionary {
    GOStatus *status = [GOStatus new];
    status.product = GOString(dictionary[@"product"]);
    status.renewalProduct = GOString(dictionary[@"renewalProduct"]);

    NSDictionary *access = GODictionary(dictionary[@"access"]);
    status.subscriptionEndsAt = GOParseDate(GOString(access[@"endsAt"]));

    NSDictionary *meters = GODictionary(access[@"meters"]);
    NSMutableArray<GOMeter *> *result = [NSMutableArray array];

    NSArray<NSNumber *> *kinds = @[@(GOWindowKindFiveHour), @(GOWindowKindWeek), @(GOWindowKindMonth)];
    NSArray<NSString *> *keys = @[@"fiveHour", @"week", @"month"];
    for (NSUInteger index = 0; index < keys.count; index++) {
        NSDictionary *raw = GODictionary(meters[keys[index]]);
        if (!raw) continue;

        GOMeter *meter = [GOMeter new];
        meter.kind = (GOWindowKind)kinds[index].integerValue;
        // В Console API суммы в «микроцентах»: 1e8 единиц = $1.
        meter.limit = GODouble(raw[@"limitMicroCents"]) / 100000000.0;
        meter.used = GODouble(raw[@"usedMicroCents"]) / 100000000.0;
        meter.resetsAt = GOParseDate(GOString(raw[@"resetsAt"]));
        [result addObject:meter];
    }
    status.meters = result;
    return status;
}

- (NSString *)planTitle {
    if ([self.product isEqualToString:@"go"]) return @"Go";
    if ([self.product isEqualToString:@"go-plus"]) return @"Go Plus";
    if (self.product.length > 0) {
        NSString *value = [self.product stringByReplacingOccurrencesOfString:@"-" withString:@" "];
        return [value capitalizedStringWithLocale:[NSLocale localeWithLocaleIdentifier:@"ru_RU"]];
    }
    return @"Go";
}

- (BOOL)isGoSubscription {
    return [self.product isEqualToString:@"go"] || [self.product isEqualToString:@"go-plus"];
}

- (GOMeter *)tightestMeter {
    GOMeter *best = nil;
    for (GOMeter *meter in self.meters) {
        if (!best || meter.remainingFraction < best.remainingFraction) {
            best = meter;
        }
    }
    return best;
}

@end
