#!/bin/bash

# Match the full command line because the kernel's comm field is truncated
# to 15 characters, which breaks `pgrep -x gpu-screen-recorder`.
if pgrep -f '(^|/)gpu-screen-recorder([[:space:]]|$)' >/dev/null; then
    printf '{"text":" REC","tooltip":"gpu-screen-recorder is running","class":"recording"}\n'
else
    printf '{"text":"","tooltip":"","class":"idle"}\n'
fi
