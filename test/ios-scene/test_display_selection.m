/* Platform-boundary doubles. Scene callbacks and display functions are extracted
 * from production, so the cases also cover changes in the UIKit implementation. */
#import <Foundation/Foundation.h>
#include <assert.h>
#include <stdbool.h>
#include <stdio.h>
#define SDL_PLATFORM_TVOS 1
#define SDL_INIT_EVENTS 1
static NSString *const UIWindowSceneSessionRoleApplication = @"application";
#define UISceneActivationStateForegroundActive 0
#define UISceneActivationStateForegroundInactive 1
#define UISceneActivationStateUnattached 2
@interface UIScreen : NSObject
@property NSRect bounds;
+ (UIScreen *)mainScreen;
+ (NSArray *)screens;
@end
static UIScreen *internalScreen, *externalScreen;
@implementation UIScreen
+ (UIScreen *)mainScreen { return internalScreen; }
+ (NSArray *)screens { return @[internalScreen, externalScreen]; }
@end
@interface UISceneSession : NSObject
@property NSString *persistentIdentifier;
@property NSString *role;
@end
@implementation UISceneSession
@end
@interface UIScene : NSObject
@property NSInteger activationState;
@property UISceneSession *session;
@end
@implementation UIScene
@end
@interface UIWindowScene : UIScene
@property UIScreen *screen;
@property UIWindowScene *coordinateSpace;
@property NSRect bounds;
@property id delegate;
@end
@implementation UIWindowScene
@end
@interface UIApplication : NSObject
@property NSSet *connectedScenes;
+ (UIApplication *)sharedApplication;
@end
@implementation UIApplication
+ (UIApplication *)sharedApplication
{
    static UIApplication *app;
    if (!app) { app = [UIApplication new]; app.connectedScenes = [NSSet set]; }
    return app;
}
@end
@interface UIWindow : NSObject
@property UIWindowScene *windowScene;
@property UIScreen *screen;
@property NSRect frame;
@property BOOL visible;
- (void)makeKeyAndVisible;
@end
@implementation UIWindow
- (void)makeKeyAndVisible { self.visible = YES; }
@end
@interface UISceneConnectionOptions : NSObject
@property NSSet<NSUserActivity *> *userActivities;
@property NSSet *URLContexts;
@end
@implementation UISceneConnectionOptions
@end
@interface UIOpenURLContext : NSObject
@property NSURL *URL;
@end
@implementation UIOpenURLContext
@end
@interface SDL_DisplayWatch : NSObject
+ (void)start;
@end
@implementation SDL_DisplayWatch
+ (void)start {}
@end
@interface SDL_UIKitDisplayData : NSObject
@property UIScreen *uiscreen;
@end
@implementation SDL_UIKitDisplayData
@end
@interface SDL_UIKitWindowData : NSObject
@property UIWindow *uiwindow;
@end
@implementation SDL_UIKitWindowData
@end
typedef struct { void *internal; } SDL_VideoDisplay;
typedef struct SDL_Window { void *internal; struct SDL_Window *next; } SDL_Window;
typedef struct { SDL_Window *windows; } SDL_VideoDevice;
static SDL_VideoDevice videoDevice;
static SDL_VideoDevice *SDL_GetVideoDevice(void) { return &videoDevice; }
static SDL_VideoDisplay videoDisplay;
static SDL_Window *mouseFocus, *keyboardFocus;
static SDL_VideoDisplay *SDL_GetVideoDisplayForWindow(SDL_Window *window) { return &videoDisplay; }
static void SDL_SetMouseFocus(SDL_Window *window) { mouseFocus = window; }
static void SDL_SetKeyboardFocus(SDL_Window *window) { keyboardFocus = window; }
static NSMutableArray *displays;
static bool UIKit_AddDisplay(UIScreen *screen, bool sendEvent)
{
    [displays addObject:screen];
    return true;
}
static int mainReadyCount;
static void SDL_SetMainReady(void) { ++mainReadyCount; }
static BOOL eventsReady;
static int SDL_WasInit(int flags) { return eventsReady ? flags : 0; }
/* PRODUCTION_HELPERS */
/* PRODUCTION_ACTIVE_SCENE */
/* PRODUCTION_INIT_MODES */
/* PRODUCTION_SHOW_WINDOW */
@interface SDLUIKitSceneDelegate : NSObject {
    NSMutableArray<NSURL *> *launchURLs;
}
@property NSMutableArray<NSURL *> *deliveredURLs;
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options;
- (void)sceneDidDisconnect:(UIScene *)scene;
- (void)processLaunchURLs;
@end
@implementation SDLUIKitSceneDelegate
- (void)handleURL:(NSURL *)url { [self.deliveredURLs addObject:url]; }
- (void)performSelector:(SEL)selector withObject:(id)object afterDelay:(NSTimeInterval)delay
{
    if (selector == NSSelectorFromString(@"postFinishLaunch")) {
        assert(UIKit_InitModes(NULL));
    }
}
/* PRODUCTION_CONNECT */
/* PRODUCTION_DISCONNECT */
/* PRODUCTION_PROCESS_URLS */
@end
static UIWindowScene *Scene(UIScreen *screen, NSString *identifier)
{
    UIWindowScene *scene = [UIWindowScene new];
    scene.screen = screen;
    scene.coordinateSpace = scene;
    scene.bounds = screen.bounds;
    scene.activationState = UISceneActivationStateForegroundActive;
    scene.session = [UISceneSession new];
    scene.session.persistentIdentifier = identifier;
    scene.session.role = UIWindowSceneSessionRoleApplication;
    return scene;
}
static UISceneConnectionOptions *Options(void)
{
    UISceneConnectionOptions *options = [UISceneConnectionOptions new];
    options.userActivities = [NSSet set];
    options.URLContexts = [NSSet set];
    return options;
}
int main(int argc, char **argv)
{
    @autoreleasepool {
        NSString *test = @(argv[1]);
        internalScreen = [UIScreen new];
        internalScreen.bounds = NSMakeRect(0, 0, 768, 1024);
        externalScreen = [UIScreen new];
        externalScreen.bounds = NSMakeRect(0, 0, 1920, 1080);
        displays = [NSMutableArray new];
        if ([test isEqualToString:@"legacy"]) {
            assert(UIKit_InitModes(NULL));
            assert(displays.count == 2 && displays[0] == internalScreen);
        } else {
            SDLUIKitSceneDelegate *delegate = [SDLUIKitSceneDelegate new];
            delegate.deliveredURLs = [NSMutableArray new];
            UIScreen *screen = [test isEqualToString:@"internal"] ? internalScreen : externalScreen;
            UIWindowScene *scene = Scene(screen, @"initial");
            // willConnect may run before UIKit publishes the connecting scene.
            [delegate scene:scene willConnectToSession:scene.session options:Options()];
            assert(mainReadyCount == 1);
            assert(displays.count == 2 && displays[0] == screen);
            assert(displays[0] != displays[1]);
            assert(UIKit_GetActiveWindowScene() == scene);
            SDL_UIKitDisplayData *displayData = [SDL_UIKitDisplayData new];
            displayData.uiscreen = screen;
            videoDisplay.internal = (__bridge void *)displayData;
            SDL_UIKitWindowData *windowData = [SDL_UIKitWindowData new];
            windowData.uiwindow = [UIWindow new];
            windowData.uiwindow.screen = screen;
            SDL_Window window = { (__bridge void *)windowData, NULL };
            videoDevice.windows = &window;
            UIKit_ShowWindow(NULL, &window);
            assert(mouseFocus == &window && keyboardFocus == &window);
            assert(windowData.uiwindow.visible);
            if ([test isEqualToString:@"secondary"]) {
                UIWindowScene *secondary = Scene(internalScreen, @"secondary");
                [delegate scene:secondary willConnectToSession:secondary.session options:Options()];
                assert(UIKit_GetApplicationWindowScene() == scene);
                [delegate sceneDidDisconnect:secondary];
                assert(UIKit_GetApplicationWindowScene() == scene);
                secondary.session.role = @"external-display";
                [delegate scene:secondary willConnectToSession:secondary.session options:Options()];
                assert(UIKit_GetApplicationWindowScene() == scene);
                assert(mainReadyCount == 1);
            } else if ([test hasSuffix:@"session"] || [test isEqualToString:@"reconnect-activity"]) {
                BOOL unattachedSession = [test isEqualToString:@"unattached-session"];
                BOOL replacementSession = [test isEqualToString:@"replacement-session"] || unattachedSession;
                UIWindowScene *replacement = Scene(screen, replacementSession ? @"replacement" : @"initial");
                UIApplication.sharedApplication.connectedScenes = [NSSet setWithObject:scene];
                if (replacementSession) {
                    if (unattachedSession) {
                        scene.activationState = UISceneActivationStateUnattached;
                    } else {
                        [delegate sceneDidDisconnect:scene];
                    }
                }
                UISceneConnectionOptions *options = Options();
                NSURL *activityURL = [NSURL URLWithString:@"https://example.org/reconnect"];
                NSURL *contextURL = [NSURL URLWithString:@"sdl-scene-smoke://reconnect"];
                NSUserActivity *activity = [[NSUserActivity alloc] initWithActivityType:NSUserActivityTypeBrowsingWeb];
                activity.webpageURL = activityURL;
                options.userActivities = [NSSet setWithObject:activity];
                UIOpenURLContext *context = [UIOpenURLContext new];
                context.URL = contextURL;
                options.URLContexts = [NSSet setWithObject:context];
                SDLUIKitSceneDelegate *reconnectDelegate = delegate;
                if (replacementSession) {
                    reconnectDelegate = [SDLUIKitSceneDelegate new];
                    reconnectDelegate.deliveredURLs = [NSMutableArray new];
                }
                [reconnectDelegate scene:replacement willConnectToSession:replacement.session options:options];
                assert(mainReadyCount == 1);
                [delegate sceneDidDisconnect:scene]; // A late old callback must not clear its replacement.
                assert(windowData.uiwindow.windowScene == replacement && windowData.uiwindow.visible);
                assert(NSEqualRects(windowData.uiwindow.frame, replacement.bounds));
                assert(UIKit_GetActiveWindowScene() == replacement);
                [reconnectDelegate processLaunchURLs];
                assert(reconnectDelegate.deliveredURLs.count == 0);
                eventsReady = YES;
                [reconnectDelegate processLaunchURLs];
                assert(reconnectDelegate.deliveredURLs.count == 2);
                assert([reconnectDelegate.deliveredURLs containsObject:contextURL]);
                assert([reconnectDelegate.deliveredURLs containsObject:activityURL]);
                [reconnectDelegate processLaunchURLs];
                assert(reconnectDelegate.deliveredURLs.count == 2);
            }
        }
        printf("PASS %s\n", argv[1]);
    }
    return 0;
}
