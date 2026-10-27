#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GOToken : NSObject
@property (nonatomic, copy) NSString *token;
@property (nonatomic, copy) NSString *source;
@property (nonatomic, strong, nullable) NSDate *expiresAt;
@end

@interface GOTokenProvider : NSObject
/// OAuth-токен аккаунта OpenCode из локального OpenCode.
+ (nullable GOToken *)accessTokenWithError:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
