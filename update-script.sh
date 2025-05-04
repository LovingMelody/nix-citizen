#!/usr/bin/env nix-shell
#! nix-shell -i bash
#! nix-shell -p bash nix-update npins curl jq gnused gnugrep yq-go
nix-update --flake lug-helper

# Update GameGlass

VERSION="$(curl -s https://download.gameglass.gg/hub/latest-linux.yml | yq -r '.version')"
HASH="$(nix-prefetch-url "https://download.gameglass.gg/hub/GameGlass.AppImage")"
SRI_HASH="$(nix hash to-sri --type sha256 "$HASH")"

echo "{\"version\": \"$VERSION\", \"hash\": \"$SRI_HASH\" }" | jq >./pkgs/gameglass/sources.json

npins update

nix fmt
