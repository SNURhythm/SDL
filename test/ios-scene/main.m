/* UIKit scene integration smoke test. See README.md for simulator commands. */
#import <UIKit/UIKit.h>
#include "SDL.h"
#include "SDL_syswm.h"

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

int main(int argc, char **argv)
{
    SDL_Window *window;
    SDL_Renderer *renderer;
    SDL_SysWMinfo info;
    SDL_Event event;
    BOOL firstFrame = YES;
    BOOL resumeFrame = NO;
    Record(@"MAIN");
    /* Native startup work must not consume a cold URL before SDL_Init. */
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, false);
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS) < 0) {
        Record(@(SDL_GetError()));
        return 1;
    }
    window = SDL_CreateWindow("Scene smoke", 0, 0, 480, 800, SDL_WINDOW_SHOWN | SDL_WINDOW_ALLOW_HIGHDPI);
    if (!window) {
        Record(@(SDL_GetError()));
        return 2;
    }
    SDL_VERSION(&info.version);
    SDL_GetWindowWMInfo(window, &info);
    UIWindow *uiwindow = info.info.uikit.window;
    if (!uiwindow.windowScene || !uiwindow.rootViewController || uiwindow.hidden) {
        Record(@"FAIL: SDL window is not attached to a visible scene");
        return 3;
    }
    Record(@"WINDOW_ATTACHED");
    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    if (!renderer) {
        Record(@(SDL_GetError()));
        return 4;
    }
    for (;;) {
        while (SDL_PollEvent(&event)) {
            switch (event.type) {
            case SDL_APP_WILLENTERBACKGROUND: Record(@"WILL_BACKGROUND"); break;
            case SDL_APP_DIDENTERBACKGROUND: Record(@"DID_BACKGROUND"); break;
            case SDL_APP_WILLENTERFOREGROUND: Record(@"WILL_FOREGROUND"); break;
            case SDL_APP_DIDENTERFOREGROUND: Record(@"DID_FOREGROUND"); resumeFrame = YES; break;
            case SDL_DISPLAYEVENT:
                if (event.display.event == SDL_DISPLAYEVENT_ORIENTATION) {
                    Record(@"ORIENTATION_CHANGED");
                }
                break;
            case SDL_FINGERDOWN: Record(@"TOUCH_DOWN"); break;
            case SDL_DROPFILE:
                Record([@"URL: " stringByAppendingString:@(event.drop.file)]);
                SDL_free(event.drop.file);
                break;
            case SDL_QUIT: SDL_Quit(); return 0;
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
