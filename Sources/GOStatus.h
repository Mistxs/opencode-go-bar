#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, GOWindowKind) {
    GOWindowKindFiveHour = 0,
    GOWindowKindWeek,
    GOWindowKindMonth,
};

@interface GOMeter : NSObject
@property (nonatomic) GOWindowKind kind;
/// Лимит в долларах.
@property (nonatomic) double limit;
/// Израсходовано в долларах.
@property (nonatomic) double used;
@property (nonatomic, strong, nullable) NSDate *resetsAt;

@property (nonatomic, readonly) double remaining;
@property (nonatomic, readonly) double remainingFraction;

- (NSString *)kindTitle;
- (NSString *)shortTitle;
@end

@interface GOStatus : NSObject
@property (nonatomic, copy, nullable) NSString *product;
@property (nonatomic, copy, nullable) NSString *renewalProduct;
@property (nonatomic, strong, nullable) NSDate *subscriptionEndsAt;
@property (nonatomic, copy) NSArray<GOMeter *> *meters;

+ (nullable instancetype)statusWithDictionary:(NSDictionary *)dictionary;
- (NSString *)planTitle;
- (BOOL)isGoSubscription;
- (nullable GOMeter *)tightestMeter;
@end

NS_ASSUME_NONNULL_END
