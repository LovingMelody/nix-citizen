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

        # Update wine-astral sources
        # This has to be done after pins are updated
        ./pkgs/wine-astral/update.sh

        nix fmt
fi

if [ "${1:-}" = "--cache" ] || [ "${1:-}" = "--cache-only" ]; then
        nom build .#rsi-launcher .#rsi-launcher-git .#lug-helper .#gameglass .#rsi-launcher-umu .#lug-wine-bin .#proton-ge-bin .#dw-proton-bin .#proton-cachyos-bin .#proton-em-bin --print-out-paths --no-link --keep-going --refresh | cachix push nix-citizen
        nom build .#packages.x86_64-linux-v3.rsi-launcher .#packages.x86_64-linux-v3.rsi-launcher-git .#packages.x86_64-linux-v3.lug-helper .#packages.x86_64-linux-v3.gameglass .#packages.x86_64-linux-v3.rsi-launcher-umu .#packages.x86_64-linux-v3.lug-wine-bin .#packages.x86_64-linux-v3.proton-ge-bin .#packages.x86_64-linux-v3.dw-proton-bin .#packages.x86_64-linux-v3.proton-cachyos-bin .#packages.x86_64-linux-v3.proton-em-bin --print-out-paths --no-link --keep-going --refresh | cachix push nix-citizen
fi
