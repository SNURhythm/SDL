#!/usr/bin/env python3
"""Run production UIKit marked-text selection logic against UTF-16 input positions."""
import pathlib
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
controller = (ROOT / 'src/video/uikit/SDL_uikitviewcontroller.m').read_text()
start = controller.index('    if (textField.markedTextRange != nil)', controller.index('- (void)textFieldTextDidChange:'))
end = controller.index('    } else {\n        if (hasMarkedText)', start)
marked = controller[start:end] + '    }\n'
source = pathlib.Path(__file__).with_suffix('.m').read_text().replace('/* PRODUCTION_MARKED_TEXT */', marked)
with tempfile.TemporaryDirectory(prefix='sdl3-ime-offsets-') as tmp:
    path = pathlib.Path(tmp)
    (path / 'test.m').write_text(source)
    subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-framework', 'Foundation', '-Werror',
                    str(path / 'test.m'), '-o', str(path / 'test')], check=True)
    subprocess.run([str(path / 'test')], check=True)
