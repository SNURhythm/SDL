#!/usr/bin/env python3
"""Run the UIKit display-selection regression on macOS without an external monitor."""
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
helpers = app[app.index('BOOL UIKit_UsesSceneLifecycle'):app.index('#if !TARGET_OS_TV\nUIInterfaceOrientation')]
source = (pathlib.Path(__file__).with_suffix('.m')).read_text()
source = source.replace('/* PRODUCTION_HELPERS */', helpers)
source = source.replace('/* PRODUCTION_INIT_MODES */', function(modes, 'int UIKit_InitModes('))
source = source.replace('/* PRODUCTION_SHOW_WINDOW */', function(window, 'void UIKit_ShowWindow('))
# Skip the declaration in the private interface.
source = source.replace('/* PRODUCTION_CONNECT */', function(app, '- (void)connectWindowScene:(UIWindowScene *)scene\n{'))
with tempfile.TemporaryDirectory(prefix='sdl-scene-display-') as tmp:
    path = pathlib.Path(tmp)
    (path / 'test.m').write_text(source)
    subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-framework', 'Foundation',
                    '-Werror', '-Wno-unguarded-availability-new', str(path / 'test.m'),
                    '-o', str(path / 'test')], check=True)
    for case in ['legacy', 'external', 'internal', 'reconnect']:
        subprocess.run([str(path / 'test'), case], check=True)
