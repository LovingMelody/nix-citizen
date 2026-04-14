#!/usr/bin/env nix-shell
#! nix-shell -i bash -p curl jaq nix-prefetch-git
set -x
INFO='pkgs/steamcompattools/sources.json'
TEMPL='pkgs/steamcompattools/sources.tpl'
ARCH="x86_64"
get_release() {
  local name="$1"
  local repo="$2"
  local url_template="$3"
  local arch="$4"
  local ver url hash

  ver="$(curl -sL "$repo" | jaq 'map(select(.prerelease == false)) | max_by(.published_at) | .tag_name' --raw-output)"
  if [ ! -z "${ver}" ] && [ "$ver" != "$(jaq -r --arg n "$name" '.[$n].version' <"$INFO")" ]; then
    url="${url_template//\{version\}/$ver}"
    url="${url//\{arch\}/$arch}"
    hash="$(nix store prefetch-file "$url" --unpack --json | jaq -r .hash)"
    updated="true"
  else
    url="$(jaq -r --arg n "$name" '.[$n].url' <"$INFO")"
    hash="$(jaq -r --arg n "$name" '.[$n].hash' <"$INFO")"
    updated="false"
  fi
  printf '%s %s %s %s\n' "$ver" "$url" "$hash" "$updated"

}

read -r GE_VER GE_URL GE_HASH _ < <(
  get_release \
    "proton-ge-bin" \
    "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases" \
    "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/{version}/{version}.tar.gz" \
    "$ARCH"
)

read -r DW_VER DW_URL DW_HASH _ < <(
  get_release \
    "dw-proton-bin" \
    "https://dawn.wine/api/v1/repos/dawn-winery/dwproton/releases" \
    "https://dawn.wine/dawn-winery/dwproton/releases/download/{version}/{version}-{arch}.tar.xz" \
    "$ARCH"
)
cachy_url_templ='https://github.com/CachyOS/proton-cachyos/releases/download/{version}/proton-{version}-{arch}.tar.xz'

read -r CACHY_VER CACHY_URL CACHY_HASH _ < <(
  get_release \
    "proton-cachyos-bin" \
    "https://api.github.com/repos/CachyOS/proton-cachyos/releases" \
    "$cachy_url_templ" \
    "$ARCH"

)
cachy_info() {
  local arch="$1"
  url="${cachy_url_templ//\{version\}/$CACHY_VER}"
  url="${url//\{arch\}/$arch}"
  if [ "$CACHY_VER" != "$(jaq -r --arg n "proton-cachyos-$arch-bin" '.[$n].version' <"$INFO")" ]; then
    hash="$(nix store prefetch-file "$url" --unpack --json | jaq -r .hash)"
  else
    hash="$(jaq -r --arg n "proton-cachyos-$arch-bin" '.[$n].hash' <"$INFO")"
  fi

  printf '%s %s\n' "$url" "$hash"
}

read -r CACHY_ARM_URL CACHY_ARM_HASH < <(cachy_info 'arm64')
read -r CACHY_V3_URL CACHY_V3_HASH < <(cachy_info 'x86_64_v3')
read -r CACHY_V4_URL CACHY_V4_HASH < <(cachy_info 'x86_64_v4')

read -r EM_VER EM_URL EM_HASH _ < <(
  get_release \
    "proton-em-bin" \
    'https://api.github.com/repos/Etaash-mathamsetty/Proton/releases' \
    'https://github.com/Etaash-mathamsetty/Proton/releases/download/{version}/proton-{version}.tar.xz' \
    "$ARCH"
)

jaq -n \
  --arg ge_ver "$GE_VER" \
  --arg ge_url "$GE_URL" \
  --arg ge_hash "$GE_HASH" \
  --arg dw_ver "$DW_VER" \
  --arg dw_url "$DW_URL" \
  --arg dw_hash "$DW_HASH" \
  --arg cachy_ver "$CACHY_VER" \
  --arg cachy_url "$CACHY_URL" \
  --arg cachy_hash "$CACHY_HASH" \
  --arg cachy_arm_url "$CACHY_ARM_URL" \
  --arg cachy_arm_hash "$CACHY_ARM_HASH" \
  --arg cachy_v3_url "$CACHY_V3_URL" \
  --arg cachy_v3_hash "$CACHY_V3_HASH" \
  --arg cachy_v4_url "$CACHY_V4_URL" \
  --arg cachy_v4_hash "$CACHY_V4_HASH" \
  --arg em_ver "$EM_VER" \
  --arg em_url "$EM_URL" \
  --arg em_hash "$EM_HASH" \
  "$(cat "$TEMPL")" >"$INFO"
