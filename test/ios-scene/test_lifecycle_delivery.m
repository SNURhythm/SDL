/* Foundation notification delivery with production UIKit lifecycle callbacks. */
#import <Foundation/Foundation.h>
#include <assert.h>
#include <stdbool.h>
#include <stdio.h>
#define SDL_PLATFORM_TVOS 1
static NSString *const UIApplicationDidBecomeActiveNotification = @"application.active";
static NSString *const UIApplicationWillResignActiveNotification = @"application.inactive";
static NSString *const UIApplicationDidEnterBackgroundNotification = @"application.background";
static NSString *const UIApplicationWillEnterForegroundNotification = @"application.foreground";
static NSString *const UIApplicationWillTerminateNotification = @"application.terminate";
static NSString *const UIApplicationDidReceiveMemoryWarningNotification = @"application.memory";
@interface UIScene : NSObject
@end
@implementation UIScene
@end
@interface UIWindowScene : UIScene
@end
@implementation UIWindowScene
@end
static UIWindowScene *applicationWindowScene;
static BOOL applicationStarted;
static BOOL UIKit_EventPumpEnabled = YES;
static bool SDL_HasMainCallbacks(void) { return false; }
static void *SDL_GetWindows(int *count) { *count = 0; return NULL; }
#define SDL_free free
static int didForeground, willBackground, didBackground, willForeground;
static int termination, memoryWarning;
static void SDL_OnApplicationDidEnterForeground(void) { ++didForeground; }
static void SDL_OnApplicationWillEnterBackground(void) { ++willBackground; }
static void SDL_OnApplicationDidEnterBackground(void) { ++didBackground; }
static void SDL_OnApplicationWillEnterForeground(void) { ++willForeground; }
static void SDL_OnApplicationWillTerminate(void) { ++termination; }
static void SDL_OnApplicationDidReceiveMemoryWarning(void) { ++memoryWarning; }
/* PRODUCTION_SCENE_MODE */
@interface SDL_LifecycleObserver : NSObject
@property BOOL isObservingNotifications;
- (void)update;
@end
@implementation SDL_LifecycleObserver
/* PRODUCTION_OBSERVER */
@end
@interface SDLUIKitSceneDelegate : NSObject
- (void)sceneDidBecomeActive:(UIScene *)scene;
- (void)sceneWillResignActive:(UIScene *)scene;
- (void)sceneWillEnterForeground:(UIScene *)scene;
- (void)sceneDidEnterBackground:(UIScene *)scene;
@end
@implementation SDLUIKitSceneDelegate
/* PRODUCTION_SCENE_CALLBACKS */
@end
static void SendApplicationTransitions(void)
{
    for (NSString *name in @[UIApplicationWillResignActiveNotification, UIApplicationDidEnterBackgroundNotification,
                             UIApplicationWillEnterForegroundNotification, UIApplicationDidBecomeActiveNotification]) {
        [NSNotificationCenter.defaultCenter postNotificationName:name object:nil];
    }
}
static void SendSceneTransitions(SDLUIKitSceneDelegate *delegate, UIScene *scene)
{
    [delegate sceneWillResignActive:scene];
    [delegate sceneDidEnterBackground:scene];
    [delegate sceneWillEnterForeground:scene];
    [delegate sceneDidBecomeActive:scene];
}
int main(int argc, char **argv)
{
    @autoreleasepool {
        NSString *test = @(argv[1]);
        BOOL legacy = [test isEqualToString:@"legacy"];
        BOOL changeMode = [test isEqualToString:@"mode-change"];
        BOOL disabled = [test isEqualToString:@"observer-disabled"];
        BOOL primary = [test isEqualToString:@"primary"] || changeMode;
        applicationStarted = !legacy && !changeMode && !disabled;
        UIWindowScene *scene = [UIWindowScene new];
        applicationWindowScene = legacy || disabled || [test isEqualToString:@"disconnected"] ? nil : scene;
        SDL_LifecycleObserver *observer = [SDL_LifecycleObserver new];
        [observer update];
        if (changeMode) {
            // Notifications can already be registered when a primary scene connects.
            applicationStarted = YES;
        }
        if (disabled) {
            UIKit_EventPumpEnabled = NO;
            [observer update];
        }
        SendApplicationTransitions();
        SDLUIKitSceneDelegate *delegate = [SDLUIKitSceneDelegate new];
        SendSceneTransitions(delegate, primary ? scene : [UIWindowScene new]);
        int expected = legacy || primary ? 1 : 0;
        assert(willBackground == expected && didBackground == expected);
        assert(willForeground == expected && didForeground == expected);
        [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationWillTerminateNotification object:nil];
        [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationDidReceiveMemoryWarningNotification object:nil];
        assert(termination == (disabled ? 0 : 1));
        assert(memoryWarning == (disabled ? 0 : 1));
        [NSNotificationCenter.defaultCenter removeObserver:observer];
        printf("PASS lifecycle %s\n", argv[1]);
    }
    return 0;
}
