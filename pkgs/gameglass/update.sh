#!/usr/bin/env nix-shell
#! nix-shell -i bash -p curl jaq

INFO="pkgs/gameglass/sources.json"

VERSION="$(curl -s https://download.gameglass.gg/hub/latest-linux.yml | jaq --from yaml -r '.version')"

url="https://download.gameglass.gg/hub/GameGlass.AppImage"
# If it's the same as current, skip other steps
if [ "$VERSION" == "$(nix eval .\#gameglass.version --raw)" ]; then
  exit 0
fi

HASH="$(nix store prefetch-file "$url" --name "GameGlass.AppImage" --json | jaq -r .hash)"

# echo "{\"version\": \"$VERSION\", \"hash\": \"$SRI_HASH\" }" | jaq >./pkgs/gameglass/sources.json

jaq -n \
  --arg version "$VERSION" \
  --arg url "$url" \
  --arg hash "$HASH" \
  '{version: $version, url: $url, hash: $hash}' >"$INFO"
