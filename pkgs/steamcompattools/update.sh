#!/usr/bin/env nix-shell
#! nix-shell -i bash -p curl jq nix-prefetch-git

INFO='pkgs/steamcompattools/sources.json'
TEMPL='pkgs/steamcompattools/sources.tpl'
GE_REPO='https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases'
GE_VER="$(curl -sL "$GE_REPO" | jq 'map(select(.prerelease == false)) | .[0].tag_name' --raw-output)"
if [ "$GE_VER" != "$(jq -r '.["proton-ge-bin"].version' <"$INFO")" ]; then
  GE_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/$GE_VER/$GE_VER.tar.gz"
  GE_HASH="$(nix store prefetch-file "$GE_URL" --unpack --json | jq -r .hash)"
else

  GE_URL="$(jq -r '.["proton-ge-bin"].url' <"$INFO")"
  GE_HASH="$(jq -r '.["proton-ge-bin"].hash' <"$INFO")"
fi
DW_REPO='https://dawn.wine/api/v1/repos/dawn-winery/dwproton/releases'
DW_VER="$(curl -sL "$DW_REPO" | jq 'map(select(.prerelease == false)) | .[0].tag_name' --raw-output)"

if [ "$DW_VER" != "$(jq -r '.["dw-proton-bin"].version' <"$INFO")" ]; then
  DW_URL="https://dawn.wine/dawn-winery/dwproton/releases/download/$DW_VER/$DW_VER-x86_64.tar.xz"
  DW_HASH="$(nix store prefetch-file "$DW_URL" --unpack --json | jq -r .hash)"
else
  DW_URL="$(jq -r '.["dw-proton-bin"].url' <"$INFO")"
  DW_HASH="$(jq -r '.["dw-proton-bin"].hash' <"$INFO")"
fi
jq -n \
  --arg ge_ver "$GE_VER" \
  --arg ge_url "$GE_URL" \
  --arg ge_hash "$GE_HASH" \
  --arg dw_ver "$DW_VER" \
  --arg dw_url "$DW_URL" \
  --arg dw_hash "$DW_HASH" \
  "$(cat "$TEMPL")" >"$INFO"
