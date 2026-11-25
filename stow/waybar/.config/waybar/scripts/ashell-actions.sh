#!/usr/bin/env bash

set -u

notify() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "Waybar" "$1"
  fi
}

launch() {
  "$@" >/dev/null 2>&1 &
}

try_launch() {
  if command -v "$1" >/dev/null 2>&1; then
    launch "$@"
    return 0
  fi

  return 1
}

open_in_terminal() {
  if command -v kitty >/dev/null 2>&1; then
    launch kitty -e "$@"
    return 0
  fi

  if command -v alacritty >/dev/null 2>&1; then
    launch alacritty -e "$@"
    return 0
  fi

  if command -v foot >/dev/null 2>&1; then
    launch foot -e "$@"
    return 0
  fi

  return 1
}

audio_output() {
  try_launch pavucontrol -t 3 && return 0
  try_launch pwvucontrol && return 0
  try_launch helvum && return 0
  notify "No audio output control app found."
  return 1
}

audio_input() {
  try_launch pavucontrol -t 4 && return 0
  try_launch pwvucontrol && return 0
  try_launch helvum && return 0
  notify "No audio input control app found."
  return 1
}

audio_mute() {
  if command -v pactl >/dev/null 2>&1; then
    pactl set-sink-mute @DEFAULT_SINK@ toggle
    return 0
  fi

  if command -v wpctl >/dev/null 2>&1; then
    wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    return 0
  fi

  notify "No audio mute command found."
  return 1
}

network_settings() {
  try_launch nm-connection-editor && return 0

  if command -v nmtui >/dev/null 2>&1 && open_in_terminal nmtui; then
    return 0
  fi

  notify "No network settings app found."
  return 1
}

bluetooth_manager() {
  try_launch blueman-manager && return 0
  try_launch blueberry && return 0

  if command -v bluetoothctl >/dev/null 2>&1 && open_in_terminal bluetoothctl; then
    return 0
  fi

  notify "No bluetooth control app found."
  return 1
}

bluetooth_toggle() {
  if ! command -v bluetoothctl >/dev/null 2>&1; then
    notify "bluetoothctl is not installed."
    return 1
  fi

  local powered
  powered=$(bluetoothctl show 2>/dev/null | awk '/Powered:/ { print $2; exit }')

  case "$powered" in
    yes)
      bluetoothctl power off >/dev/null 2>&1
      notify "Bluetooth disabled."
      ;;
    no)
      bluetoothctl power on >/dev/null 2>&1
      notify "Bluetooth enabled."
      ;;
    *)
      notify "No bluetooth controller available."
      return 1
      ;;
  esac
}

case "${1:-}" in
  audio-output)
    audio_output
    ;;
  audio-input)
    audio_input
    ;;
  audio-mute)
    audio_mute
    ;;
  network)
    network_settings
    ;;
  bluetooth-manager)
    bluetooth_manager
    ;;
  bluetooth-toggle)
    bluetooth_toggle
    ;;
  *)
    notify "Unknown action: ${1:-missing}"
    exit 1
    ;;
esac
