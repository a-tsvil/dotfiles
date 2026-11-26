import contextlib
import io
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import tomllib
import unittest
from unittest.mock import patch

from scripts import deploy

ROOT = Path(__file__).resolve().parents[1]
COMPONENTS = sorted([p.name for p in (ROOT / 'stow').iterdir() if p.is_dir()] + ['dunst'])


@unittest.skipUnless(shutil.which('stow'), 'GNU Stow is required for deployment integration tests')
class DeploymentTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dotfiles-test-')
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name) / 'home with spaces'
        self.home.mkdir()

    def run_deploy(self, apply=True):
        with contextlib.redirect_stdout(io.StringIO()):
            return deploy.deploy(self.home, COMPONENTS, apply=apply)

    def original_files(self):
        originals = {
            '.config/kitty/kitty.conf': 'font_size 12\n',
            '.config/kdeglobals': '# keep this comment\n[KFileDialog Settings]\nShow hidden files=true\n[General]\nColorScheme=BreezeLight\n',
            '.codex/config.toml': 'model = "test-model"\n[tui]\nnotifications = false\ntheme = "old"\n[projects."/test"]\ntrust_level = "trusted"\n',
            '.zshrc': '# personal aliases\nalias hi="echo hi"\n',
            '.config/qt6ct/qt6ct.conf': '[Fonts]\ngeneral=Personal Font\n[Appearance]\nstyle=Old\n',
            '.config/gtk-3.0/gtk.css': '/* personal rules */\nbutton { padding: 2px; }\n',
        }
        for name, text in originals.items():
            path = self.home / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        (self.home / '.codex/config.toml').chmod(0o600)
        return originals

    def test_preview_is_read_only(self):
        originals = self.original_files()
        self.run_deploy(apply=False)
        for name, text in originals.items():
            self.assertEqual((self.home / name).read_text(), text)
        self.assertFalse((self.home / '.local').exists())

    def test_install_merges_and_is_idempotent(self):
        originals = self.original_files()
        backup = self.run_deploy()
        for name, text in originals.items():
            self.assertEqual((backup / name).read_text(), text)
        self.assertTrue((self.home / '.config/kitty/kitty.conf').is_symlink())
        self.assertFalse((self.home / '.config/kitty').is_symlink())
        codex = tomllib.loads((self.home / '.codex/config.toml').read_text())
        self.assertEqual(codex['model'], 'test-model')
        self.assertFalse(codex['tui']['notifications'])
        self.assertEqual(codex['tui']['theme'], 'charcoal-orange')
        self.assertEqual((self.home / '.codex/config.toml').stat().st_mode & 0o777, 0o600)
        kde = (self.home / '.config/kdeglobals').read_text()
        self.assertIn('Show hidden files=true', kde)
        self.assertIn('# keep this comment', kde)
        self.assertIn('[UiSettings]\nColorScheme=CharcoalOrange', kde)
        self.assertIn('general=Personal Font', (self.home / '.config/qt6ct/qt6ct.conf').read_text())
        self.assertIn(str(self.home), (self.home / '.config/qt6ct/qt6ct.conf').read_text())
        self.assertIn('personal rules', (self.home / '.config/gtk-3.0/gtk.css').read_text())
        self.assertIsNone(self.run_deploy())

    def test_cli_uses_home_and_allows_explicit_override(self):
        other = Path(self.temp.name) / 'other home'
        other.mkdir()
        env = dict(os.environ, HOME=str(self.home))
        command = [sys.executable, str(ROOT / 'scripts/deploy.py'), '--only', 'hypr', 'qt', 'dunst', '--apply']
        for target, args in [(self.home, []), (other, ['--home', str(other)])]:
            subprocess.run(command + args, env=env, check=True, capture_output=True, text=True)
            for name in ['.config/hypr/hyprpaper.conf', '.config/qt5ct/qt5ct.conf',
                         '.config/qt6ct/qt6ct.conf', '.config/dunst/dunstrc']:
                text = (target / name).read_text()
                self.assertIn(str(target) + '/.config/', text)
                self.assertNotIn('@HOME@', text)
            link = target / '.config/hypr/hyprland.lua'
            self.assertTrue(link.is_symlink())
            self.assertEqual(link.resolve(), ROOT / 'stow/hypr/.config/hypr/hyprland.lua')

    def test_local_overrides_are_preserved(self):
        overrides = {
            '.config/hypr/hyprland.local.lua': 'hl.config({ input = { kb_layout = "de" } })\n',
            '.config/desktop/host.env': 'NETWORK_INTERFACE=wlan9\nBATTERY_NAME=BAT3\n',
            '.config/desktop/waybar-host.jsonc': '{"output": ["DP-2"]}\n',
        }
        for name, text in overrides.items():
            path = self.home / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        self.run_deploy()
        self.assertIsNone(self.run_deploy())
        for name, text in overrides.items():
            path = self.home / name
            self.assertEqual(path.read_text(), text)
            self.assertFalse(path.is_symlink())

    def test_restore_recovers_previous_files(self):
        originals = self.original_files()
        backup = self.run_deploy()
        with contextlib.redirect_stdout(io.StringIO()):
            deploy.restore(self.home, backup)
        for name, text in originals.items():
            self.assertEqual((self.home / name).read_text(), text)
            self.assertFalse((self.home / name).is_symlink())
        self.assertFalse((self.home / '.config/hypr/hyprland.lua').exists())

    def test_failed_stow_rolls_back(self):
        originals = self.original_files()
        with patch.object(deploy.subprocess, 'run', side_effect=subprocess.CalledProcessError(1, ['stow'])):
            with self.assertRaises(subprocess.CalledProcessError):
                self.run_deploy()
        for name, text in originals.items():
            self.assertEqual((self.home / name).read_text(), text)
        self.assertFalse((self.home / '.config/hypr/hyprland.local.lua').exists())

    def test_reject_symlinked_parent_without_changes(self):
        elsewhere = self.home / 'elsewhere'
        elsewhere.mkdir()
        (self.home / '.config').symlink_to(elsewhere)
        with self.assertRaisesRegex(ValueError, 'Symlinked parent'):
            self.run_deploy()
        self.assertEqual(list(elsewhere.iterdir()), [])
        self.assertFalse((self.home / '.local').exists())


if __name__ == '__main__':
    unittest.main()
