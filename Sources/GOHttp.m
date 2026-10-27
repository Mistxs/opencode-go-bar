#import "GOHttp.h"

static NSError *GOHTTPError(NSString *message) {
    return [NSError errorWithDomain:@"dev.opencode.gobar.http"
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

NSData *GOSyncGet(NSURLRequest *request,
                  NSTimeInterval timeout,
                  NSHTTPURLResponse **outResponse,
                  NSError **outError) {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block NSData *result = nil;
    __block NSHTTPURLResponse *httpResponse = nil;
    __block NSError *transportError = nil;

    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    configuration.timeoutIntervalForRequest = timeout;
    configuration.timeoutIntervalForResource = timeout;
    configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];

    [[session dataTaskWithRequest:request
               completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        result = data;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            httpResponse = (NSHTTPURLResponse *)response;
        }
        transportError = error;
        dispatch_semaphore_signal(semaphore);
    }] resume];

    dispatch_time_t deadline = dispatch_time(DISPATCH_TIME_NOW, (int64_t)((timeout + 2.0) * NSEC_PER_SEC));
    long waitResult = dispatch_semaphore_wait(semaphore, deadline);
    [session invalidateAndCancel];

    if (waitResult != 0) {
        if (outError) *outError = GOHTTPError(@"Таймаут запроса");
        return nil;
    }
    if (outResponse) *outResponse = httpResponse;
    if (transportError) {
        if (outError) *outError = transportError;
        return nil;
    }
    return result;
}
