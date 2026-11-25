#!/usr/bin/env bash
set -u

refresh_waybar_updates() {
  pkill -RTMIN+8 -u "$UID" -x waybar >/dev/null 2>&1 || true
}

if ! command -v checkupdates >/dev/null 2>&1; then
  echo "checkupdates is not installed."
  echo
  read -r -p "Press Enter to exit."
  exit 1
fi

updates="$(checkupdates 2>/dev/null || true)"

if [[ -z "$updates" ]]; then
  refresh_waybar_updates
  echo "No pacman updates available."
  echo
  read -r -p "Press Enter to exit."
  exit 0
fi

echo "Pacman updates:"
echo
printf '%s\n' "$updates"
echo

# read -r -p "Run sudo pacman -Syu? [y/N] " confirm
# case "$confirm" in
#   [yY]|[yY][eE][sS])
#     sudo pacman -Syu
#     ;;
#   *)
#     echo "Cancelled."
#     ;;
# esac

sudo pacman -Syu

# Refresh the count before waiting for the terminal to be closed.
refresh_waybar_updates

echo
read -r -p "Done - Press Enter to exit."
