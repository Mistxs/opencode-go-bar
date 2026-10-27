#import <Foundation/Foundation.h>

#import "GOAPIClient.h"
#import "GOFormat.h"
#import "GOStatus.h"
#import "GOTokenProvider.h"

void GOProbeRun(void) {
    @autoreleasepool {
        NSError *error = nil;
        GOToken *token = [GOTokenProvider accessTokenWithError:&error];
        if (!token) {
            fprintf(stderr, "Ошибка: %s\n", (error.localizedDescription ?: @"нет токена").UTF8String);
            exit(1);
        }
        fprintf(stderr, "token source: %s\n", token.source.UTF8String);

        GOStatus *status = [GOAPIClient fetchWithToken:token.token error:&error];
        if (!status) {
            fprintf(stderr, "Ошибка: %s\n", (error.localizedDescription ?: @"нет данных").UTF8String);
            exit(1);
        }

        printf("OpenCode Go — тариф %s\n", status.planTitle.UTF8String);
        if (status.subscriptionEndsAt) {
            printf("Подписка %s\n", [GOFormat subscriptionEnd:status.subscriptionEndsAt].UTF8String);
        }
        for (GOMeter *meter in status.meters) {
            NSString *line = [NSString stringWithFormat:@"%@ %@ %@  %@ / %@  %@",
                              [GOFormat pad:[meter kindTitle] width:9],
                              [GOFormat bar:meter.remainingFraction],
                              [GOFormat pad:[GOFormat percent:meter.remainingFraction] width:4],
                              [GOFormat usd:meter.remaining],
                              [GOFormat usd:meter.limit],
                              [GOFormat resetDescription:meter]];
            printf("%s\n", line.UTF8String);
        }
        printf("%s\n", [GOFormat updated:[NSDate date]].UTF8String);
    }
}
