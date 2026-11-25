#!/usr/bin/env bash

set -u

host_config="$HOME/.config/desktop/host.env"
# shellcheck source=/dev/null
[ ! -r "$host_config" ] || source "$host_config"
iface="${1:-${NETWORK_INTERFACE:-}}"

print_block() {
  printf '%s\n%s\n%s\n' "$1" "$2" "$3"
}

unescape_nm() {
  printf '%s' "$1" | sed 's/\\\\:/:/g; s/\\\\\\\\/\\\\/g'
}

if [ -z "$iface" ] && command -v nmcli >/dev/null 2>&1; then
  iface=$(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null | awk -F: '
    $2 == "wifi" && $3 == "connected" { print $1; found=1; exit }
    $2 == "wifi" && !wifi { wifi=$1 }
    $2 == "ethernet" && $3 == "connected" && !wired { wired=$1 }
    END { if (!found) { if (wired) print wired; else if (wifi) print wifi } }
  ')
fi

if [ -z "$iface" ]; then
  print_block "󰤭" "No Wi-Fi or connected Ethernet interface found" "disconnected"
  exit 0
fi

if ! command -v nmcli >/dev/null 2>&1; then
  print_block "󰤭" "nmcli is not installed" "disconnected"
  exit 0
fi

device_info=$(nmcli -t -e yes -f GENERAL.TYPE,GENERAL.STATE,GENERAL.CONNECTION,IP4.ADDRESS device show "$iface" 2>/dev/null || true)

if [ -z "$device_info" ]; then
  print_block "󰤭" "${iface} is unavailable" "disconnected"
  exit 0
fi

nm_field() {
  local key="$1"
  printf '%s\n' "$device_info" | sed -n "s/^${key}://p" | head -n1
}

device_type=$(nm_field "GENERAL.TYPE")
device_state=$(nm_field "GENERAL.STATE")
connection_name=$(unescape_nm "$(nm_field "GENERAL.CONNECTION")")
ip_address=$(printf '%s\n' "$device_info" | sed -n 's/^IP4.ADDRESS\[[0-9]\+\]://p' | head -n1)
ip_address=${ip_address%%/*}

case "$device_type" in
  wifi)
    wifi_radio=$(nmcli radio wifi 2>/dev/null | tr '[:upper:]' '[:lower:]')

    if [ "$wifi_radio" = "disabled" ]; then
      print_block "󰤭" "Wi-Fi disabled on ${iface}" "disabled"
      exit 0
    fi

    if [[ "$device_state" == 100* ]] || [[ "$device_state" == *"(connected)"* ]]; then
      wifi_info=$(nmcli -t -e yes -f IN-USE,SSID,SIGNAL device wifi list ifname "$iface" 2>/dev/null | awk -F: '$1 == "*" { print; exit }')
      if [ -n "$wifi_info" ]; then
        wifi_info=${wifi_info#*:}
        signal_strength=${wifi_info##*:}
        ssid=$(unescape_nm "${wifi_info%:*}")
      else
        signal_strength=""
        ssid="$connection_name"
      fi

      if [ -n "$ssid" ]; then
        tooltip="$ssid"
      else
        tooltip="Connected on ${iface}"
      fi

      if [ -n "$signal_strength" ]; then
        tooltip="${tooltip} (${signal_strength}%)"
      fi

      print_block "" "$tooltip" "connected"
      exit 0
    fi

    if [[ "$device_state" == *"(connecting)"* ]] || [[ "$device_state" == 40* ]] || [[ "$device_state" == 50* ]]; then
      if [ -n "$connection_name" ]; then
        print_block "" "Connecting to ${connection_name}" "disconnected"
      else
        print_block "" "Connecting on ${iface}" "disconnected"
      fi
      exit 0
    fi

    print_block "󰤭" "Disconnected from ${iface}" "disconnected"
    ;;
  ethernet)
    if [[ "$device_state" == 100* ]] || [[ "$device_state" == *"(connected)"* ]]; then
      if [ -n "$ip_address" ]; then
        print_block "󰈀 ${ip_address}" "${iface} ${ip_address}" "connected"
      else
        print_block "󰈀" "${iface} connected" "connected"
      fi
      exit 0
    fi

    print_block "󰤭" "Disconnected from ${iface}" "disconnected"
    ;;
  *)
    if [[ "$device_state" == 100* ]] || [[ "$device_state" == *"(connected)"* ]]; then
      if [ -n "$connection_name" ]; then
        print_block "$iface" "$connection_name" "connected"
      else
        print_block "$iface" "${iface} connected" "connected"
      fi
      exit 0
    fi

    print_block "󰤭" "Disconnected from ${iface}" "disconnected"
    ;;
esac
