#import "GOAppDelegate.h"
#import <ServiceManagement/ServiceManagement.h>

#import "GOAPIClient.h"
#import "GOFormat.h"
#import "GOMenuBarIcon.h"
#import "GOStatus.h"
#import "GOTokenProvider.h"

typedef NS_ENUM(NSInteger, GODisplayMode) {
    GODisplayModeBars = 0,
    GODisplayModePercent,
    GODisplayModeDollars,
};

static NSString *const GODefaultsMode = @"displayMode";
static NSString *const GODefaultsInterval = @"refreshInterval";

@implementation GOAppDelegate {
    NSStatusItem *_statusItem;
    NSTimer *_timer;
    GOStatus *_status;
    NSDate *_lastUpdated;
    NSString *_lastError;
    BOOL _refreshing;
    BOOL _menuOpen;
    NSUserDefaults *_defaults;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    _defaults = [NSUserDefaults standardUserDefaults];

    _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    _statusItem.behavior = NSStatusItemBehaviorRemovalAllowed;

    [self rebuildMenu];
    [self updateButton];
    [self scheduleTimer];

    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                          selector:@selector(didWake:)
                                                              name:NSWorkspaceDidWakeNotification
                                                            object:nil];

    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf refreshForced:YES];
    });
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [_timer invalidate];
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
}

- (void)dumpMenuToStandardOutput {
    _defaults = [NSUserDefaults standardUserDefaults];
    _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];

    NSError *error = nil;
    GOToken *token = [GOTokenProvider accessTokenWithError:&error];
    _status = token ? [GOAPIClient fetchWithToken:token.token error:&error] : nil;
    _lastError = _status ? nil : (error.localizedDescription ?: @"нет данных");
    _lastUpdated = [NSDate date];

    [self updateButton];
    [self rebuildMenu];

    printf("menu bar title: %s\n",
           (_statusItem.button.attributedTitle.string ?: @"").UTF8String);
    printf("menu bar tooltip:\n%s\n\n",
           (_statusItem.button.toolTip ?: @"").UTF8String);

    for (NSMenuItem *item in _statusItem.menu.itemArray) {
        if (item.isSeparatorItem) {
            printf("---\n");
            continue;
        }
        NSString *title = item.attributedTitle.string ?: item.title;
        printf("%s%s%s\n",
               item.enabled ? "" : "[disabled] ",
               title.UTF8String,
               item.state == NSControlStateValueOn ? "  ✓" : "");
        if (item.submenu) {
            for (NSMenuItem *submenuItem in item.submenu.itemArray) {
                NSString *submenuTitle = submenuItem.attributedTitle.string ?: submenuItem.title;
                printf("    %s%s\n",
                       submenuItem.state == NSControlStateValueOn ? "✓ " : "",
                       submenuTitle.UTF8String);
            }
        }
    }
}

- (void)didWake:(NSNotification *)notification {
    [self refreshForced:YES];
}

// MARK: - Загрузка

- (void)refreshNow:(id)sender {
    [self refreshForced:YES];
}

- (void)refreshForced:(BOOL)force {
    if (_refreshing) return;
    if (!force && _lastUpdated && [[NSDate date] timeIntervalSinceDate:_lastUpdated] < 10) return;

    _refreshing = YES;
    [self updateButton];

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSError *error = nil;
        GOToken *token = [GOTokenProvider accessTokenWithError:&error];
        GOStatus *status = nil;
        if (token) {
            status = [GOAPIClient fetchWithToken:token.token error:&error];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf applyStatus:status error:error];
        });
    });
}

- (void)applyStatus:(GOStatus *)status error:(NSError *)error {
    _refreshing = NO;

    if (status) {
        _status = status;
        _lastUpdated = [NSDate date];
        _lastError = status.meters.count == 0 ? @"В ответе нет лимитов Go" : nil;
    } else {
        _lastError = error.localizedDescription ?: @"Неизвестная ошибка";
    }

    [self updateButton];
    if (!_menuOpen) [self rebuildMenu];
}

- (void)scheduleTimer {
    [_timer invalidate];
    NSTimeInterval interval = self.refreshInterval;
    __weak typeof(self) weakSelf = self;
    NSTimer *timer = [NSTimer timerWithTimeInterval:interval
                                            repeats:YES
                                              block:^(NSTimer * _Nonnull current) {
        [weakSelf refreshForced:NO];
    }];
    timer.tolerance = MIN(30, interval * 0.1);
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    _timer = timer;
}

// MARK: - Строка меню

- (void)updateButton {
    NSStatusBarButton *button = _statusItem.button;
    if (!button) return;

    if (_status.meters.count > 0) {
        GODisplayMode mode = self.displayMode;
        switch (mode) {
            case GODisplayModeBars:
                button.image = [GOMenuBarIcon imageWithMeters:_status.meters error:_lastError != nil];
                button.imagePosition = NSImageOnly;
                button.attributedTitle = [[NSAttributedString alloc] initWithString:@""];
                break;
            case GODisplayModePercent: {
                GOMeter *tightest = [_status tightestMeter];
                double fraction = tightest ? tightest.remainingFraction : 0;
                button.image = nil;
                button.imagePosition = NSNoImage;
                button.attributedTitle = [self textTitle:[GOFormat percent:fraction]
                                                   color:[GOMenuBarIcon colorForRemainingFraction:fraction]];
                break;
            }
            case GODisplayModeDollars: {
                GOMeter *tightest = [_status tightestMeter];
                double fraction = tightest ? tightest.remainingFraction : 0;
                double remaining = tightest ? tightest.remaining : 0;
                button.image = nil;
                button.imagePosition = NSNoImage;
                NSString *label = tightest ? [tightest shortTitle] : @"5ч";
                button.attributedTitle = [self textTitle:[NSString stringWithFormat:@"%@ %@", label, [GOFormat usd:remaining]]
                                                   color:[GOMenuBarIcon colorForRemainingFraction:fraction]];
                break;
            }
        }
        button.toolTip = [self tooltipText];
    } else if (_refreshing) {
        button.image = [GOMenuBarIcon imageWithMeters:nil error:NO];
        button.imagePosition = NSImageOnly;
        button.attributedTitle = [[NSAttributedString alloc] initWithString:@""];
        button.toolTip = @"Загружаю лимиты OpenCode Go…";
    } else {
        button.image = nil;
        button.imagePosition = NSNoImage;
        button.attributedTitle = [self textTitle:@"Go ?" color:[NSColor systemOrangeColor]];
        button.toolTip = _lastError ?: @"Нет данных о лимитах";
    }

    button.accessibilityLabel = button.toolTip ?: @"OpenCode Go";
}

- (NSAttributedString *)textTitle:(NSString *)text color:(NSColor *)color {
    return [[NSAttributedString alloc] initWithString:text attributes:@{
        NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: color,
        NSBaselineOffsetAttributeName: @1,
    }];
}

- (NSString *)tooltipText {
    if (!_status) return _lastError ?: @"OpenCode Go";

    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    [lines addObject:[NSString stringWithFormat:@"OpenCode Go · тариф %@", [_status planTitle]]];
    if (_lastError) {
        [lines addObject:[@"⚠︎ " stringByAppendingString:_lastError]];
    }
    for (GOMeter *meter in _status.meters) {
        [lines addObject:[NSString stringWithFormat:@"%@: %@ из %@ (%@), %@",
                          [meter shortTitle],
                          [GOFormat usd:meter.remaining],
                          [GOFormat usd:meter.limit],
                          [GOFormat percent:meter.remainingFraction],
                          [GOFormat resetDescription:meter]]];
    }
    [lines addObject:[GOFormat updated:_lastUpdated]];
    return [lines componentsJoinedByString:@"\n"];
}

// MARK: - Меню

- (void)rebuildMenu {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"OpenCode Go"];
    menu.autoenablesItems = NO;
    menu.delegate = self;

    [menu addItem:[self headerItem]];

    if (_status.isGoSubscription) {
        [menu addItem:[self planItem]];
    }

    [menu addItem:[NSMenuItem separatorItem]];

    if (_status.meters.count > 0) {
        for (GOMeter *meter in _status.meters) {
            [menu addItem:[self meterItem:meter]];
        }
    } else if (_refreshing) {
        [menu addItem:[self infoItem:@"Загружаю лимиты…"]];
    } else {
        [menu addItem:[self infoItem:@"Нет данных о лимитах"]];
    }

    if (_lastError.length > 0) {
        [menu addItem:[NSMenuItem separatorItem]];
        [menu addItem:[self errorItem:_lastError]];
    }

    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItem:[self infoItem:[GOFormat updated:_lastUpdated]]];

    NSMenuItem *refresh = [self actionItem:@"Обновить" action:@selector(refreshNow:) key:@"r"];
    refresh.image = [NSImage imageWithSystemSymbolName:@"arrow.clockwise" accessibilityDescription:nil];
    refresh.enabled = !_refreshing;
    [menu addItem:refresh];

    NSMenuItem *console = [self actionItem:@"Открыть консоль" action:@selector(openConsole:) key:@"o"];
    console.image = [NSImage imageWithSystemSymbolName:@"safari" accessibilityDescription:nil];
    [menu addItem:console];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *view = [[NSMenuItem alloc] initWithTitle:@"Вид" action:nil keyEquivalent:@""];
    view.image = [NSImage imageWithSystemSymbolName:@"chart.bar" accessibilityDescription:nil];
    view.submenu = [self viewMenu];
    [menu addItem:view];

    NSMenuItem *interval = [[NSMenuItem alloc] initWithTitle:@"Обновлять" action:nil keyEquivalent:@""];
    interval.image = [NSImage imageWithSystemSymbolName:@"clock" accessibilityDescription:nil];
    interval.submenu = [self intervalMenu];
    [menu addItem:interval];

    NSMenuItem *login = [self actionItem:@"Запускать при входе" action:@selector(toggleLaunchAtLogin:) key:@""];
    login.image = [NSImage imageWithSystemSymbolName:@"power" accessibilityDescription:nil];
    login.state = [self launchAtLoginEnabled] ? NSControlStateValueOn : NSControlStateValueOff;
    [menu addItem:login];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *quit = [self actionItem:@"Выйти" action:@selector(quit:) key:@"q"];
    quit.image = [NSImage imageWithSystemSymbolName:@"xmark.circle" accessibilityDescription:nil];
    [menu addItem:quit];

    _statusItem.menu = menu;
}

- (NSMenuItem *)headerItem {
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc]
        initWithString:@"OpenCode Go"
            attributes:@{
                NSFontAttributeName: [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold],
                NSForegroundColorAttributeName: [NSColor labelColor],
            }];

    if (_status.isGoSubscription) {
        [text appendAttributedString:[[NSAttributedString alloc]
            initWithString:[NSString stringWithFormat:@"  ·  %@", [_status planTitle]]
                attributes:@{
                    NSFontAttributeName: [NSFont systemFontOfSize:12 weight:NSFontWeightRegular],
                    NSForegroundColorAttributeName: [NSColor secondaryLabelColor],
                }]];
    }

    NSMenuItem *item = [[NSMenuItem alloc] init];
    item.attributedTitle = text;
    item.enabled = NO;
    return item;
}

- (NSMenuItem *)planItem {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];

    for (GOMeter *meter in _status.meters) {
        if (meter.kind == GOWindowKindMonth) {
            [parts addObject:[NSString stringWithFormat:@"лимит %@ / мес", [GOFormat usd:meter.limit]]];
            break;
        }
    }
    if (_status.subscriptionEndsAt) {
        [parts addObject:[GOFormat subscriptionEnd:_status.subscriptionEndsAt]];
    }
    return [self infoItem:[parts componentsJoinedByString:@"  ·  "]];
}

- (NSMenuItem *)meterItem:(GOMeter *)meter {
    NSFont *mono = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightMedium];
    NSFont *monoRegular = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
    NSMutableAttributedString *line = [[NSMutableAttributedString alloc] init];

    [line appendAttributedString:[[NSAttributedString alloc]
        initWithString:[GOFormat pad:[meter shortTitle] width:4]
            attributes:@{NSFontAttributeName: mono, NSForegroundColorAttributeName: [NSColor labelColor]}]];

    [line appendAttributedString:[[NSAttributedString alloc]
        initWithString:[GOFormat bar:meter.remainingFraction]
            attributes:@{
                NSFontAttributeName: monoRegular,
                NSForegroundColorAttributeName: [GOMenuBarIcon colorForRemainingFraction:meter.remainingFraction],
            }]];

    [line appendAttributedString:[[NSAttributedString alloc]
        initWithString:[NSString stringWithFormat:@"  %@", [GOFormat pad:[GOFormat percent:meter.remainingFraction] width:4]]
            attributes:@{NSFontAttributeName: mono, NSForegroundColorAttributeName: [NSColor labelColor]}]];

    [line appendAttributedString:[[NSAttributedString alloc]
        initWithString:[NSString stringWithFormat:@"  %@ / %@",
                        [GOFormat usd:meter.remaining],
                        [GOFormat usd:meter.limit]]
            attributes:@{NSFontAttributeName: monoRegular, NSForegroundColorAttributeName: [NSColor secondaryLabelColor]}]];

    NSString *reset = [GOFormat resetSuffix:meter];
    if (reset.length > 0) {
        [line appendAttributedString:[[NSAttributedString alloc]
            initWithString:[@"  " stringByAppendingString:reset]
                attributes:@{
                    NSFontAttributeName: [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular],
                    NSForegroundColorAttributeName: [NSColor tertiaryLabelColor],
                }]];
    }

    NSMenuItem *item = [[NSMenuItem alloc] init];
    item.attributedTitle = line;
    item.toolTip = [NSString stringWithFormat:@"%@: осталось %@ из %@ · %@",
                    [meter kindTitle],
                    [GOFormat usd:meter.remaining],
                    [GOFormat usd:meter.limit],
                    [GOFormat resetDescription:meter]];
    item.target = self;
    item.action = @selector(openConsole:);
    item.enabled = YES;
    return item;
}

- (NSMenuItem *)infoItem:(NSString *)text {
    NSMenuItem *item = [[NSMenuItem alloc] init];
    item.attributedTitle = [[NSAttributedString alloc]
        initWithString:text
            attributes:@{
                NSFontAttributeName: [NSFont systemFontOfSize:11 weight:NSFontWeightRegular],
                NSForegroundColorAttributeName: [NSColor secondaryLabelColor],
            }];
    item.enabled = NO;
    return item;
}

- (NSMenuItem *)errorItem:(NSString *)text {
    NSMenuItem *item = [[NSMenuItem alloc] init];
    item.attributedTitle = [[NSAttributedString alloc]
        initWithString:[@"⚠︎  " stringByAppendingString:text]
            attributes:@{
                NSFontAttributeName: [NSFont systemFontOfSize:11 weight:NSFontWeightMedium],
                NSForegroundColorAttributeName: [NSColor systemRedColor],
            }];
    item.enabled = NO;
    return item;
}

- (NSMenuItem *)actionItem:(NSString *)title action:(SEL)action key:(NSString *)key {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:key];
    item.target = self;
    item.enabled = YES;
    return item;
}

- (NSMenu *)viewMenu {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Вид"];
    menu.autoenablesItems = NO;
    NSArray<NSString *> *titles = @[@"Три полоски", @"Процент", @"Оставшиеся доллары"];
    GODisplayMode current = self.displayMode;

    for (NSInteger mode = 0; mode < (NSInteger)titles.count; mode++) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:titles[(NSUInteger)mode]
                                                      action:@selector(selectMode:)
                                               keyEquivalent:@""];
        item.target = self;
        item.representedObject = @(mode);
        item.state = current == (GODisplayMode)mode ? NSControlStateValueOn : NSControlStateValueOff;
        item.enabled = YES;
        [menu addItem:item];
    }
    return menu;
}

- (NSMenu *)intervalMenu {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Обновлять"];
    menu.autoenablesItems = NO;
    NSArray<NSString *> *titles = @[@"1 минуту", @"5 минут", @"15 минут"];
    NSArray<NSNumber *> *values = @[@60, @300, @900];
    NSTimeInterval current = self.refreshInterval;

    for (NSInteger index = 0; index < (NSInteger)titles.count; index++) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:titles[(NSUInteger)index]
                                                      action:@selector(selectInterval:)
                                               keyEquivalent:@""];
        item.target = self;
        item.representedObject = values[(NSUInteger)index];
        item.state = fabs(current - values[(NSUInteger)index].doubleValue) < 1
            ? NSControlStateValueOn
            : NSControlStateValueOff;
        item.enabled = YES;
        [menu addItem:item];
    }
    return menu;
}

// MARK: - Настройки

- (GODisplayMode)displayMode {
    NSString *raw = [_defaults stringForKey:GODefaultsMode];
    if ([raw isEqualToString:@"percent"]) return GODisplayModePercent;
    if ([raw isEqualToString:@"dollars"]) return GODisplayModeDollars;
    return GODisplayModeBars;
}

- (void)setDisplayMode:(GODisplayMode)mode {
    NSString *raw = @"bars";
    if (mode == GODisplayModePercent) raw = @"percent";
    if (mode == GODisplayModeDollars) raw = @"dollars";
    [_defaults setObject:raw forKey:GODefaultsMode];
}

- (NSTimeInterval)refreshInterval {
    double value = [_defaults doubleForKey:GODefaultsInterval];
    return value > 0 ? value : 300;
}

- (void)setRefreshInterval:(NSTimeInterval)interval {
    [_defaults setDouble:interval forKey:GODefaultsInterval];
}

// MARK: - Действия

- (void)selectMode:(NSMenuItem *)sender {
    NSNumber *value = [sender.representedObject isKindOfClass:[NSNumber class]] ? sender.representedObject : nil;
    if (!value) return;
    [self setDisplayMode:(GODisplayMode)value.integerValue];
    [self updateButton];
    [self rebuildMenu];
}

- (void)selectInterval:(NSMenuItem *)sender {
    NSNumber *value = [sender.representedObject isKindOfClass:[NSNumber class]] ? sender.representedObject : nil;
    if (!value) return;
    [self setRefreshInterval:value.doubleValue];
    [self scheduleTimer];
    [self rebuildMenu];
}

- (void)openConsole:(id)sender {
    NSURL *url = [NSURL URLWithString:@"https://opencode.ai/console/go"];
    if (url) [[NSWorkspace sharedWorkspace] openURL:url];
}

- (void)quit:(id)sender {
    [NSApp terminate:nil];
}

- (BOOL)launchAtLoginEnabled {
    if (@available(macOS 13.0, *)) {
        return [SMAppService mainAppService].status == SMAppServiceStatusEnabled;
    }
    return NO;
}

- (void)toggleLaunchAtLogin:(id)sender {
    if (@available(macOS 13.0, *)) {
        NSError *error = nil;
        BOOL success;
        SMAppService *service = [SMAppService mainAppService];
        if (service.status == SMAppServiceStatusEnabled) {
            success = [service unregisterAndReturnError:&error];
        } else {
            success = [service registerAndReturnError:&error];
        }
        if (!success) {
            [self showAlertWithTitle:@"Не удалось изменить автозапуск"
                             message:[NSString stringWithFormat:@"%@\n\nСкопируйте приложение в ~/Applications или /Applications и попробуйте снова.",
                                      error.localizedDescription ?: @"Неизвестная ошибка"]];
        }
    } else {
        [self showAlertWithTitle:@"Не поддерживается" message:@"Для автозапуска нужна macOS 13 или новее."];
    }
    [self rebuildMenu];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    [NSApp activateIgnoringOtherApps:YES];
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = title;
    alert.informativeText = message;
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:@"Ок"];
    [alert runModal];
}

// MARK: - NSMenuDelegate

- (void)menuWillOpen:(NSMenu *)menu {
    _menuOpen = YES;
    if (!_lastUpdated || [[NSDate date] timeIntervalSinceDate:_lastUpdated] > 120) {
        [self refreshForced:NO];
    }
}

- (void)menuDidClose:(NSMenu *)menu {
    _menuOpen = NO;
    [self rebuildMenu];
}

@end
