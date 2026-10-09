#!/usr/bin/env python3
"""Exercise production UIKit scene/display boundaries on macOS with Foundation doubles."""
import pathlib
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]


def function(source, signature):
    start = source.index(signature)
    brace = source.index('{', start)
    depth = 1
    end = brace + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]


app = (ROOT / 'src/video/uikit/SDL_uikitappdelegate.m').read_text()
window = (ROOT / 'src/video/uikit/SDL_uikitwindow.m').read_text()
modes = (ROOT / 'src/video/uikit/SDL_uikitmodes.m').read_text()
video = (ROOT / 'src/video/uikit/SDL_uikitvideo.m').read_text()
helpers = app[app.index('static UIWindowScene *applicationWindowScene'):app.index('UIInterfaceOrientation UIKit_GetApplicationOrientation')]
source = pathlib.Path(__file__).with_suffix('.m').read_text()
source = source.replace('/* PRODUCTION_HELPERS */', helpers)
source = source.replace('/* PRODUCTION_ACTIVE_SCENE */', function(video, 'UIWindowScene *UIKit_GetActiveWindowScene('))
source = source.replace('/* PRODUCTION_INIT_MODES */', function(modes, 'bool UIKit_InitModes('))
source = source.replace('/* PRODUCTION_SHOW_WINDOW */', function(window, 'void UIKit_ShowWindow('))
source = source.replace('/* PRODUCTION_CONNECT */', function(app, '- (void)scene:(UIScene *)scene willConnectToSession:'))
source = source.replace('/* PRODUCTION_PROCESS_URLS */', function(app, '- (void)processLaunchURLs\n{'))
disconnect = '- (void)sceneDidDisconnect:(UIScene *)scene'
source = source.replace('/* PRODUCTION_DISCONNECT */', function(app, disconnect) if disconnect in app else disconnect + ' {}')
with tempfile.TemporaryDirectory(prefix='sdl3-scene-display-') as tmp:
    path = pathlib.Path(tmp)
    (path / 'test.m').write_text(source)
    subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-framework', 'Foundation',
                    '-Werror', '-Wno-unguarded-availability-new', str(path / 'test.m'),
                    '-o', str(path / 'test')], check=True)
    failures = []
    for case in ['legacy', 'external', 'internal', 'same-session', 'replacement-session', 'unattached-session', 'secondary', 'reconnect-activity']:
        result = subprocess.run([str(path / 'test'), case])
        if result.returncode:
            failures.append(case)
    if failures:
        raise SystemExit('Failed scene cases: ' + ', '.join(failures))
