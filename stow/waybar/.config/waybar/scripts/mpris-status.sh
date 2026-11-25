#!/usr/bin/env bash

set -u

trim_text() {
  local text="$1"
  local limit="$2"

  if [ "${#text}" -le "$limit" ]; then
    printf '%s' "$text"
    return 0
  fi

  printf '%s...' "${text:0:limit-3}"
}

json_escape() {
  local text="$1"

  text=${text//\\/\\\\}
  text=${text//\"/\\\"}
  text=${text//$'\n'/\\n}
  text=${text//$'\r'/}
  text=${text//$'\t'/ }

  printf '%s' "$text"
}

print_json() {
  local text="$1"
  local tooltip="$2"
  local class_name="$3"

  printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' \
    "$(json_escape "$text")" \
    "$(json_escape "$tooltip")" \
    "$(json_escape "$class_name")"
}

status_of() {
  local player="$1"
  playerctl -p "$player" status 2>/dev/null || true
}

metadata_of() {
  local player="$1"
  playerctl -p "$player" metadata "$2" 2>/dev/null || true
}

if ! command -v playerctl >/dev/null 2>&1; then
  print_json "" "" "idle"
  exit 0
fi

mapfile -t players < <(playerctl -l 2>/dev/null | awk '!seen[$0]++')

if [ "${#players[@]}" -eq 0 ]; then
  print_json "" "" "idle"
  exit 0
fi

selected_player=""
selected_status=""

for player in "${players[@]}"; do
  status=$(status_of "$player")

  case "$status" in
    Playing)
      selected_player="$player"
      selected_status="$status"
      break
      ;;
    Paused)
      if [ -z "$selected_player" ]; then
        selected_player="$player"
        selected_status="$status"
      fi
      ;;
    Stopped)
      if [ -z "$selected_player" ]; then
        selected_player="$player"
        selected_status="$status"
      fi
      ;;
  esac
done

if [ -z "$selected_player" ]; then
  print_json "" "" "idle"
  exit 0
fi

player_name=$(metadata_of "$selected_player" "mpris:identity")
artist=$(metadata_of "$selected_player" "xesam:artist")
title=$(metadata_of "$selected_player" "xesam:title")

if [ -n "$artist" ] && [ -n "$title" ]; then
  track="${artist} - ${title}"
elif [ -n "$title" ]; then
  track="$title"
elif [ -n "$artist" ]; then
  track="$artist"
else
  track="${player_name:-$selected_player}"
fi

case "$selected_status" in
  Playing)
    icon="󰐊"
    class_name="playing"
    ;;
  Paused)
    icon="󰏤"
    class_name="paused"
    ;;
  *)
    icon="󰓛"
    class_name="stopped"
    ;;
esac

display_track=$(trim_text "$track" 28)

if [ -n "$player_name" ]; then
  tooltip="${player_name}: ${track}"
else
  tooltip="$track"
fi

print_json "${icon} ${display_track}" "$tooltip" "$class_name"
