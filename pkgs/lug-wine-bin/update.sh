#!/usr/bin/env nix-shell
#! nix-shell -i bash -p curl jq
INFO="pkgs/lug-wine-bin/sources.json"
version="$(curl -s https://api.github.com/repos/starcitizen-lug/lug-wine/releases/latest | jq -r .tag_name)"

[ "$version" == "$(nix eval .\#lug-wine-bin.version --raw)" ] && exit 0
base_url="https://github.com/starcitizen-lug/lug-wine/releases/download/$version/lug-wine-tkg-git-$version.tar.gz"
staging_url="https://github.com/starcitizen-lug/lug-wine/releases/download/$version/lug-wine-tkg-staging-git-$version.tar.gz"
base_hash="$(nix store prefetch-file "$base_url" --unpack --json | jq -r .hash)"
staging_hash="$( (nix store prefetch-file "$staging_url" --unpack --json | jq -r .hash) || echo "null")"
if [ "$staging_hash" == "null" ]; then
  staging_url="null"
fi
jq -n \
  --arg version "$version" \
  --arg staging_url "$staging_url" \
  --arg staging_hash "$staging_hash" \
  --arg base_url "$base_url" \
  --arg base_hash "$base_hash" \
  '{version: $version, staging_url: $staging_url, staging_hash: $staging_hash, base_url: $base_url, base_hash: $base_hash}' >"$INFO"
