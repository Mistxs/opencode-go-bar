#import <Foundation/Foundation.h>
#import "GOStatus.h"

NS_ASSUME_NONNULL_BEGIN

@interface GOAPIClient : NSObject
+ (nullable GOStatus *)fetchWithToken:(NSString *)token error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
