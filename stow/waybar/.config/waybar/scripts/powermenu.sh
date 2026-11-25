#!/usr/bin/env bash

set -u

theme="$HOME/.config/waybar/themes/powermenu.rasi"
confirm_theme="$HOME/.config/waybar/themes/power-confirm.rasi"

shutdown='  Shut down'
reboot='  Restart'
lock='  Lock screen'
suspend='  Suspend'
logout='  Log out'
yes='Confirm'
no='Cancel'

rofi_cmd() {
  local uptime_value

  uptime_value=$(uptime -p 2>/dev/null | sed 's/^up //')

  rofi -dmenu \
    -p "Power" \
    -mesg "Uptime: ${uptime_value:-unknown}" \
    -theme "$theme"
}

confirm_cmd() {
  local message
  case "$1" in
    --shutdown) message='Shut down this computer?' ;;
    --reboot) message='Restart this computer?' ;;
    --suspend) message='Suspend this computer?' ;;
    --logout) message='Log out of this session?' ;;
    *) return 1 ;;
  esac

  rofi \
    -dmenu \
    -p 'Confirmation' \
    -mesg "$message" \
    -selected-row 0 \
    -u 1 \
    -theme "$confirm_theme"
}

confirm_exit() {
  printf '%s\n' "$no" "$yes" | confirm_cmd "$1"
}

run_rofi() {
  printf '%s\n' "$lock" "$suspend" "$logout" "$reboot" "$shutdown" | rofi_cmd
}

lock_session() {
  if command -v playerctl >/dev/null 2>&1; then
    playerctl --all-players pause >/dev/null 2>&1 || true
  fi

  if command -v hyprlock >/dev/null 2>&1; then
    hyprlock
    return $?
  fi

  if [ -n "${XDG_SESSION_ID:-}" ]; then
    loginctl lock-session "${XDG_SESSION_ID}"
    return $?
  fi

  loginctl lock-session
}

suspend_session() {
  if command -v playerctl >/dev/null 2>&1; then
    playerctl --all-players pause >/dev/null 2>&1 || true
  fi

  if command -v hyprlock >/dev/null 2>&1; then
    hyprlock >/dev/null 2>&1 &
    sleep 0.5
  elif [ -n "${XDG_SESSION_ID:-}" ]; then
    loginctl lock-session "${XDG_SESSION_ID}" >/dev/null 2>&1 || true
  fi

  systemctl suspend
}

logout_session() {
  case "${XDG_SESSION_DESKTOP:-${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}}" in
    Hyprland|hyprland)
      if command -v hyprctl >/dev/null 2>&1; then
        hyprctl eval 'hl.dispatch(hl.dsp.exit())'
        return $?
      fi
      ;;
  esac

  if [ -n "${XDG_SESSION_ID:-}" ]; then
    loginctl terminate-session "${XDG_SESSION_ID}"
    return $?
  fi

  return 1
}

run_cmd() {
  local selection

  selection=$(confirm_exit "$1")
  if [ "$selection" != "$yes" ]; then
    return 0
  fi

  case "$1" in
    --shutdown)
      systemctl poweroff
      ;;
    --reboot)
      systemctl reboot
      ;;
    --suspend)
      suspend_session
      ;;
    --logout)
      logout_session
      ;;
  esac
}

case "$(run_rofi)" in
  "$shutdown")
    run_cmd --shutdown
    ;;
  "$reboot")
    run_cmd --reboot
    ;;
  "$lock")
    lock_session
    ;;
  "$suspend")
    run_cmd --suspend
    ;;
  "$logout")
    run_cmd --logout
    ;;
esac
