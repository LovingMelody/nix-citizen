#!/usr/bin/env nix-shell
#! nix-shell -i bash
#! nix-shell -p bash nix-update npins
nix-update --flake lug-helper
npins update
nix fmt
