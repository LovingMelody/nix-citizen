#!/usr/bin/env nix-shell
#! nix-shell -i bash -p curl jq nix-prefetch-git

# This has to be run after wine()
vkSources() {

  INFO="pkgs/wine-astral/vk.json"

  src=$(jq -r .path <'pkgs/wine-astral/wine.json')
  VERSION=$(sed -nE 's/^[[:space:]]*VK_XML_VERSION[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$src/dlls/winevulkan/make_vulkan" | head -n1)

  LAST_CHECKED_VERSION="$(jq -r .version "$INFO")"

  # If it's the same as current, skip other steps
  if [ "$VERSION" == "$LAST_CHECKED_VERSION" ]; then
    return
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
}

openxr() {
  INFO="pkgs/wine-astral/openxr.json"

  # GitHub API URL
  # We limit to 1 result to get the most recent commit
  URL="https://api.github.com/repos/ValveSoftware/Proton/commits?sha=bleeding-edge&path=wineopenxr&per_page=1"

  # Fetch data and extract the SHA hash
  LATEST_REV=$(curl -s "$URL" | jq -r '.[0].sha')

  if [ "$LATEST_REV" != "null" ] && [ "$LATEST_REV" != "$(jq -r '.rev' "$INFO")" ]; then
    nix-prefetch-git --rev "$LATEST_REV" --sparse-checkout wineopenxr --quiet 'https://github.com/ValveSoftware/Proton.git' >$INFO
  else
    [ "$LATEST_REV" != "null" ] || echo "[wine-astral][openxr]: Error: Could not retrieve hash. Verify the path and branch names."
  fi
}

lugPatches() {
  INFO="pkgs/wine-astral/lug-patches.json"
  nix-prefetch-git --no-deepClone --branch-name main --quiet 'https://github.com//starcitizen-lug/patches' >$INFO
}

wineTKG() {
  INFO="pkgs/wine-astral/wine-tkg-git.json"
  nix-prefetch-git --no-deepClone --branch-name master --quiet 'https://github.com/Frogging-Family/wine-tkg-git.git' >$INFO
}
wine() {
  INFO="pkgs/wine-astral/wine.json"
  if output=$(nix-prefetch-git --fetch-submodules --no-deepClone --branch-name master --quiet 'https://gitlab.winehq.org/wine/wine.git'); then
    src=$(jq -r .path <<<"$output")
    version=$(cat "$src/VERSION")
    jq --arg version "${version##"Wine version "}" '.version = $version' <<<"$output" >"$INFO"
  fi

}
wineStaging() {
  INFO="pkgs/wine-astral/wine-staging.json"
  nix-prefetch-git --fetch-submodules --no-deepClone --branch-name master --quiet 'https://gitlab.winehq.org/wine/wine-staging.git' >$INFO
}
wineMono() {

  INFO="pkgs/wine-astral/mono.json"
  version="$(curl -fsSL "https://api.github.com/repos/wine-mono/wine-mono/releases/latest" | jq -r '.tag_name')"

  if [ "$(jq -r ".version" "$INFO")" != "$version" ]; then
    if output=$(nix store prefetch-file "https://github.com/wine-mono/wine-mono/releases/download/${version}/${version}-x86.msi" --json); then
      jq --arg version "$version" '.version = $version' <<<"$output" >"$INFO"
    fi
  fi
}
openxr || echo "[wine-astral][openxr]: Failed to update source"
lugPatches || echo "[wine-astral][lug]: Failed to update source"
wineTKG || echo "[wine-astral][wine-tkg]: Failed to update source"
wine || echo "[wine-astral][wine]: Failed to update source"
wineStaging || "[wine-astral][wine staging]: Failed to update source"
vkSources || echo "[wine-astral][vk]: Failed to update sources"
wineMono || echo "[wine-astral][mono]: Update failed"
