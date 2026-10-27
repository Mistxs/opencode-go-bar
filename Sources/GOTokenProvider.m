#import "GOTokenProvider.h"
#import "GOHttp.h"
#import <sqlite3.h>

static NSError *GOError(NSString *message) {
    return [NSError errorWithDomain:@"dev.opencode.gobar"
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

static NSDictionary *_Nullable GOJSONObject(NSData *data) {
    if (!data) return nil;
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    return [object isKindOfClass:[NSDictionary class]] ? (NSDictionary *)object : nil;
}

@implementation GOToken
@end

@interface GOTokenProvider ()
+ (NSDictionary *)serviceInfo;
+ (GOToken *)tokenFromService;
+ (NSDictionary *)preferredCredentialIn:(NSArray *)credentials;
+ (GOToken *)tokenFromDatabase;
@end

@implementation GOTokenProvider

+ (GOToken *)accessTokenWithError:(NSError **)error {
    GOToken *token = [self tokenFromService];
    if (token) return token;

    token = [self tokenFromDatabase];
    if (token) return token;

    if (error) *error = GOError(@"OpenCode не запущен и сохранённый токен не найден");
    return nil;
}

// MARK: - Локальный сервис OpenCode

+ (NSDictionary *)serviceInfo {
    NSString *home = NSHomeDirectory();
    NSArray<NSString *> *paths = @[
        [home stringByAppendingPathComponent:@".local/state/opencode/service.json"],
        [home stringByAppendingPathComponent:@".config/opencode/service.json"]
    ];

    for (NSString *path in paths) {
        NSDictionary *info = GOJSONObject([NSData dataWithContentsOfFile:path]);
        NSString *url = [info[@"url"] isKindOfClass:[NSString class]] ? info[@"url"] : nil;
        if (url.length > 0) return info;
    }
    return nil;
}

+ (GOToken *)tokenFromService {
    NSDictionary *service = [self serviceInfo];
    if (!service) return nil;

    NSString *baseURL = service[@"url"];
    NSString *password = [service[@"password"] isKindOfClass:[NSString class]] ? service[@"password"] : @"";
    NSURL *url = [NSURL URLWithString:[baseURL stringByAppendingString:@"/api/credential"]];
    if (!url) return nil;

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"GET";
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    NSString *raw = [NSString stringWithFormat:@"opencode:%@", password];
    NSString *encoded = [[raw dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
    [request setValue:[@"Basic " stringByAppendingString:encoded] forHTTPHeaderField:@"Authorization"];

    NSHTTPURLResponse *response = nil;
    NSData *data = GOSyncGet(request, 1.5, &response, NULL);
    if (!data || response.statusCode != 200) return nil;

    NSDictionary *envelope = GOJSONObject(data);
    NSArray *credentials = [envelope[@"data"] isKindOfClass:[NSArray class]] ? envelope[@"data"] : nil;
    NSDictionary *credential = [self preferredCredentialIn:credentials];
    if (!credential) return nil;

    NSDictionary *value = [credential[@"value"] isKindOfClass:[NSDictionary class]] ? credential[@"value"] : nil;
    NSString *access = [value[@"access"] isKindOfClass:[NSString class]] ? value[@"access"] : nil;
    if (access.length == 0) return nil;

    GOToken *token = [GOToken new];
    token.token = access;
    token.source = @"OpenCode service";

    id expires = value[@"expires"];
    if ([expires isKindOfClass:[NSNumber class]]) {
        token.expiresAt = [NSDate dateWithTimeIntervalSince1970:[(NSNumber *)expires doubleValue] / 1000.0];
    }
    return token;
}

+ (NSDictionary *)preferredCredentialIn:(NSArray *)credentials {
    NSDictionary *fallback = nil;
    for (NSDictionary *credential in credentials) {
        if (![credential isKindOfClass:[NSDictionary class]]) continue;
        if (![credential[@"integrationID"] isEqual:@"opencode"]) continue;

        id active = credential[@"active"];
        BOOL isActive = (active == nil || active == [NSNull null] || [active boolValue]);
        if (isActive) return credential;
        if (!fallback) fallback = credential;
    }
    return fallback;
}

// MARK: - База OpenCode (fallback)

+ (GOToken *)tokenFromDatabase {
    NSString *home = NSHomeDirectory();
    NSString *path = [home stringByAppendingPathComponent:@".local/share/opencode/opencode.db"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return nil;

    sqlite3 *database = NULL;
    if (sqlite3_open_v2(path.fileSystemRepresentation, &database, SQLITE_OPEN_READONLY, NULL) != SQLITE_OK) {
        if (database) sqlite3_close(database);
        return nil;
    }

    GOToken *token = nil;
    const char *sql = "SELECT value FROM credential "
                      "WHERE integration_id = 'opencode' AND active = 1 "
                      "ORDER BY time_updated DESC LIMIT 1";
    sqlite3_stmt *statement = NULL;

    if (sqlite3_prepare_v2(database, sql, -1, &statement, NULL) == SQLITE_OK &&
        sqlite3_step(statement) == SQLITE_ROW) {
        const unsigned char *text = sqlite3_column_text(statement, 0);
        if (text) {
            NSString *json = [NSString stringWithUTF8String:(const char *)text];
            NSDictionary *value = GOJSONObject([json dataUsingEncoding:NSUTF8StringEncoding]);
            NSString *access = [value[@"access"] isKindOfClass:[NSString class]] ? value[@"access"] : nil;
            if (access.length > 0) {
                token = [GOToken new];
                token.token = access;
                token.source = @"OpenCode database";

                id expires = value[@"expires"];
                if ([expires isKindOfClass:[NSNumber class]]) {
                    token.expiresAt = [NSDate dateWithTimeIntervalSince1970:[(NSNumber *)expires doubleValue] / 1000.0];
                }
            }
        }
    }

    if (statement) sqlite3_finalize(statement);
    sqlite3_close(database);
    return token;
}

@end
