#!/usr/bin/env bash

set -euo pipefail

script="${1:?Usage: rofi-single-click-wrapper.sh <script> [args...]}"
shift

rofi() {
  command rofi -me-select-entry '' -me-accept-entry MousePrimary "$@"
}

# shellcheck source=/dev/null
source "$script" "$@"
