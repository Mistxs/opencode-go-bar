#import <Cocoa/Cocoa.h>

#import "GOMenuBarIcon.h"
#import "GOStatus.h"

static GOMeter *GOPreviewMeter(GOWindowKind kind, double limit, double used) {
    GOMeter *meter = [GOMeter new];
    meter.kind = kind;
    meter.limit = limit;
    meter.used = used;
    return meter;
}

void GOPreviewRun(NSString *path) {
    @autoreleasepool {
        NSArray<GOMeter *> *meters = @[
            GOPreviewMeter(GOWindowKindFiveHour, 12, 3.3),
            GOPreviewMeter(GOWindowKindWeek, 30, 25.5),
            GOPreviewMeter(GOWindowKindMonth, 60, 16),
        ];

        NSImage *icon = [GOMenuBarIcon imageWithMeters:meters error:NO];
        CGFloat scale = 6;
        NSSize iconSize = NSMakeSize(icon.size.width * scale, icon.size.height * scale);
        CGFloat padding = 24;
        NSSize canvasSize = NSMakeSize(iconSize.width + padding * 2, iconSize.height * 2 + padding * 3);

        NSImage *canvas = [[NSImage alloc] initWithSize:canvasSize];
        [canvas lockFocus];

        [[NSColor colorWithWhite:0.13 alpha:1] setFill];
        NSRectFill(NSMakeRect(0, 0, canvasSize.width, canvasSize.height));
        [[NSColor colorWithWhite:0.96 alpha:1] setFill];
        NSRectFill(NSMakeRect(0, canvasSize.height / 2, canvasSize.width, canvasSize.height / 2));

        NSRect top = NSMakeRect(padding, canvasSize.height / 2 + padding, iconSize.width, iconSize.height);
        NSRect bottom = NSMakeRect(padding, padding, iconSize.width, iconSize.height);

        NSAppearance *light = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
        NSAppearance *dark = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
        [light performAsCurrentDrawingAppearance:^{
            [icon drawInRect:top];
        }];
        [dark performAsCurrentDrawingAppearance:^{
            [icon drawInRect:bottom];
        }];

        [canvas unlockFocus];

        NSBitmapImageRep *bitmap = [NSBitmapImageRep imageRepWithData:canvas.TIFFRepresentation];
        NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        if (![png writeToFile:path atomically:YES]) {
            fprintf(stderr, "Не удалось записать %s\n", path.UTF8String);
            exit(1);
        }
        printf("%s\n", path.UTF8String);
    }
}
