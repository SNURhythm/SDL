/* Platform-boundary doubles for test_display_selection.py. The scene helpers,
 * connection callback and display initialization are extracted from production. */
#import <Foundation/Foundation.h>
#include <assert.h>
#include <stdio.h>
#define SDL_UIKIT_SCENE_LIFECYCLE 1
#undef TARGET_OS_TV
#define TARGET_OS_TV 1
#define _THIS void *unused
#define SDL_FALSE 0
static BOOL usesScenes;
@interface SceneTestBundle : NSObject
+ (SceneTestBundle *)mainBundle;
- (id)objectForInfoDictionaryKey:(NSString *)key;
@end
#define NSBundle SceneTestBundle
@implementation SceneTestBundle
+ (SceneTestBundle *)mainBundle { return [SceneTestBundle new]; }
- (id)objectForInfoDictionaryKey:(NSString *)key { return usesScenes ? @{} : nil; }
@end
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
#define UISceneActivationStateForegroundActive 0
@interface UIScene : NSObject
@property NSInteger activationState;
@end
@implementation UIScene
@end
@interface UIWindowScene : UIScene
@property UIScreen *screen;
@property UIWindowScene *coordinateSpace;
@property NSRect bounds;
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
@property NSRect frame;
@property BOOL visible;
- (void)makeKeyAndVisible;
@end
@implementation UIWindow
- (void)makeKeyAndVisible { self.visible = YES; }
@end
@interface SDL_DisplayWatch : NSObject
+ (void)start;
@end
@implementation SDL_DisplayWatch
+ (void)start {}
@end
static NSMutableArray *displays;
static int UIKit_AddDisplay(UIScreen *screen, int sendEvent)
{
    [displays addObject:screen];
    return 0;
}
/* PRODUCTION_HELPERS */
/* PRODUCTION_INIT_MODES */
@interface SDLUIKitDelegate : NSObject {
    BOOL applicationStarted;
}
@property UIWindow *window;
@property int starts;
@property int urlChecks;
- (BOOL)startApplication:(UIApplication *)app launchOptions:(NSDictionary *)options;
- (void)processLaunchURLs;
- (void)connectWindowScene:(UIWindowScene *)scene;
@end
@implementation SDLUIKitDelegate
- (BOOL)startApplication:(UIApplication *)app launchOptions:(NSDictionary *)options
{
    applicationStarted = YES;
    self.starts++;
    assert(UIKit_InitModes(NULL) == 0);
    return YES;
}
- (void)processLaunchURLs { self.urlChecks++; }
/* PRODUCTION_CONNECT */
@end
@interface SDL_DisplayData : NSObject
@property UIScreen *uiscreen;
@end
@implementation SDL_DisplayData
@end
@interface SDL_WindowData : NSObject
@property UIWindow *uiwindow;
@end
@implementation SDL_WindowData
@end
typedef struct { void *driverdata; } SDL_VideoDisplay;
typedef struct { void *driverdata; } SDL_Window;
static SDL_VideoDisplay videoDisplay;
static SDL_Window *mouseFocus, *keyboardFocus;
static SDL_VideoDisplay *SDL_GetDisplayForWindow(SDL_Window *window) { return &videoDisplay; }
static void SDL_SetMouseFocus(SDL_Window *window) { mouseFocus = window; }
static void SDL_SetKeyboardFocus(SDL_Window *window) { keyboardFocus = window; }
/* PRODUCTION_SHOW_WINDOW */
static UIWindowScene *Scene(UIScreen *screen)
{
    UIWindowScene *scene = [UIWindowScene new];
    scene.screen = screen;
    scene.coordinateSpace = scene;
    scene.bounds = screen.bounds;
    return scene;
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
        usesScenes = ![test isEqualToString:@"legacy"];
        if (!usesScenes) {
            assert(UIKit_InitModes(NULL) == 0);
            assert(displays.count == 2 && displays[0] == internalScreen);
        } else {
            SDLUIKitDelegate *delegate = [SDLUIKitDelegate new];
            UIScreen *screen = [test isEqualToString:@"internal"] ? internalScreen : externalScreen;
            UIWindowScene *scene = Scene(screen);
            // willConnect may run before UIKit publishes the connecting scene.
            [delegate connectWindowScene:scene];
            assert(delegate.starts == 1);
            assert(displays.count == 2 && displays[0] == screen);
            assert(displays[0] != displays[1]);
            assert(UIKit_GetWindowScene(screen) == scene);
            SDL_DisplayData *displayData = [SDL_DisplayData new];
            displayData.uiscreen = screen;
            videoDisplay.driverdata = (__bridge void *)displayData;
            SDL_WindowData *windowData = [SDL_WindowData new];
            windowData.uiwindow = [UIWindow new];
            SDL_Window window = { (__bridge void *)windowData };
            UIKit_ShowWindow(NULL, &window);
            assert(mouseFocus == &window && keyboardFocus == &window);
            assert(windowData.uiwindow.visible);
            if ([test isEqualToString:@"reconnect"]) {
                delegate.window = [UIWindow new];
                UIWindowScene *replacement = Scene(screen);
                UIApplication.sharedApplication.connectedScenes = [NSSet setWithObject:scene];
                [delegate connectWindowScene:replacement];
                assert(delegate.starts == 1 && delegate.urlChecks == 1);
                assert(delegate.window.windowScene == replacement && delegate.window.visible);
                assert(NSEqualRects(delegate.window.frame, replacement.bounds));
                assert(UIKit_GetWindowScene(screen) == replacement);
            }
        }
        printf("PASS %s\n", argv[1]);
    }
    return 0;
}
