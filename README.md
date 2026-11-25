# Charcoal Orange dotfiles

An Arch Linux / Hyprland desktop with near-black surfaces, warm gray text, orange accents, and a teal brutalist cityscape wallpaper with clean cast-concrete facades. Shared settings live in Git; monitor layouts and hardware overrides stay local to each computer.

Includes Waybar and its calendar/player/Wi-Fi/power controls, Rofi, Dunst, Hyprland, Hyprpaper, Hyprlock, Kitty, GTK/Qt/KDE colors, shell file-listing colors, and the Codex syntax theme.

[Neovim has its own repository](https://github.com/a-tsvil/my-nvim-config); it is deliberately separate. Its Kanagawa Dragon change is already pushed there.

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

Review [optional packages](packages/optional-arch.txt) for Dolphin, Fastfetch, Bluetooth, power profiles, screenshots, brightness keys, and recording. Install the ones this machine needs. `gpu-screen-recorder` availability depends on the repositories configured on the target.

The installer does not install packages, enable services, restart applications, or reload the compositor. It assumes NetworkManager and a working PipeWire/WirePlumber audio session already exist. Enable `NetworkManager`, Bluetooth, or `power-profiles-daemon` as appropriate for that machine. Avoid running two notification daemons or two copies of Waybar from different autostart mechanisms.

After deploying, edit `~/.config/hypr/hyprland.local.lua` for the target's monitors, scaling, and GPU/input settings. The shared fallback uses each monitor's preferred mode and automatic scaling. Then reload Hyprland or log out and back in. A fresh login also ensures already-running terminals and launchers inherit the new Qt environment. If your session launches Hyprland with an explicit `--config`, point it at the Lua file.

For appearance only while keeping the other machine's existing Hyprland keybindings and startup:

```sh
python3 scripts/deploy.py --only waybar kitty rofi dunst gtk qt kde shell codex fastfetch
# Add --apply after reviewing the preview.
```

Copy the border/rounding settings from `stow/hypr/.config/hypr/hyprland.lua` into that machine's compositor config as needed. Its existing keybindings should invoke `~/.config/hypr/scripts/rofi-current-workspace drun` for Super+Space, or call Rofi with `-theme ~/.config/waybar/themes/launcher.rasi`. Set `QT_STYLE_OVERRIDE=Fusion` and `QT_QPA_PLATFORMTHEME=qt6ct` in that session to use the Qt palette. The `rofi` package supplies the launcher helper; the `hypr` package supplies those environment settings when selected.

## What is shared

| Component | Details |
| --- | --- |
| Waybar | 15px outer margins, 3px corners, centered window title, player on the right, Monday-first calendar with ISO week numbers |
| Bar background | Dithered teal-to-dark gradient; PNG is included so it works without regeneration |
| Controls | Matching Rofi application launcher, player, Wi-Fi, Bluetooth, and confirmed power actions |
| Hyprland | Orange active border, dim inactive border, 15px outer gaps, 5px inner gaps, 3px rounding, shared keybindings and animations |
| Notifications / lock | Matching Dunst notification styling and Hyprlock screen; existing PAM authentication defaults |
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

Most configuration files are individual GNU Stow symlinks into `stow/<component>/`; editing them updates the checkout. Review, commit, and push those edits. On the other machine:

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

Deployment tests use temporary home directories and exercise previews, preference preservation, idempotence, restore, symlink-parent protection, and rollback after a simulated Stow failure. Hardware tests cover Wi-Fi/Ethernet selection, host overrides, battery discovery, and desktops without a battery. They do not alter the active desktop.

Asset sources and attribution are in [CREDITS.md](CREDITS.md).
