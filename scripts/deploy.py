#!/usr/bin/env python3
"""Preview or deploy selected Stow packages and merge appearance settings."""
from __future__ import annotations
import argparse
import configparser
from datetime import datetime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import tomllib

ROOT = Path(__file__).resolve().parents[1]


def merge_ini(existing, fragment):
    """Replace only selected INI entries; preserve unrelated lines and comments."""
    config = configparser.ConfigParser(interpolation=None, strict=False)
    config.optionxform = str
    config.read_string(fragment)
    text = existing
    for section in config.sections():
        for key, value in config[section].items():
            lines = text.splitlines(keepends=True)
            header = '[' + section + ']'
            start = next((i for i, line in enumerate(lines) if line.strip() == header), None)
            if start is None:
                text = text.rstrip() + ('\n\n' if text.strip() else '') + header + '\n' + key + '=' + value + '\n'
                continue
            end = next((i for i in range(start + 1, len(lines)) if lines[i].lstrip().startswith('[')), len(lines))
            matches = [i for i in range(start + 1, end) if re.match(r'^\s*' + re.escape(key) + r'\s*=', lines[i])]
            if matches:
                lines[matches[0]] = key + '=' + value + '\n'
                for index in reversed(matches[1:]):
                    del lines[index]
            else:
                if lines and not lines[end - 1].endswith('\n'):
                    lines[end - 1] += '\n'
                lines.insert(end, key + '=' + value + '\n')
            text = ''.join(lines)
    return text


def codex_theme(text):
    tomllib.loads(text)
    lines = text.splitlines(keepends=True)
    start = next((i for i, line in enumerate(lines) if line.strip() == '[tui]'), None)
    if start is None:
        result = text.rstrip() + ('\n\n' if text.strip() else '') + '[tui]\ntheme = "charcoal-orange"\n'
    else:
        end = next((i for i in range(start + 1, len(lines)) if lines[i].lstrip().startswith('[')), len(lines))
        matches = [i for i in range(start + 1, end) if re.match(r'^\s*theme\s*=', lines[i])]
        if matches:
            lines[matches[0]] = 'theme = "charcoal-orange"\n'
        else:
            if lines and not lines[end - 1].endswith('\n'):
                lines[end - 1] += '\n'
            lines.insert(end, 'theme = "charcoal-orange"\n')
        result = ''.join(lines)
    parsed = tomllib.loads(result)
    assert parsed['tui']['theme'] == 'charcoal-orange'
    return result


def exists(path):
    return path.exists() or path.is_symlink()


def deploy(home, selected, apply=False):
    home = home.expanduser().resolve()
    if not home.is_dir():
        raise ValueError('Target home directory does not exist: ' + str(home))
    operations = {}
    def relative(path):
        return str(path.relative_to(home))
    def read(path):
        return path.read_text() if exists(path) else ''
    def content(path, text):
        if not exists(path) or read(path) != text:
            operations[path] = ('write', text)
    def ini(target, source):
        path = home / target
        fragment = (ROOT / 'settings' / source).read_text().replace('@HOME@', str(home))
        content(path, merge_ini(read(path), fragment))
    def once(target, source):
        path = home / target
        if not exists(path):
            content(path, (ROOT / 'examples' / source).read_text())

    stow_packages = [name for name in selected if (ROOT / 'stow' / name).is_dir()]
    for name in stow_packages:
        package = ROOT / 'stow' / name
        for source in sorted(package.rglob('*')):
            if not source.is_file():
                continue
            target = home / source.relative_to(package)
            if not (target.is_symlink() and target.resolve() == source.resolve()):
                operations[target] = ('link', str(source))
    if 'hypr' in selected:
        once('.config/hypr/hyprland.local.lua', 'hyprland.local.lua')
        content(home / '.config/hypr/hyprpaper.conf', (ROOT / 'settings/hyprpaper.conf.in').read_text().replace('@HOME@', str(home)))
    if 'waybar' in selected:
        once('.config/desktop/host.env', 'host.env')
        once('.config/desktop/waybar-host.jsonc', 'waybar-host.jsonc')
    if 'gtk' in selected:
        for version in ('3.0', '4.0'):
            ini(f'.config/gtk-{version}/settings.ini', f'gtk-{version}.ini')
            path = home / f'.config/gtk-{version}/gtk.css'
            text = read(path)
            if not re.search(r'@import[^;]*charcoal-orange\.css[^;]*;', text):
                content(path, text.rstrip() + ('\n' if text.strip() else '') + '@import url("charcoal-orange.css");\n')
    if 'qt' in selected:
        for version in (5, 6):
            ini(f'.config/qt{version}ct/qt{version}ct.conf', f'qt{version}ct.ini')
    if 'kde' in selected:
        ini('.config/kdeglobals', 'kdeglobals.ini')
    if 'dunst' in selected:
        content(home / '.config/dunst/dunstrc', (ROOT / 'settings/dunstrc.in').read_text().replace('@HOME@', str(home)))
    if 'codex' in selected:
        path = home / '.codex/config.toml'
        content(path, codex_theme(read(path)))
    if 'shell' in selected:
        path = home / '.zshrc'
        text = read(path)
        line = '[ ! -r "$HOME/.config/shell/colors.sh" ] || . "$HOME/.config/shell/colors.sh"'
        if line not in text:
            content(path, text.rstrip() + '\n\n# Charcoal Orange file-listing colors.\n' + line + '\n')
    # Never follow a directory symlink into another dotfiles repository.
    for path in operations:
        for parent in path.parents:
            if parent == home:
                break
            if parent.is_symlink():
                raise ValueError('Symlinked parent needs manual review: ' + str(parent))
        if path.is_dir() and not path.is_symlink():
            raise ValueError('Expected a file but found a directory: ' + str(path))
    for path, (kind, _) in operations.items():
        print(f'{kind:5} {relative(path)}' + (' (back up existing)' if exists(path) else ''))
    if not operations:
        print('Already up to date.')
        return None
    if not apply:
        print('Preview only. Re-run with --apply to make these changes.')
        return None
    if stow_packages and shutil.which('stow') is None:
        raise ValueError('GNU Stow is required: sudo pacman -S stow')
    backup = home / '.local/state/dotfiles/backups' / datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    backup.mkdir(parents=True, mode=0o700)
    records = []
    # Take every snapshot before changing any destination.
    for path in operations:
        saved = backup / relative(path)
        record = {'path': relative(path), 'existed': exists(path)}
        if exists(path):
            saved.parent.mkdir(parents=True, exist_ok=True)
            if path.is_symlink():
                saved.symlink_to(os.readlink(path))
            else:
                shutil.copy2(path, saved)
        records.append(record)
    (backup / 'manifest.json').write_text(json.dumps(records, indent=2) + '\n')
    try:
        for path, (kind, text) in operations.items():
            path.parent.mkdir(parents=True, exist_ok=True)
            if kind == 'link':
                if exists(path):
                    path.unlink()
                continue
            mode = path.stat().st_mode & 0o777 if path.exists() else 0o600
            fd, temporary = tempfile.mkstemp(prefix='.dotfiles-', dir=path.parent)
            try:
                with os.fdopen(fd, 'w') as stream:
                    stream.write(text)
                os.chmod(temporary, mode)
                os.replace(temporary, path)
            finally:
                if os.path.exists(temporary):
                    os.unlink(temporary)
        if any(kind == 'link' for kind, _ in operations.values()):
            subprocess.run(['stow', '--dir', str(ROOT / 'stow'), '--target', str(home), '--no-folding', '--restow', *stow_packages], check=True)
    except BaseException:
        restore(home, backup, quiet=True)
        raise
    print('Installed. Backup:', backup)
    print('Review ~/.config/hypr/hyprland.local.lua before reloading Hyprland.')
    return backup


def restore(home, backup, quiet=False):
    home = home.expanduser().resolve()
    backup = backup.expanduser().resolve()
    records = json.loads((backup / 'manifest.json').read_text())
    for record in reversed(records):
        rel = Path(record['path'])
        if rel.is_absolute() or '..' in rel.parts:
            raise ValueError('Invalid backup path')
        target = home / rel
        for parent in target.parents:
            if parent == home:
                break
            if parent.is_symlink():
                raise ValueError('Symlinked parent needs manual review: ' + str(parent))
        if exists(target):
            if target.is_dir() and not target.is_symlink():
                raise ValueError('Refusing to replace directory: ' + str(target))
            target.unlink()
        if record['existed']:
            saved = backup / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            if saved.is_symlink():
                target.symlink_to(os.readlink(saved))
            else:
                shutil.copy2(saved, target)
    if not quiet:
        print('Restored original files from', backup)


def main():
    available = sorted([path.name for path in (ROOT / 'stow').iterdir() if path.is_dir()] + ['dunst'])
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true', help='Make changes; default is a read-only preview')
    parser.add_argument('--home', type=Path, default=Path.home(), help='Target home (also useful for testing)')
    parser.add_argument('--only', nargs='+', choices=available, help='Deploy only these components')
    parser.add_argument('--restore', type=Path, help='Restore files from a previous backup (requires --apply)')
    args = parser.parse_args()
    if args.restore:
        if not args.apply:
            parser.error('--restore requires --apply; it replaces the files listed in that backup')
        restore(args.home, args.restore)
    else:
        deploy(args.home, args.only or available, args.apply)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError, tomllib.TOMLDecodeError) as error:
        print('Deployment stopped:', error, file=sys.stderr)
        sys.exit(1)
