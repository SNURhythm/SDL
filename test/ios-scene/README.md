# SDL2 UIKit scene smoke test

This fixture exercises the SNURhythm fork's optional, single-window scene lifecycle.
Apps opt in with `UIApplicationSceneManifest` and `SDLUIKitSceneDelegate`, as shown
in `Info.plist`. Apps without that manifest keep the legacy application lifecycle
on OS versions that still support it. Multiple simultaneous app scenes are not
supported.

From the SDL repository, build for an Apple Silicon simulator:

```sh
cmake -S test/ios-scene -B build-ios-scene -G Ninja \
  -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphonesimulator \
  -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
  -DCMAKE_BUILD_TYPE=Debug
cmake --build build-ios-scene --target SDLSceneSmoke -j 6
codesign --force --sign - --timestamp=none build-ios-scene/SDLSceneSmoke.app
xcrun simctl install booted build-ios-scene/SDLSceneSmoke.app
xcrun simctl launch booted org.libsdl.SceneSmoke
```

The app should show a blue screen. It records observations in its data container's
`Documents/scene-events.txt` (also available in the console):

```sh
scene_data=$(xcrun simctl get_app_container booted org.libsdl.SceneSmoke data)
cat "$scene_data/Documents/scene-events.txt"
```

Check these behaviors; each process entry appends `MAIN`:

1. Normal launch records `WINDOW_ATTACHED` and `FRAME_PRESENTED`, with no `FAIL`.
2. Launch Settings (`xcrun simctl launch booted com.apple.Preferences`), wait for
   its screen, then launch the smoke app again. It records exactly one each of
   `WILL_BACKGROUND`, `DID_BACKGROUND`, `WILL_FOREGROUND`, `DID_FOREGROUND` and
   `RESUME_FRAME_PRESENTED` without another `MAIN`.
3. Run `xcrun simctl openurl booted sdl-scene-smoke://warm` and accept the simulator's
   Open confirmation if shown. It records `URL: sdl-scene-smoke://warm` once.
4. Terminate with `xcrun simctl terminate booted org.libsdl.SceneSmoke`, then run
   `xcrun simctl openurl booted sdl-scene-smoke://cold`. It records another `MAIN`,
   the window/frame markers and exactly one cold URL. The fixture intentionally
   runs the native loop **before SDL_Init**, catching premature URL delivery.
5. Tap the blue view and rotate the simulator: input records `TOUCH_DOWN`,
   orientation changes record `ORIENTATION_CHANGED`, and rendering continues.

Stop the fixture after testing. On simulators with several integrated displays,
`simctl io ... screenshot` can select an inactive display; use `enumerate` and
an explicit `--display` or inspect the simulator frontend.

For display selection without external-display hardware, run on macOS:

```sh
python3 test/ios-scene/test_display_selection.py
```

This compiles the production scene helpers, connection callback, display
initialization and window-show function against small Foundation-based UIKit
doubles. It covers legacy display ordering, internal and external app scenes,
input focus, a connecting scene absent from `connectedScenes`, and reconnection
while the old scene remains in that set. Use an iPad with an extended display to
confirm actual external-screen rendering and window movement.
