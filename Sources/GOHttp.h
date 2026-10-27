#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Синхронный GET: приложению нужны всего два запроса, состояние ради них не нужно.
NSData *_Nullable GOSyncGet(NSURLRequest *request,
                            NSTimeInterval timeout,
                            NSHTTPURLResponse *_Nullable *_Nullable outResponse,
                            NSError *_Nullable *_Nullable outError);

NS_ASSUME_NONNULL_END
