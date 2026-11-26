import ast
import configparser
import contextlib
import io
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import tomllib
import unittest
from unittest.mock import patch

from scripts import deploy, themes

ROOT = Path(__file__).resolve().parents[1]
COMPONENTS = sorted([p.name for p in (ROOT / 'stow').iterdir() if p.is_dir()] + ['dunst'])


class PaletteTests(unittest.TestCase):
    def test_default_preserves_every_shared_color(self):
        self.assertEqual(len(themes.BASE), len(set(themes.BASE.values())))
        colors = themes.palette(themes.DEFAULT)
        self.assertEqual(colors, themes.BASE)
        for area in ('stow', 'settings'):
            for path in (ROOT / area).rglob('*'):
                if path.is_file() and path.suffix != '.png':
                    with self.subTest(path=path):
                        self.assertEqual(themes.render_file(path, colors), path.read_text())

    def test_color_formats_and_alpha_are_preserved(self):
        colors = themes.palette(themes.DEFAULT, {'accent': '#123456', 'foreground': '#abcdef'})
        self.assertEqual(themes.render('#ff6a00fa rgba(ff6a00ee) ##ff6a00', colors),
                         '#123456fa rgba(123456ee) ##123456')
        self.assertEqual(themes.render('#ffff6a00', colors, qt=True), '#ff123456')
        self.assertEqual(themes.render('Color=255,106,0\nDIR 01;38;2;255;106;0\n', colors),
                         'Color=18,52,86\nDIR 01;38;2;18;52;86\n')
        self.assertEqual(themes.render('rgba(201, 200, 195, 0.18)', colors),
                         'rgba(171, 205, 239, 0.18)')
        self.assertEqual(themes.render('#123456 #000000 15,15,15', colors),
                         '#123456 #000000 15,15,15')

    def test_replacements_are_not_applied_twice(self):
        colors = themes.palette(themes.DEFAULT, {'accent': themes.BASE['foreground'], 'foreground': '#123456'})
        self.assertEqual(themes.render('#ff6a00 #c9c8c3', colors), '#c9c8c3 #123456')

    def test_overrides_update_related_colors(self):
        colors = themes.palette('nord', {'accent': '#abcdef', 'error': '#fe1234'})
        self.assertEqual(colors['accent'], '#abcdef')
        self.assertNotEqual(colors['accent_dim'], themes.BASE['accent_dim'])
        self.assertEqual(colors['terminal_red'], '#fe1234')
        self.assertEqual(colors['terminal_bright_red'], '#fe1234')
        self.assertEqual(themes.palette('nord', {'selection': '#010203'})['selection'], '#010203')

    def test_invalid_inputs_are_rejected(self):
        for name, colors in [('missing', {}), ('../nord', {}), ('nord', {'unknown': '#123456'}),
                             ('nord', {'accent': 'red'}), ('nord', {'accent': '#ff0000\ncommand'}),
                             ('nord', {'accent': 123}), ('nord', [])]:
            with self.subTest(name=name, colors=colors), self.assertRaises(ValueError):
                themes.palette(name, colors)


@unittest.skipUnless(shutil.which('stow'), 'GNU Stow is required for deployment integration tests')
class ThemeDeploymentTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dotfiles-themes-')
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name) / 'home with spaces'
        self.home.mkdir()

    def install(self, **kwargs):
        with contextlib.redirect_stdout(io.StringIO()):
            return deploy.deploy(self.home, COMPONENTS, apply=True, **kwargs)

    def test_all_presets_install_and_render_valid_files(self):
        for name in themes.PRESETS:
            with self.subTest(theme=name):
                self.install(theme=name)
                self.assertIsNone(self.install())
                accent = themes.palette(name)['accent']
                self.assertIn(accent, (self.home / '.config/waybar/style.css').read_text())
                self.assertIn(accent, (self.home / '.config/waybar/themes/controls.rasi').read_text())
                ast.parse((self.home / '.config/waybar/scripts/calendar-status.py').read_text())
                self.assertIn(accent, (self.home / '.config/waybar/scripts/calendar-status.py').read_text())
                self.assertEqual(plistlib.loads((self.home / '.codex/themes/charcoal-orange.tmTheme').read_bytes())
                                 ['settings'][0]['settings']['caret'], accent)
                for relative in ['.config/qt5ct/colors/CharcoalOrange.conf', '.config/qt6ct/colors/CharcoalOrange.conf',
                                 '.config/kdeglobals', '.local/share/color-schemes/CharcoalOrange.colors']:
                    config = configparser.ConfigParser(interpolation=None, strict=False)
                    config.read(self.home / relative)
                    self.assertTrue(config.sections())
                    if relative.endswith(('kdeglobals', '.colors')):
                        self.assertEqual(config['Colors:View']['BackgroundNormal'],
                                         ','.join(map(str, themes.rgb(themes.palette(name)['background']))))
                subprocess.run(['luac', '-p', str(self.home / '.config/hypr/hyprland.lua')], check=True)
                self.assertEqual((self.home / '.config/waybar/scripts/calendar-status.py').stat().st_mode & 0o777,
                                 (ROOT / 'stow/waybar/.config/waybar/scripts/calendar-status.py').stat().st_mode & 0o777)
                self.assertIn('font_family', (self.home / '.config/kitty/kitty.conf').read_text())
                self.assertEqual((self.home / '.config/kitty/kitty.conf').resolve(),
                                 ROOT / 'stow/kitty/.config/kitty/kitty.conf')

    def test_switcher_changes_installed_colors_and_keeps_unrelated_preferences(self):
        with contextlib.redirect_stdout(io.StringIO()):
            deploy.deploy(self.home, ['waybar', 'kitty', 'kde'], apply=True)
        kde = self.home / '.config/kdeglobals'
        kde.write_text(kde.read_text() + '\n[Personal]\nkeep=this\n')
        command = [sys.executable, str(ROOT / 'scripts/theme.py'), '--home', str(self.home),
                   '--theme', 'nord', '--accent', '#123456']
        original = (self.home / '.config/waybar/style.css').read_bytes()
        subprocess.run(command, check=True, capture_output=True)
        self.assertEqual((self.home / '.config/waybar/style.css').read_bytes(), original)
        subprocess.run(command + ['--apply'], check=True, capture_output=True)
        self.assertIn('#123456', (self.home / '.config/waybar/style.css').read_text())
        self.assertIn('keep=this', kde.read_text())
        self.assertFalse((self.home / '.config/hypr/hyprland.lua').exists())
        self.assertFalse((self.home / '.config/dunst/dunstrc').exists())
        self.assertFalse((self.home / '.zshrc').exists())
        self.assertEqual(tomllib.loads((self.home / '.config/desktop/theme.toml').read_text()),
                         {'palette': 'nord', 'colors': {'accent': '#123456'}})
        self.assertEqual((ROOT / 'stow/waybar/.config/waybar/style.css').read_bytes(), original)
        # A later full deployment uses the saved palette and renders new components.
        self.install()
        self.assertIn('rgba(123456ff)', (self.home / '.config/hypr/hyprlock.conf').read_text())

    def test_reset_to_default_and_restore_previous_theme(self):
        self.install(theme='nord', colors={'accent': '#123456'})
        before = (self.home / '.config/waybar/style.css').read_bytes()
        backup = self.install(theme=themes.DEFAULT)
        self.assertTrue((self.home / '.config/waybar/style.css').is_symlink())
        self.assertEqual(tomllib.loads((self.home / '.config/desktop/theme.toml').read_text())['colors'], {})
        with contextlib.redirect_stdout(io.StringIO()):
            deploy.restore(self.home, backup)
        self.assertEqual((self.home / '.config/waybar/style.css').read_bytes(), before)
        self.assertIsNone(self.install())

    def test_failed_deployment_restores_theme_and_symlinks(self):
        self.install()
        original = (self.home / '.config/desktop/theme.toml').read_bytes()
        missing = self.home / '.config/kitty/kitty.conf'
        missing.unlink()
        with patch.object(deploy.subprocess, 'run', side_effect=subprocess.CalledProcessError(1, ['stow'])):
            with self.assertRaises(subprocess.CalledProcessError):
                self.install(theme='nord')
        self.assertEqual((self.home / '.config/desktop/theme.toml').read_bytes(), original)
        self.assertTrue((self.home / '.config/waybar/style.css').is_symlink())
        self.assertFalse(missing.exists())

    def test_reset_keeps_hyprland_config_present_before_stow(self):
        self.install(theme='nord')
        config = self.home / '.config/hypr/hyprland.lua'
        run = subprocess.run

        def check_stow(command, **kwargs):
            self.assertTrue(config.is_file())
            self.assertTrue(config.is_symlink())
            self.assertNotIn('--restow', command)
            return run(command, **kwargs)

        with patch.object(deploy.subprocess, 'run', side_effect=check_stow):
            self.install(theme=themes.DEFAULT)
        self.assertIsNone(self.install())

    def test_invalid_local_colors_make_no_changes(self):
        path = self.home / '.config/desktop/theme.toml'
        path.parent.mkdir(parents=True)
        path.write_text('palette = "nord"\n[colors]\naccent = "bad"\n')
        with self.assertRaises(ValueError):
            self.install()
        self.assertFalse((self.home / '.local').exists())
        self.assertFalse((self.home / '.config/kitty').exists())


if __name__ == '__main__':
    unittest.main()
