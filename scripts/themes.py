"""Render shared Charcoal Orange colors using a preset and local overrides."""
from pathlib import Path
import re
import tomllib

DIRECTORY = Path(__file__).resolve().parents[1] / 'themes'
DEFAULT = 'charcoal-orange'
BASE = tomllib.loads((DIRECTORY / (DEFAULT + '.toml')).read_text())
PRESETS = sorted(path.stem for path in DIRECTORY.glob('*.toml'))


def validate(colors):
    if not isinstance(colors, dict):
        raise ValueError('Theme colors must be a table of role = "#RRGGBB" entries')
    for role, value in colors.items():
        if role not in BASE:
            raise ValueError('Unknown theme color: ' + role)
        if not isinstance(value, str) or not re.fullmatch(r'#[0-9a-fA-F]{6}', value):
            raise ValueError('Theme color ' + role + ' must be #RRGGBB')
    return {role: value.lower() for role, value in colors.items()}


def rgb(color):
    return tuple(int(color[i:i + 2], 16) for i in (1, 3, 5))


def mix(first, second, amount):
    return '#' + ''.join(f'{round(a + (b - a) * amount):02x}' for a, b in zip(rgb(first), rgb(second)))


def palette(name, overrides=None):
    if name not in PRESETS:
        raise ValueError('Unknown theme: ' + str(name))
    changes = validate(tomllib.loads((DIRECTORY / (name + '.toml')).read_text()))
    overrides = validate(overrides if overrides is not None else {})
    colors = BASE | changes | overrides
    changed = {role for role in colors if colors[role] != BASE[role]}
    derived = {
        'accent_dim': ('accent', 'background', 0.1),
        'selection': ('background', 'accent', 0.22),
        'shade': ('background', 'accent', 0.1),
        'highlight': ('background', 'foreground', 0.04),
        'diff_add': ('background', 'success', 0.12),
        'diff_remove': ('background', 'error', 0.12),
        'diff_change': ('background', 'warning', 0.12),
        'shadow': ('background', 'background', 0),
        'qt_light': ('surface', 'foreground', 0.12),
        'qt_dark': ('background', 'surface', 0.2),
        'bar_hover': ('background', 'foreground', 0.08),
        'bar_border': ('background', 'foreground', 0.5),
        'disabled': ('background', 'foreground', 0.25),
        'inactive': ('muted', 'muted', 0),
        'code_type': ('blue', 'blue', 0),
    }
    for role, (first, second, amount) in derived.items():
        if {first, second} & changed and role not in overrides:
            colors[role] = mix(colors[first], colors[second], amount)
    for role, source in {
        'terminal_foreground': 'foreground', 'terminal_muted': 'muted',
        'terminal_red': 'error', 'terminal_green': 'success',
        'terminal_yellow': 'warning', 'terminal_blue': 'blue',
        'terminal_purple': 'purple', 'terminal_cyan': 'cyan',
        'terminal_bright_red': 'error', 'terminal_bright_green': 'success',
        'terminal_bright_blue': 'blue', 'terminal_bright_purple': 'purple',
        'terminal_bright_cyan': 'cyan', 'terminal_bright': 'bright',
    }.items():
        if source in changed and role not in overrides:
            colors[role] = colors[source]
    return colors


def selection(home, name=None, overrides=None):
    """Read local preferences; an explicit preset starts with fresh overrides."""
    path = home / '.config/desktop/theme.toml'
    text = path.read_text() if path.exists() else ''
    saved = tomllib.loads(text)
    if set(saved) - {'palette', 'colors'}:
        raise ValueError('theme.toml accepts only palette and [colors]')
    saved_name = saved.get('palette', DEFAULT)
    saved_colors = validate(saved.get('colors', {}))
    selected = name if name is not None else saved_name
    colors = ({} if name is not None else saved_colors) | (overrides or {})
    resolved = palette(selected, colors)
    if not text or name is not None or overrides:
        text = 'palette = "' + selected + '"\n\n[colors]\n'
        text += ''.join(f'{role} = "{value}"\n' for role, value in sorted(validate(colors).items()))
    return resolved, text


# shortcut: source colors must be listed in charcoal-orange.toml; extend it when adding colors.
TOKEN = re.compile(
    r'#[0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?(?![0-9a-fA-F])'
    r'|rgba\([0-9a-fA-F]{8}\)'
    r'|rgba\(\s*\d+,\s*\d+,\s*\d+,\s*[\d.]+\s*\)'
    r'|(?m:(?<==)\d+,\d+,\d+(?=\s*$))'
    r'|38;2;\d+;\d+;\d+'
)


def render(text, colors, qt=False):
    replacements = {value: colors[role] for role, value in BASE.items()}

    def replace(match):
        token = match.group()
        if token.startswith('#'):
            if qt and len(token) == 9:
                return token[:3] + replacements.get('#' + token[3:].lower(), '#' + token[3:])[1:]
            return replacements.get(token[:7].lower(), token[:7]) + token[7:]
        if token.startswith('rgba('):
            body = token[5:-1]
            if ',' not in body:
                return 'rgba(' + replacements.get('#' + body[:6].lower(), '#' + body[:6])[1:] + body[6:] + ')'
            parts = body.split(',')
            original = '#' + ''.join(f'{int(part):02x}' for part in parts[:3])
            if original not in replacements or replacements[original] == original:
                return token
            return 'rgba(' + ', '.join(map(str, rgb(replacements[original]))) + ',' + parts[3] + ')'
        ansi = token.startswith('38;2;')
        separator = ';' if ansi else ','
        body = token[5:] if ansi else token
        original = '#' + ''.join(f'{int(part):02x}' for part in body.split(separator))
        return ('38;2;' if ansi else '') + separator.join(map(str, rgb(replacements.get(original, original))))

    return TOKEN.sub(replace, text)


def render_file(path, colors):
    text = render(path.read_text(), colors, qt='qt' in path.parts)
    if path.name == 'style.css' and colors != BASE:
        start = mix(colors['background'], colors['accent'], 0.18)
        end = colors['background']
        text = text.replace('url("themes/bar-gradient.png")', f'linear-gradient(to right, {start}, {end})')
    return text
