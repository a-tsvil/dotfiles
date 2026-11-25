#!/usr/bin/env python3
"""Validate tracked text/assets without launching desktop applications."""
import ast
import configparser
import json
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
errors = []
files = [p for area in ['stow', 'settings', 'examples', 'scripts', 'tests', 'packages'] for p in (ROOT / area).rglob('*') if p.is_file() and '__pycache__' not in p.parts]
for path in files:
    try:
        if path.suffix == '.png':
            assert path.read_bytes().startswith(b'\x89PNG\r\n\x1a\n'), 'Invalid PNG signature'
            continue
        text = path.read_text()
        assert not re.search(r'/home/[\w.-]+/', text), 'Hard-coded user home'
        assert not re.search(r'(?i)(?:api[_-]?key|access[_-]?token|password)\s*[:=]\s*[\'\"][A-Za-z0-9_.-]{16,}', text), 'Possible embedded credential'
        if path.suffix in ('.json', '.jsonc'):
            json.loads(text)
        if path.suffix == '.py':
            ast.parse(text, filename=str(path))
        if path.suffix == '.tmTheme':
            plistlib.loads(path.read_bytes())
        if path.suffix == '.ini':
            parser = configparser.ConfigParser(interpolation=None, strict=False)
            parser.read_string(text)
        if text.startswith('#!') and ('bash' in text.splitlines()[0] or '/sh' in text.splitlines()[0]):
            subprocess.run(['bash', '-n', str(path)], check=True)
        if path.suffix == '.lua':
            if not shutil.which('luac'):
                raise RuntimeError('luac is needed to check Lua syntax')
            subprocess.run(['luac', '-p', str(path)], check=True)
    except Exception as error:
        errors.append(f'{path.relative_to(ROOT)}: {error}')
bar = json.loads((ROOT / 'stow/waybar/.config/waybar/config.jsonc').read_text())[0]
assert bar['pulseaudio']['states'] == {'normal': 99, 'full': 100}
assert 'output' not in bar, 'Monitor selection belongs in local config'
assert 'wlp0s20f3' not in json.dumps(bar) and 'BAT0' not in json.dumps(bar)
fastfetch = json.loads((ROOT / 'stow/fastfetch/.config/fastfetch/config.jsonc').read_text())
assert len(fastfetch['modules']) > 15
assert 'display' not in fastfetch and 'logo' not in fastfetch, 'Fastfetch must inherit terminal colors'
if errors:
    print('\n'.join(errors), file=sys.stderr)
    sys.exit(1)
print(f'Validated {len(files)} files: JSON, INI, Python, shell, Lua, theme plist, asset headers, portability, and credential-pattern checks.')
