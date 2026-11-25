# Source after framework/theme initialization in ~/.zshrc or ~/.bashrc.
if command -v dircolors >/dev/null 2>&1 && [ -r "$HOME/.config/shell/dircolors" ]; then
    eval "$(dircolors -b "$HOME/.config/shell/dircolors")"
    alias ls='ls --color=auto'
fi
