/* UIKit scene integration smoke test. See README.md for simulator commands. */
#import <UIKit/UIKit.h>
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>

static void Record(NSString *message)
{
    NSString *directory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *path = [directory stringByAppendingPathComponent:@"scene-events.txt"];
    FILE *file = fopen(path.UTF8String, "a");
    if (file) {
        fprintf(file, "%s\n", message.UTF8String);
        fclose(file);
    }
    SDL_Log("%s", message.UTF8String);
}

static bool WatchLifecycle(void *userdata, SDL_Event *event)
{
    BOOL *resumeFrame = (BOOL *)userdata;
    switch (event->type) {
    case SDL_EVENT_WILL_ENTER_BACKGROUND: Record(@"WILL_BACKGROUND"); break;
    case SDL_EVENT_DID_ENTER_BACKGROUND: Record(@"DID_BACKGROUND"); break;
    case SDL_EVENT_WILL_ENTER_FOREGROUND: Record(@"WILL_FOREGROUND"); break;
    case SDL_EVENT_DID_ENTER_FOREGROUND:
        Record(@"DID_FOREGROUND");
        *resumeFrame = YES;
        break;
    }
    return true;
}

int main(int argc, char **argv)
{
    SDL_Window *window;
    SDL_Renderer *renderer;
    SDL_Event event;
    BOOL firstFrame = YES;
    BOOL resumeFrame = NO;
    Record(@"MAIN");
    /* Native startup work must not consume a cold URL before SDL_Init. */
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, false);
    if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS)) {
        Record(@(SDL_GetError()));
        return 1;
    }
    SDL_AddEventWatch(WatchLifecycle, &resumeFrame);
    window = SDL_CreateWindow("Scene smoke", 480, 800, SDL_WINDOW_HIGH_PIXEL_DENSITY);
    if (!window) {
        Record(@(SDL_GetError()));
        return 2;
    }
    UIWindow *uiwindow = (__bridge UIWindow *)SDL_GetPointerProperty(SDL_GetWindowProperties(window), SDL_PROP_WINDOW_UIKIT_WINDOW_POINTER, NULL);
    if (!uiwindow.windowScene || !uiwindow.rootViewController || uiwindow.hidden) {
        Record(@"FAIL: SDL window is not attached to a visible scene");
        return 3;
    }
    Record(@"WINDOW_ATTACHED");
    renderer = SDL_CreateRenderer(window, NULL);
    if (!renderer) {
        Record(@(SDL_GetError()));
        return 4;
    }
    for (;;) {
        while (SDL_PollEvent(&event)) {
            switch (event.type) {
            case SDL_EVENT_DISPLAY_ORIENTATION: Record(@"ORIENTATION_CHANGED"); break;
            case SDL_EVENT_FINGER_DOWN: Record(@"TOUCH_DOWN"); break;
            case SDL_EVENT_DROP_FILE:
                Record([@"URL: " stringByAppendingString:@(event.drop.data)]);
                break;
            case SDL_EVENT_QUIT: SDL_Quit(); return 0;
            }
        }
        if (uiwindow.windowScene.activationState == UISceneActivationStateForegroundActive) {
            SDL_SetRenderDrawColor(renderer, 40, 110, 180, 255);
            SDL_RenderClear(renderer);
            SDL_RenderPresent(renderer);
            if (firstFrame) {
                Record(@"FRAME_PRESENTED");
                firstFrame = NO;
            }
            if (resumeFrame) {
                Record(@"RESUME_FRAME_PRESENTED");
                resumeFrame = NO;
            }
        }
        SDL_Delay(16);
    }
}
