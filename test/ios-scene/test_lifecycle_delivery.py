#!/usr/bin/env python3
"""Test real notification registration and scene callbacks for exclusive delivery."""
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
events = (ROOT / 'src/video/uikit/SDL_uikitevents.m').read_text()
source = pathlib.Path(__file__).with_suffix('.m').read_text()
mode = 'BOOL UIKit_UsesSceneLifecycle(void)'
source = source.replace('/* PRODUCTION_SCENE_MODE */', function(app, mode) if mode in app else mode + ' { return applicationStarted; }')
observer = '\n\n'.join(function(events, signature) for signature in [
    '- (void)update', '- (void)applicationDidBecomeActive', '- (void)applicationWillResignActive',
    '- (void)applicationDidEnterBackground', '- (void)applicationWillEnterForeground',
    '- (void)applicationWillTerminate', '- (void)applicationDidReceiveMemoryWarning'])
source = source.replace('/* PRODUCTION_OBSERVER */', observer)
scene = '\n\n'.join(function(app, signature) for signature in [
    '- (void)sceneDidBecomeActive:', '- (void)sceneWillResignActive:',
    '- (void)sceneWillEnterForeground:', '- (void)sceneDidEnterBackground:'])
source = source.replace('/* PRODUCTION_SCENE_CALLBACKS */', scene)
with tempfile.TemporaryDirectory(prefix='sdl3-lifecycle-') as tmp:
    path = pathlib.Path(tmp)
    (path / 'test.m').write_text(source)
    subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-framework', 'Foundation', '-Werror',
                    str(path / 'test.m'), '-o', str(path / 'test')], check=True)
    failures = []
    for case in ['legacy', 'primary', 'secondary', 'disconnected', 'mode-change', 'observer-disabled']:
        result = subprocess.run([str(path / 'test'), case])
        if result.returncode:
            failures.append(case)
    if failures:
        raise SystemExit('Failed lifecycle cases: ' + ', '.join(failures))
