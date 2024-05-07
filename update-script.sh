#!/usr/bin/env nix-shell
#! nix-shell -i bash
#! nix-shell -p bash nix-update
nix-update --flake lug-helper
nix-update --flake --override-filename pkgs/dxvk-gplasync/default.nix dxvk-gplasync
