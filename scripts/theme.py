#!/usr/bin/env python3
"""Switch the palette of installed dotfiles without installing other components."""
from deploy import cli

if __name__ == '__main__':
    cli(theme_only=True)
