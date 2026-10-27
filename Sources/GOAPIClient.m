#import "GOAPIClient.h"
#import "GOHttp.h"

static NSError *GOAPIError(NSString *message) {
    return [NSError errorWithDomain:@"dev.opencode.gobar.api"
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

@implementation GOAPIClient

+ (GOStatus *)fetchWithToken:(NSString *)token error:(NSError **)error {
    // Внутренний endpoint веб-консоли OpenCode (console.opencode.ai).
    // Публичной документации нет; при изменениях смотреть сетевые запросы консоли.
    NSURL *url = [NSURL URLWithString:@"https://console.opencode.ai/api/go/status"];
    if (!url) {
        if (error) *error = GOAPIError(@"Некорректный адрес Console API");
        return nil;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"GET";
    [request setValue:[@"Bearer " stringByAppendingString:token] forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"OpenCodeGoBar/1.0 (macOS)" forHTTPHeaderField:@"User-Agent"];

    NSHTTPURLResponse *response = nil;
    NSError *transportError = nil;
    NSData *data = GOSyncGet(request, 10.0, &response, &transportError);
    if (!data) {
        NSString *reason = transportError.localizedDescription ?: @"неизвестная ошибка";
        if (error) *error = GOAPIError([NSString stringWithFormat:@"Нет связи с Console API: %@", reason]);
        return nil;
    }

    NSInteger statusCode = response.statusCode;
    if (statusCode == 401 || statusCode == 403) {
        if (error) *error = GOAPIError(@"Токен не принят. Войдите в OpenCode заново");
        return nil;
    }
    if (statusCode == 404) {
        if (error) *error = GOAPIError(@"Подписка OpenCode Go не найдена");
        return nil;
    }
    if (statusCode != 200) {
        if (error) *error = GOAPIError([NSString stringWithFormat:@"Console API вернул HTTP %ld", (long)statusCode]);
        return nil;
    }
    if (data.length == 0) {
        if (error) *error = GOAPIError(@"Console API вернул пустой ответ");
        return nil;
    }

    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    if (![object isKindOfClass:[NSDictionary class]]) {
        if (error) *error = GOAPIError(@"Не удалось разобрать ответ Console API");
        return nil;
    }

    return [GOStatus statusWithDictionary:(NSDictionary *)object];
}

@end
