#!/usr/bin/env nix-shell
#! nix-shell -i bash
#! nix-shell -p bash nix-update npins curl jq gnused gnugrep yq-go
nix-update --flake lug-helper
# RSI Launcher
./pkgs/rsi-launcher/update.sh
# GameGlass
./pkgs/gameglass/update.sh
# lug-wine-bin
./pkgs/lug-wine-bin/update.sh

npins update

nix fmt
