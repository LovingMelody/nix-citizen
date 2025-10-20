#!/usr/bin/env nix-shell
#! nix-shell -i bash -p curl yq-go jq

INFO="pkgs/rsi-launcher/info.json"

VERSION="$(curl -s 'https://install.robertsspaceindustries.com/rel/2/latest.yml' | yq -r '.version')"

# If it's the same as current, skip other steps
if [ "$VERSION" == "$(nix eval .\#rsi-launcher.version --raw)" ]; then
  exit 0
fi

url="https://install.robertsspaceindustries.com/rel/2/RSI%20Launcher-Setup-$VERSION.exe"

HASH="$(nix store prefetch-file "$url" --name "RSI-Launcher-Setup-$VERSION.exe" --json | jq -r .hash)"

jq -n \
  --arg version "$VERSION" \
  --arg url "$url" \
  --arg hash "$HASH" \
  '{version: $version, url: $url, hash: $hash}' >"$INFO"
