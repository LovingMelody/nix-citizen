{
  self,
  inputs,
  ...
}: let
  inherit (inputs.nixpkgs.lib) optional;
  inherit (inputs.nixpkgs.lib.strings) versionOlder;
  pins = import "${self}/npins";
  nix-gaming-pins = import "${inputs.nix-gaming}/npins";
in {
  flake.overlays = {
    patchedXwayland = _final: prev: {
      xwayland = prev.xwayland.overrideAttrs (p: {
        patches =
          (p.patches or [])
          ++ optional (!builtins.elem ./patches/ge-xwayland-pointer-warp-fix.patch (p.patches or [])) ./patches/ge-xwayland-pointer-warp-fix.patch;
      });
    };
    default = final: prev: {
      dxvk-w32 = final.pkgsCross.mingw32.callPackage "${inputs.nix-gaming}/pkgs/dxvk" {pins = nix-gaming-pins;};
      dxvk-w64 = final.pkgsCross.mingwW64.callPackage "${inputs.nix-gaming}/pkgs/dxvk" {pins = nix-gaming-pins;};

      dxvk-nvapi-w32 = final.pkgsCross.mingw32.callPackage "${inputs.nix-gaming}/pkgs/dxvk-nvapi" {pins = nix-gaming-pins;};
      dxvk-nvapi-w64 = final.pkgsCross.mingwW64.callPackage "${inputs.nix-gaming}/pkgs/dxvk-nvapi" {pins = nix-gaming-pins;};

      vkd3d-proton-w32 = final.pkgsCross.mingw32.callPackage "${inputs.nix-gaming}/pkgs/vkd3d-proton" {pins = nix-gaming-pins;};
      vkd3d-proton-w64 = final.pkgsCross.mingwW64.callPackage "${inputs.nix-gaming}/pkgs/vkd3d-proton" {pins = nix-gaming-pins;};
      winetricks-git = final.callPackage "${inputs.nix-gaming}/pkgs/winetricks-git" {pins = nix-gaming-pins;};
      wineprefix-preparer = final.callPackage "${inputs.nix-gaming}/pkgs/wineprefix-preparer" {};

      wine-astral = final.callPackage ./pkgs/wine-astral {
        inherit (final) lib;
        inherit pins inputs;
      };
      wine-astral-ntsync = final.wine-astral.override {ntsync = true;};
      star-citizen = final.callPackage "${inputs.nix-gaming}/pkgs/star-citizen" {wine = final.wine-astral;};
      star-citizen-umu = final.star-citizen.override {useUmu = true;};
      rsi-launcher = final.callPackage ./pkgs/rsi-launcher {wine = final.wine-astral;};
      rsi-launcher-umu = final.rsi-launcher.override {useUmu = true;};

      gameglass = final.callPackage ./pkgs/gameglass {};
      star-citizen-helper = final.callPackage ./pkgs/star-citizen-helper {};
      lug-helper = let
        pkg = final.callPackage ./pkgs/lug-helper {};
      in
        # We only use the local lug-helper if nixpkgs doesn't have it
        # And if the nixpkgs version isnt newer than local
        if (builtins.hasAttr "lug-helper" prev)
        then
          if (versionOlder pkg.version prev.lug-helper.version)
          then prev.lug-helper
          else pkg
        else pkg;
    };
  };
}
