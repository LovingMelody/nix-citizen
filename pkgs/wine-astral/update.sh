#!/usr/bin/env nix-shell
#! nix-shell -i bash -p curl jq

INFO="pkgs/wine-astral/vk-sources.json"

VERSION="$(nix eval .\#wine-astral.vk_version --raw)"

LAST_CHECKED_VERSION="$(jq -r .version "$INFO")"

# If it's the same as current, skip other steps
if [ "$VERSION" == "$(cat "$INFO")" ]; then
  exit 0
fi

url="https://raw.githubusercontent.com/KhronosGroup/Vulkan-Docs/v$VERSION/xml/vk.xml"
url2="https://raw.githubusercontent.com/KhronosGroup/Vulkan-Docs/v$VERSION/xml/video.xml"

HASH="$(nix store prefetch-file "$url" --json | jq -r .hash)"
HASH2="$(nix store prefetch-file "$url2" --json | jq -r .hash)"

jq -n \
  --arg version "$VERSION" \
  --arg vk_hash "$HASH" \
  --arg video_hash "$HASH2" \
  '{version: $version, vk_hash: $vk_hash, video_hash: $video_hash}' >"$INFO"
