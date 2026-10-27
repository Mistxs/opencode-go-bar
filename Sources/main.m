#import <Cocoa/Cocoa.h>

#import "GOAppDelegate.h"

void GOProbeRun(void);
void GOPreviewRun(NSString *path);

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSArray<NSString *> *arguments = [[NSProcessInfo processInfo] arguments];

        if ([arguments containsObject:@"--probe"]) {
            GOProbeRun();
            return 0;
        }

        NSUInteger previewIndex = [arguments indexOfObject:@"--icon-preview"];
        if (previewIndex != NSNotFound && previewIndex + 1 < arguments.count) {
            GOPreviewRun(arguments[previewIndex + 1]);
            return 0;
        }

        if ([arguments containsObject:@"--dump-menu"]) {
            NSApplication *application = [NSApplication sharedApplication];
            (void)application;
            GOAppDelegate *delegate = [GOAppDelegate new];
            [delegate dumpMenuToStandardOutput];
            return 0;
        }

        NSApplication *application = [NSApplication sharedApplication];
        static GOAppDelegate *delegate;
        delegate = [GOAppDelegate new];
        application.delegate = delegate;
        [application setActivationPolicy:NSApplicationActivationPolicyAccessory];
        [application run];
        return 0;
    }
}
