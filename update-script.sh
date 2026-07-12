#!/usr/bin/env nix-shell
#! nix-shell -i bash
#! nix-shell -p bash nix-update npins curl gnused gnugrep jaq cachix

if [ "${1:-}" != "--cache-only" ]; then
  nix-update --flake lug-helper

  # RSI Launcher
  ./pkgs/rsi-launcher/update.sh
  # GameGlass
  ./pkgs/gameglass/update.sh
  # lug-wine-bin
  ./pkgs/lug-wine-bin/update.sh

  # Compattools
  ./pkgs/steamcompattools/update.sh

  npins update

  # Update wine-astral sources (after pins are updated)
  ./pkgs/wine-astral/update.sh

  nix fmt
fi

nix_build() {
  NIX="nix"
  if command -v nom >/dev/null; then
    NIX="nom"
  fi

  "$NIX" build -L --print-out-paths --no-link --keep-going --refresh "$@"
}

if [ "${1:-}" = "--cache" ] || [ "${1:-}" = "--cache-only" ]; then
  logFile="$(mktemp --suffix '.nix_updater_output')"

  pkgs=(
    'rsi-launcher' 'rsi-launcher-git' 'lug-helper' 'gameglass' 'rsi-launcher-umu'
    'lug-wine-bin' 'proton-ge-bin' 'dw-proton-bin' 'proton-cachyos-bin' 'proton-em-bin'
  )

  targets=()
  optimizedTargets=()

  for pkg in "${pkgs[@]}"; do
    targets+=(".#$pkg")
    optimizedTargets+=(".#packages.x86_64-linux-v3.$pkg")
  done

  nix_build "${targets[@]}" >"$logFile" && nix_build "${optimizedTargets[@]}" >>"$logFile"
  cachix push nix-citizen <"$logFile"
  trap "rm '$logFile'" exit
fi
