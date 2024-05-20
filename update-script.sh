#!/usr/bin/env nix-shell
#! nix-shell -i bash
#! nix-shell -p bash nix-update npins curl jq gnused gnugrep
update-gplasync () {
  echo "[dxvk-gplasync]: Searching for update..."
  local latest="$(curl 'https://gitlab.com/api/v4/projects/Ph42oN%2Fdxvk-gplasync/repository/tags?per_page=1' | , jq -r ".[0].name" | sed 's/^v//')"
  local current="$(npins show | grep "version" | sed 's/\s\s\s\sversion: v//')"
  echo "[dxvk-gplasync] Current : $current"
  echo "[dxvk-gplasync] Upstream: $latest"
  if [ "$latest" != "$current" ]; then
    echo "[dxvk-gplasync] Update found: $current -> $latest"
    npins add gitlab Ph42oN dxvk-gplasync --at "$latest"
  fi
}
nix-update --flake lug-helper
update-gplasync
nix fmt
