#import "GOMenuBarIcon.h"
#import "GOStatus.h"

@implementation GOMenuBarIcon

+ (NSColor *)colorForRemainingFraction:(double)fraction {
    if (fraction <= 0.2) return [NSColor systemRedColor];
    if (fraction <= 0.5) return [NSColor systemOrangeColor];
    return [NSColor systemGreenColor];
}

+ (NSImage *)imageWithMeters:(NSArray<GOMeter *> *)meters error:(BOOL)hasError {
    NSSize size = NSMakeSize(23, 18);
    NSImage *image = [NSImage imageWithSize:size
                                    flipped:NO
                             drawingHandler:^BOOL(NSRect destinationRect) {
        CGFloat barWidth = 5;
        CGFloat gap = 3;
        CGFloat height = 14;
        CGFloat totalWidth = barWidth * 3 + gap * 2;
        CGFloat startX = (size.width - totalWidth) / 2;
        CGFloat startY = (size.height - height) / 2;

        for (NSInteger index = 0; index < 3; index++) {
            CGFloat x = startX + (CGFloat)index * (barWidth + gap);
            NSRect background = NSMakeRect(x, startY, barWidth, height);
            [[[NSColor labelColor] colorWithAlphaComponent:0.22] setFill];
            [[NSBezierPath bezierPathWithRoundedRect:background xRadius:1.5 yRadius:1.5] fill];

            if (!meters || index >= (NSInteger)meters.count) continue;
            GOMeter *meter = meters[(NSUInteger)index];
            double fraction = meter.remainingFraction;
            if (fraction <= 0.02) continue;

            CGFloat fillHeight = MAX(1.5, height * fraction);
            NSRect fill = NSMakeRect(x, startY, barWidth, fillHeight);
            [[self colorForRemainingFraction:fraction] setFill];
            [[NSBezierPath bezierPathWithRoundedRect:fill xRadius:1.5 yRadius:1.5] fill];
        }

        if (hasError) {
            NSRect dot = NSMakeRect(size.width - 4.5, size.height - 4.5, 4.5, 4.5);
            [[NSColor systemRedColor] setFill];
            [[NSBezierPath bezierPathWithOvalInRect:dot] fill];
        }
        return YES;
    }];

    image.template = NO;
    image.accessibilityDescription = @"Остаток лимитов OpenCode Go";
    return image;
}

@end
