#!/usr/bin/env sh
set -eu

# Query the current keyboard instead of parsing layout events, which may also
# come from headphones and other devices registered as keyboards.
devices=$(hyprctl devices -j 2>/dev/null) || {
  printf '%s\n' '{"text":"--","tooltip":"Keyboard layout unavailable"}'
  exit 0
}

printf '%s\n' "$devices" | jq -c '
  (.keyboards // []) |
  (first(.[] | select(.main == true)) // .[0]) |
  if . == null then
    {text: "--", tooltip: "No keyboard connected"}
  else
    ((.layout // "" | split(","))[.active_layout_index // 0] // "") as $code |
    {
      text: (if $code == "" then "--" else $code | ascii_upcase end),
      tooltip: (.active_keymap // $code)
    }
  end
'
