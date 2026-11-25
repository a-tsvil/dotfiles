#!/usr/bin/env bash

set -u

host_config="$HOME/.config/desktop/host.env"
# shellcheck source=/dev/null
[ ! -r "$host_config" ] || source "$host_config"
battery_name="${1:-${BATTERY_NAME:-}}"
if [ -z "$battery_name" ]; then
  for supply in /sys/class/power_supply/*; do
    [ -r "$supply/type" ] || continue
    if [ "$(cat "$supply/type")" = "Battery" ]; then
      battery_name="${supply##*/}"
      break
    fi
  done
fi
battery_dir="/sys/class/power_supply/${battery_name:-not-present}"

print_block() {
  printf '%s\n%s\n%s\n' "$1" "$2" "$3"
}

read_value() {
  local path="$1"
  if [ -r "$path" ]; then
    sed -n '1p' "$path"
  fi
}

detect_ac_state() {
  local supply type online

  for supply in /sys/class/power_supply/*; do
    [ -d "$supply" ] || continue

    type=$(read_value "$supply/type")
    case "$type" in
      Mains|USB|USB_C|USB_PD)
        online=$(read_value "$supply/online")
        case "$online" in
          1)
            printf 'online'
            return 0
            ;;
        esac
        ;;
    esac
  done

  printf 'offline'
}

battery_icon() {
  local capacity="$1"

  if [ "$capacity" -ge 95 ]; then
    printf '󰁹'
  elif [ "$capacity" -ge 85 ]; then
    printf '󰂂'
  elif [ "$capacity" -ge 75 ]; then
    printf '󰂁'
  elif [ "$capacity" -ge 65 ]; then
    printf '󰂀'
  elif [ "$capacity" -ge 55 ]; then
    printf '󰁿'
  elif [ "$capacity" -ge 45 ]; then
    printf '󰁾'
  elif [ "$capacity" -ge 35 ]; then
    printf '󰁽'
  elif [ "$capacity" -ge 25 ]; then
    printf '󰁼'
  elif [ "$capacity" -ge 15 ]; then
    printf '󰁻'
  else
    printf '󰁺'
  fi
}

if [ ! -d "$battery_dir" ]; then
  print_block "" "No battery detected" "missing"
  exit 0
fi

capacity=$(read_value "$battery_dir/capacity")
status=$(read_value "$battery_dir/status")
ac_state=$(detect_ac_state)

case "${capacity:-}" in
  ''|*[!0-9]*)
    capacity=0
    ;;
esac

status=${status:-Unknown}

class_name="discharging"
icon=$(battery_icon "$capacity")
tooltip="${battery_name} • ${status}"

case "$status" in
  Charging)
    class_name="charging"
    icon="󰂄"
    ;;
  Full)
    class_name="plugged"
    ;;
  "Not charging")
    if [ "$ac_state" = "online" ]; then
      class_name="plugged"
    fi
    ;;
esac

if [ "$class_name" != "charging" ] && [ "$class_name" != "plugged" ]; then
  if [ "$capacity" -le 10 ]; then
    class_name="critical"
  elif [ "$capacity" -le 20 ]; then
    class_name="warning"
  fi
fi

if [ "$ac_state" = "online" ]; then
  tooltip="${tooltip} • AC"
fi

print_block "${icon} ${capacity}%" "$tooltip" "$class_name"
