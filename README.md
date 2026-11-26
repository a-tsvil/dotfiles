# Charcoal Orange dotfiles

An Arch Linux / Hyprland desktop with near-black surfaces, warm gray text, orange accents, and a teal brutalist cityscape wallpaper with weathered cast-concrete facades. Shared settings live in Git; monitor layouts and hardware overrides stay local to each computer.

Includes Waybar and its calendar/player/Wi-Fi/power controls, Rofi, Dunst, Hyprland, Hyprpaper, Hyprlock, Kitty, GTK/Qt/KDE colors, shell file-listing colors, the Codex syntax theme, and an optional SDDM login theme.

Neovim configuration is maintained separately.

## Install on another Arch machine

The compositor configuration uses **Hyprland's Lua API**, tested with **Hyprland 0.57.2**. It cannot be loaded by releases that only support the older `.conf` syntax. The matching Hyprpaper configuration was tested with 0.8.5. See [tested versions](packages/tested-versions.txt).

```sh
git clone git@github.com:a-tsvil/dotfiles.git ~/Projects/dotfiles
cd ~/Projects/dotfiles
sudo pacman -Syu --needed $(cat packages/arch.txt)

# Preview only; no configuration files are changed.
python3 scripts/deploy.py

# Back up conflicts, create Stow links, and merge appearance settings.
python3 scripts/deploy.py --apply
```

The checkout can live anywhere. Deployment defaults to the invoking user's `$HOME`; no username or `/home` prefix is assumed. To target another existing home directory (including paths with spaces), use the same `--home` for preview, apply, and restore:

```sh
python3 scripts/deploy.py --home "/path/to/home"
python3 scripts/deploy.py --home "/path/to/home" --apply
```

Run as the target user, without `sudo`. Runtime scripts resolve that session's `$HOME`. Files use the standard `~/.config`, `~/.local/share`, and `~/.local/state` layout; custom XDG base directories are not currently supported. Generated paths in Qt, Dunst, and Hyprpaper settings use the selected home. Redeploy after moving the home or checkout.

Review [optional packages](packages/optional-arch.txt) for Dolphin, Fastfetch, Bluetooth, power profiles, screenshots, brightness keys, and recording. Install the ones this machine needs. `gpu-screen-recorder` availability depends on the repositories configured on the target.

The installer does not install packages, enable services, restart applications, or reload the compositor. It assumes NetworkManager and a working PipeWire/WirePlumber audio session already exist. Enable `NetworkManager`, Bluetooth, or `power-profiles-daemon` as appropriate for that machine. Avoid running two notification daemons or two copies of Waybar from different autostart mechanisms.

After deploying, edit `~/.config/hypr/hyprland.local.lua` for the target's monitors, scaling, and GPU/input settings. Keyboard input defaults to `us,ru`; override layouts locally as needed. Super+N opens this local file. Application-specific rules and workspace preferences also belong there. The shared fallback uses each monitor's preferred mode and automatic scaling. Then reload Hyprland or log out and back in. A fresh login also ensures already-running terminals and launchers inherit the new Qt environment. If your session launches Hyprland with an explicit `--config`, point it at the Lua file.

For appearance only while keeping the other machine's existing Hyprland keybindings and startup:

```sh
python3 scripts/deploy.py --only waybar kitty rofi dunst gtk qt kde shell codex fastfetch
# Add --apply after reviewing the preview.
```

Copy the border/rounding settings from `stow/hypr/.config/hypr/hyprland.lua` into that machine's compositor config as needed. Its existing keybindings should invoke `~/.config/hypr/scripts/rofi-current-workspace drun` for Super+Space, or call Rofi with `-theme ~/.config/waybar/themes/launcher.rasi`. Set `QT_STYLE_OVERRIDE=Fusion` and `QT_QPA_PLATFORMTHEME=qt6ct` in that session to use the Qt palette. The `rofi` package supplies the launcher helper; the `hypr` package supplies those environment settings when selected.

## Themes

The existing **Charcoal Orange** look remains the default. Five additional dark palettes are included:

| Preset | Background | Accent | Palette source |
| --- | --- | --- | --- |
| `catppuccin-mocha` | `#1e1e2e` | `#cba6f7` | [Catppuccin](https://github.com/catppuccin/palette) |
| `dracula` | `#282a36` | `#bd93f9` | [Dracula](https://github.com/dracula/dracula-theme) |
| `gruvbox-dark` | `#282828` | `#fe8019` | [Gruvbox](https://github.com/morhetz/gruvbox) |
| `nord` | `#2e3440` | `#88c0d0` | [Nord](https://www.nordtheme.com/docs/colors-and-palettes/) |
| `tokyo-night` | `#1a1b26` | `#7aa2f7` | [Tokyo Night](https://github.com/folke/tokyonight.nvim) |

These are desktop adaptations of the source palettes, with derived shades for surfaces, selection, and diff backgrounds. Some muted colors are brightened for readability.

Choose a theme during deployment:

```sh
python3 scripts/deploy.py --theme catppuccin-mocha
python3 scripts/deploy.py --theme catppuccin-mocha --apply
```

Use the separate switcher after installation. It changes colors in installed components without installing missing components or changing their startup, keybindings, or local hardware overrides:

```sh
python3 scripts/theme.py --list-themes
python3 scripts/theme.py --theme nord                   # Preview
python3 scripts/theme.py --theme nord --apply
python3 scripts/theme.py --accent '#a6e3a1' --apply      # Keep the current palette
python3 scripts/theme.py --background '#141414' --foreground '#eeeeee' --apply
python3 scripts/theme.py --theme charcoal-orange --apply
```

Both scripts support `--home`, `--only`, and the existing backup/restore flow. Selecting `--theme` resets previous color overrides. Omitting it retains the saved palette and overrides. With `--only`, only the named components are updated; a later full deployment applies the saved choice to the others.

Preferences are stored per machine in `~/.config/desktop/theme.toml` and survive subsequent deployments. To customize additional colors, edit its `[colors]` table and run `python3 scripts/theme.py --apply`:

```toml
palette = "nord"

[colors]
accent = "#88c0d0"
background = "#2e3440"
foreground = "#d8dee9"
surface = "#3b4252"
border = "#4c566a"
muted = "#a5b0c2"
success = "#a3be8c"
warning = "#ebcb8b"
error = "#bf616a"
```

All colors must be six-digit `#RRGGBB` values. The full set of available roles is listed in [`themes/charcoal-orange.toml`](themes/charcoal-orange.toml); preset definitions are in [`themes/`](themes/). Accent shades and related terminal colors are derived automatically unless explicitly overridden.

Colors cover Waybar (including the calendar), Rofi, Hyprland borders, Hyprlock, Dunst, Kitty, GTK 3/4, Qt 5/6, KDE, shell file listings, and the Codex syntax theme. The wallpaper is retained. Other presets use a matching CSS bar gradient; the original default keeps its dithered PNG. GTK applications that ignore custom CSS can retain their own styling.

Color-customized files are generated in the target home instead of linked, keeping other machines and the checkout unchanged. Unchanged files remain Stow links. Existing filenames and scheme IDs (`CharcoalOrange` / `charcoal-orange`) stay stable so application references keep working. Edit shared layouts in the checkout and redeploy to regenerate customized files.

Applications are not restarted automatically. Reload Hyprland, restart Waybar and Dunst, reload Kitty's config, and reopen GTK/Qt applications as needed. Source `~/.config/shell/colors.sh` to refresh an existing shell. Codex may need its theme reselected or a new session.

## What is shared

| Component | Details |
| --- | --- |
| Waybar | 15px outer margins, 3px corners, centered window title, player on the right, Monday-first calendar with ISO week numbers |
| Bar background | Dithered amber-to-teal-to-dark gradient; PNG is included so it works without regeneration |
| Controls | Matching Rofi application launcher, player, Wi-Fi, Bluetooth, and confirmed power actions |
| Hyprland | Orange active border, dim inactive border, 15px outer gaps, 5px inner gaps, 3px rounding, shared keybindings and animations |
| Notifications / lock | Matching Dunst styling and a sharp pixel-art Hyprlock background; existing PAM authentication defaults |
| Login | [Charcoal City SDDM preset](settings/sddm/README.md) with the same pixel-art wallpaper, windblown leaves and blinking beacons; installed separately with administrator privileges |
| Kitty | Charcoal Orange with distinct, higher-contrast ANSI hues, 85% background opacity, and IosevkaTerm Nerd Font at 14.5pt |
| File listings | Orange directories, green executables, underlined symlinks, amber archives, dim logs/backups; only a small shell snippet is sourced |
| Fastfetch | Standard information modules; colors inherit Kitty's palette |
| GTK / Qt / KDE | Appearance entries are merged into existing settings. The explicit KDE `UiSettings/ColorScheme` prevents Dolphin from falling back to Breeze Light |
| Codex | Custom `charcoal-orange.tmTheme` and only the `tui.theme` setting; other Codex settings are preserved |

The original laptop's display EDID/serial, Intel-specific overrides, hard-coded DPI, work apps, credentials, bookmarks, histories, generated plugin directories, backups, and obsolete wallpaper variants are excluded. The repo contains no full Zsh or Codex configuration.

## Local hardware overrides

The installer creates these files **only when absent**, and does not link them into Git:

- `~/.config/hypr/hyprland.local.lua`: monitor layout, scaling, GPU variables, input devices, per-monitor workspaces, and extra local startup hooks.
- `~/.config/desktop/host.env`: optional `NETWORK_INTERFACE` and `BATTERY_NAME`. By default, the bar prefers connected Wi-Fi, then connected Ethernet, then the first Wi-Fi device; it discovers a battery from `/sys/class/power_supply`. `host.env` is sourced as trusted local Bash configuration.
- `~/.config/desktop/waybar-host.jsonc`: Waybar options omitted from the shared bar config. For example, `{"output": ["DP-1"]}` limits the bar to that output. The default is all outputs. Waybar's first-defined-value rule applies: shared options take precedence over the include.

Theme preferences are stored separately in `~/.config/desktop/theme.toml`; only explicit theme/color options change those preferences during deployment.

Use `hyprctl monitors`, `nmcli device status`, and `/sys/class/power_supply` to identify local hardware. Host examples are in [`examples/`](examples/).

## Backups and rollback

Every deployment that changes files saves their previous state under:

```text
~/.local/state/dotfiles/backups/<timestamp>/
```

The backup mirrors paths relative to your home and includes a manifest for files that did not previously exist. Existing preferences and comments in mixed INI files are retained. The installer writes Codex's selected theme without replacing its other settings. Failed installations roll back the files they touched automatically.

Restore one deployment with:

```sh
python3 scripts/deploy.py --apply --restore ~/.local/state/dotfiles/backups/<timestamp>
```

This replaces the files listed in that backup with their previous versions, removing files introduced by that deployment. Preserve any later edits you want to keep before restoring. Unrelated files are not restored or removed.

A symlinked parent directory, such as `~/.config/kitty` pointing to another repository, stops deployment for manual review. This prevents writing through another dotfiles checkout. Keep the cloned repository in its final location because Stow links point into it.

## Keep machines synchronized

Uncustomized configuration files are individual GNU Stow symlinks into `stow/<component>/`; editing them updates the checkout. Files with customized colors are generated: edit their shared source in the checkout and redeploy. Review, commit, and push source edits. On the other machine:

```sh
cd ~/Projects/dotfiles
git pull --ff-only
python3 scripts/deploy.py
python3 scripts/deploy.py --apply
```

Files with mixed personal and appearance settings are merged from `settings/` at deployment time instead of being linked wholesale. To sync changes to those managed appearance values, edit the relevant source fragment in `settings/` and deploy again. Dunst and Hyprpaper are generated from `.in` files to insert the current user's home path. Local overrides are never overwritten on subsequent runs.

Use `source ~/.config/shell/colors.sh` in an existing Zsh terminal to refresh file-listing colors; new shells load the snippet automatically. Reload Kitty's configuration or open a new terminal after palette changes. Dynamic background opacity is enabled for future adjustments; reopen windows that originally started without it to apply the opacity setting. Existing Codex sessions may need `/theme` to select `charcoal-orange`.

## Validate

With Python 3.11+, GNU Stow, and Lua installed:

```sh
python3 -m unittest discover -s tests -v
python3 scripts/check.py
```

Deployment tests use temporary home directories and exercise previews, preference preservation, idempotence, restore, symlink-parent protection, alternate homes with spaces, local override preservation, and rollback after a simulated Stow failure. Hardware tests cover Wi-Fi/Ethernet selection, host overrides, battery discovery, and desktops without a battery. They do not alter the active desktop.

Theme tests install every preset, check the supported color formats and transparency, and exercise the separate switcher, saved overrides, resetting to the default, and rollback. The default palette is checked against every shared text file to preserve the existing look exactly.

Asset sources and attribution are in [CREDITS.md](CREDITS.md).
