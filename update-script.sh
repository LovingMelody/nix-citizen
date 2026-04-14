#!/usr/bin/env nix-shell
#! nix-shell -i bash
#! nix-shell -p bash nix-update npins curl gnused gnugrep jaq
nix-update --flake lug-helper
# RSI Launcher
./pkgs/rsi-launcher/update.sh
# GameGlass
./pkgs/gameglass/update.sh
# lug-wine-bin
./pkgs/lug-wine-bin/update.sh

# Compattools
./pkgs/steamcompattools/update.sh

npins update

# Update wine-astral sources
# This has to be done after pins are updated
./pkgs/wine-astral/update.sh

nix fmt
