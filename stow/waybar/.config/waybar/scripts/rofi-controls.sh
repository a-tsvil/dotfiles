#!/usr/bin/env bash

set -u
host_config="$HOME/.config/desktop/host.env"
# shellcheck source=/dev/null
[ ! -r "$host_config" ] || source "$host_config"

theme="$HOME/.config/waybar/themes/controls.rasi"

notify() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "Waybar" "$1"
  fi
}

refresh_network_module() {
  if command -v pkill >/dev/null 2>&1; then
    pkill -RTMIN+9 waybar >/dev/null 2>&1 || true
  fi
}

rofi_menu() {
  local prompt="$1"
  local message="$2"
  local width="$3"
  local columns="$4"
  local lines="$5"
  local icon

  case "$prompt" in
    Player)
      icon=''
      ;;
    Network|Wi-Fi) icon='' ;;
    Bluetooth) icon='' ;;
    Audio) icon='󰕾' ;;
    *) icon='󰍜' ;;
  esac

  rofi \
    -dmenu \
    -i \
    -p "$prompt" \
    -mesg "$message" \
    -theme "$theme" \
    -theme-str "window { width: ${width}; }" \
    -theme-str "listview { columns: ${columns}; lines: ${lines}; }" \
    -theme-str "textbox-prompt-colon { str: \"${icon}\"; }"
}

prompt_input() {
  local prompt="$1"
  shift

  rofi \
    -dmenu \
    -p "$prompt" \
    -theme "$theme" \
    -theme-str 'window { width: 420px; }' \
    -theme-str 'mainbox { children: [ "inputbar" ]; }' \
    -theme-str 'inputbar { border: 0; padding: 0; }' \
    -theme-str 'entry { placeholder: "Type here…"; }' \
    -theme-str 'textbox-prompt-colon { str: "󰌾"; }' \
    "$@"
}

volume_bar() {
  local value="$1"
  local filled empty blocks

  value=${value%\%}
  case "$value" in
    ''|*[!0-9]*)
      printf '------------'
      return 0
      ;;
  esac

  if [ "$value" -lt 0 ]; then
    value=0
  elif [ "$value" -gt 150 ]; then
    value=150
  fi

  blocks=$(( (value + 6) / 12 ))
  if [ "$blocks" -gt 12 ]; then
    blocks=12
  fi
  filled=$(printf '%*s' "$blocks" '' | tr ' ' '█')
  empty=$(printf '%*s' $((12 - blocks)) '' | tr ' ' '░')
  printf '%s%s' "$filled" "$empty"
}

run_audio_menu() {
  local sink_volume source_volume sink_muted source_muted

  sink_volume=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | awk 'NR==1 { print $5; exit }')
  source_volume=$(pactl get-source-volume @DEFAULT_SOURCE@ 2>/dev/null | awk 'NR==1 { print $5; exit }')
  sink_muted=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '{ print $2; exit }')
  source_muted=$(pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null | awk '{ print $2; exit }')

  sink_volume=${sink_volume:-n/a}
  source_volume=${source_volume:-n/a}
  sink_muted=${sink_muted:-unknown}
  source_muted=${source_muted:-unknown}

  local prompt message chosen
  prompt="Audio"
  message="Out $(volume_bar "$sink_volume") ${sink_volume} (${sink_muted})\nMic $(volume_bar "$source_volume") ${source_volume} (${source_muted})"

  chosen=$(
    printf '%s\n' \
      "󰕾  Output +5%" \
      "󰁆  Output -5%" \
      "󰝟  Toggle output mute" \
      "  Toggle mic mute" \
      "󰎈  Set output level" \
      "󰓃  Output settings" \
      "󰍬  Input settings" | \
      rofi_menu "$prompt" "$message" "420px" 2 4
  )

  case "$chosen" in
    "󰕾  Output +5%")
      pactl set-sink-volume @DEFAULT_SINK@ +5%
      ;;
    "󰁆  Output -5%")
      pactl set-sink-volume @DEFAULT_SINK@ -5%
      ;;
    "󰝟  Toggle output mute")
      pactl set-sink-mute @DEFAULT_SINK@ toggle
      ;;
    "  Toggle mic mute")
      pactl set-source-mute @DEFAULT_SOURCE@ toggle
      ;;
    "󰎈  Set output level")
      local target
      target=$(printf '' | prompt_input "Volume %")
      case "$target" in
        ''|*[!0-9]*)
          ;;
        *)
          if [ "$target" -gt 150 ]; then
            target=150
          fi
          pactl set-sink-volume @DEFAULT_SINK@ "${target}%"
          ;;
      esac
      ;;
    "󰓃  Output settings")
      "$HOME/.config/waybar/scripts/ashell-actions.sh" audio-output
      ;;
    "󰍬  Input settings")
      "$HOME/.config/waybar/scripts/ashell-actions.sh" audio-input
      ;;
  esac
}

radio_state() {
  nmcli radio wifi 2>/dev/null | tr '[:upper:]' '[:lower:]'
}

wifi_device() {
  if [ -n "${NETWORK_INTERFACE:-}" ] && nmcli -t -f DEVICE,TYPE device status 2>/dev/null | grep -Fxq "${NETWORK_INTERFACE}:wifi"; then
    printf '%s\n' "$NETWORK_INTERFACE"
    return
  fi
  nmcli -t -f DEVICE,TYPE device status 2>/dev/null | awk -F: '$2 == "wifi" { print $1; exit }'
}

active_wifi() {
  nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | awk -F: '$2 == "802-11-wireless" { print $1; exit }'
}

available_wifi_entries() {
  nmcli -t -e yes -f IN-USE,SSID,SIGNAL,SECURITY device wifi list 2>/dev/null | while IFS=: read -r in_use ssid signal security; do
    ssid=${ssid//\\:/\:}
    [ -n "$ssid" ] || continue

    local marker icon
    marker=" "
    [ "$in_use" = "*" ] && marker="•"

    if [ "$security" = "--" ] || [ -z "$security" ]; then
      security="open"
    fi

    printf '%s\t%s\t%s%%\t%s\n' "$marker" "$ssid" "${signal:-0}" "$security"
  done
}

connect_wifi_menu() {
  local device entries chosen ssid security password

  device=$(wifi_device)
  if [ -z "$device" ]; then
    notify "No Wi-Fi device found."
    return 1
  fi

  entries=$(available_wifi_entries)
  if [ -z "$entries" ]; then
    notify "No Wi-Fi networks found."
    return 1
  fi

  chosen=$(printf '%s\n' "$entries" | rofi_menu "Wi-Fi" "Choose a network" "520px" 1 8)
  [ -n "$chosen" ] || return 0

  IFS=$'\t' read -r _ ssid _ security <<EOF
$chosen
EOF

  if [ "$security" = "open" ]; then
    nmcli device wifi connect "$ssid" ifname "$device"
    status=$?
    refresh_network_module
    return $status
  fi

  password=$(printf '' | prompt_input "Password" -password)
  [ -n "$password" ] || return 0

  nmcli device wifi connect "$ssid" password "$password" ifname "$device"
  status=$?
  refresh_network_module
  return $status
}

run_network_menu() {
  local wifi_state current_network chosen

  wifi_state=$(radio_state)
  current_network=$(active_wifi)

  if [ -n "$current_network" ]; then
    current_network="Connected: ${current_network}"
  else
    current_network="Connected: none"
  fi

  chosen=$(
    printf '%s\n' \
      "󰖩  Toggle Wi-Fi (${wifi_state:-unknown})" \
      "󰤨  Scan and connect" \
      "󰌾  Disconnect current" \
      "󰒓  Advanced settings" | \
      rofi_menu "Network" "$current_network" "420px" 1 4
  )

  case "$chosen" in
    "󰖩  Toggle Wi-Fi (enabled)")
      nmcli radio wifi off
      refresh_network_module
      ;;
    "󰖩  Toggle Wi-Fi (disabled)")
      nmcli radio wifi on
      refresh_network_module
      ;;
    "󰤨  Scan and connect")
      connect_wifi_menu
      ;;
    "󰌾  Disconnect current")
      if [ -n "$current_network" ] && [ "$current_network" != "Connected: none" ]; then
        nmcli connection down "${current_network#Connected: }"
        refresh_network_module
      else
        notify "No active Wi-Fi connection."
      fi
      ;;
    "󰒓  Advanced settings")
      "$HOME/.config/waybar/scripts/ashell-actions.sh" network
      ;;
  esac
}

bluetooth_power_state() {
  bluetoothctl show 2>/dev/null | awk '/Powered:/ { print tolower($2); exit }'
}

bluetooth_connected_name() {
  bluetoothctl devices Connected 2>/dev/null | sed -n '1s/^Device [^ ]* //p'
}

bluetooth_device_entries() {
  local devices

  devices=$(bluetoothctl devices Paired 2>/dev/null)
  if [ -z "$devices" ]; then
    devices=$(bluetoothctl devices 2>/dev/null)
  fi

  printf '%s\n' "$devices" | while IFS= read -r line; do
    [ -n "$line" ] || continue

    local mac name icon
    mac=$(printf '%s\n' "$line" | awk '{ print $2 }')
    name=$(printf '%s\n' "$line" | cut -d' ' -f3-)
    [ -n "$mac" ] || continue

    if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
      icon="󰂱"
    else
      icon="󰂯"
    fi

    printf '%s\t%s\t%s\n' "$icon" "$name" "$mac"
  done
}

connect_bluetooth_menu() {
  local entries chosen mac

  entries=$(bluetooth_device_entries)
  if [ -z "$entries" ]; then
    notify "No known bluetooth devices."
    return 1
  fi

  chosen=$(printf '%s\n' "$entries" | rofi_menu "Bluetooth" "Choose a device" "520px" 1 8)
  [ -n "$chosen" ] || return 0

  IFS=$'\t' read -r _ _ mac <<EOF
$chosen
EOF

  [ -n "$mac" ] || return 1

  if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
    bluetoothctl disconnect "$mac"
  else
    bluetoothctl connect "$mac"
  fi
}

run_bluetooth_menu() {
  local bt_state connected chosen

  bt_state=$(bluetooth_power_state)
  connected=$(bluetooth_connected_name)

  if [ -n "$connected" ]; then
    connected="Connected: ${connected}"
  else
    connected="Connected: none"
  fi

  chosen=$(
    printf '%s\n' \
      "  Toggle bluetooth (${bt_state:-unknown})" \
      "󰂱  Connect or disconnect device" \
      "󰂲  Disconnect current device" \
      "󰒓  Advanced settings" | \
      rofi_menu "Bluetooth" "$connected" "420px" 1 4
  )

  case "$chosen" in
    "  Toggle bluetooth (yes)")
      bluetoothctl power off
      ;;
    "  Toggle bluetooth (no)")
      bluetoothctl power on
      ;;
    "󰂱  Connect or disconnect device")
      connect_bluetooth_menu
      ;;
    "󰂲  Disconnect current device")
      if [ -n "$connected" ] && [ "$connected" != "Connected: none" ]; then
        local device_mac
        device_mac=$(bluetoothctl devices Connected 2>/dev/null | awk 'NR==1 { print $2; exit }')
        if [ -n "$device_mac" ]; then
          bluetoothctl disconnect "$device_mac"
        fi
      else
        notify "No connected bluetooth device."
      fi
      ;;
    "󰒓  Advanced settings")
      "$HOME/.config/waybar/scripts/ashell-actions.sh" bluetooth-manager
      ;;
  esac
}

player_status() {
  playerctl status 2>/dev/null | tr '[:upper:]' '[:lower:]'
}

player_track() {
  playerctl metadata --format '{{ title }}' 2>/dev/null
}

player_artist() {
  playerctl metadata --format '{{ artist }}' 2>/dev/null
}

run_player_menu() {
  if ! command -v playerctl >/dev/null 2>&1; then
    notify "playerctl is not installed."
    return 1
  fi

  local status title artist message chosen
  status=$(player_status)
  title=$(player_track)
  artist=$(player_artist)

  if [ -z "$title" ] && [ -z "$artist" ]; then
    message="No active media player"
  elif [ -n "$artist" ]; then
    message="${artist} - ${title}"
  else
    message="${title}"
  fi

  if [ -n "$status" ]; then
    message="${message}"$'\n'"${status^}"
  fi

  chosen=$(
    printf '%s\n' \
      "󰒮  Previous" \
      "󰐎  Play / Pause" \
      "󰒭  Next" \
      "󰓃  Open pavucontrol" | \
      rofi_menu "Player" "$message" "480px" 2 2
  )

  case "$chosen" in
    "󰒮  Previous")
      playerctl previous
      ;;
    "󰐎  Play / Pause")
      playerctl play-pause
      ;;
    "󰒭  Next")
      playerctl next
      ;;
    "󰓃  Open pavucontrol")
      pavucontrol -t 1 >/dev/null 2>&1 &
      ;;
  esac
}

case "${1:-}" in
  audio-menu)
    run_audio_menu
    ;;
  bluetooth-menu)
    run_bluetooth_menu
    ;;
  network-menu)
    run_network_menu
    ;;
  player-menu)
    run_player_menu
    ;;
  *)
    notify "Unknown rofi control: ${1:-missing}"
    exit 1
    ;;
esac
