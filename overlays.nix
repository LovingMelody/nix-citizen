{
  self,
  inputs,
  ...
}: let
  inherit (inputs.nixpkgs.lib) optional;
  inherit (inputs.nixpkgs.lib.strings) versionOlder;
  pins = import "${self}/npins";
  nix-gaming-pins = import "${inputs.nix-gaming}/npins";
  brokenCommits = {
    dxvkGplAsync = "8a55443c13a5c8b0a09b6859edaa54e3576518b3"; # Patch no longer applies to dxvk needs update
  };
in {
  flake.overlays = rec {
    unstable-sdl = final: prev: {
      sdl3 = prev.sdl3.overrideAttrs (o: rec {
        src = pins.sdl;
        # Not perfect but it works
        version = "${o.version}-${src.revision}";
        meta.changelog = "https://github.com/libsdl-org/SDL/releases";
      });
      sdl2 = (prev.sdl2.override {inherit (final) sdl3;}).overrideAttrs (o: rec {
        src = pins.sdl2-compat;
        # Not perfect but it works
        version = "${o.version}-${src.revision}";
      });
    };
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

      wineprefix-preparer-git = final.wineprefix-preparer.override {
        dxvk-w64 = final.dxvk-w64.overrideAttrs {
          pname = "dxvk-gplasync";
          src = pins.dxvk;
          version = "git+${pins.dxvk.revision}";
          patches = [
            (
              if brokenCommits.dxvkGplAsync != pins.dxvk-gplasync.revision
              then (pins.dxvk-gplasync + "/patches/dxvk-gplasync-master.patch")
              else patches/dxvk-gplasync-master.patch
            )
            (pins.dxvk-gplasync + "/patches/global-dxvk.conf.patch")
          ];
        };
        dxvk-w32 = final.dxvk-w32.overrideAttrs {
          pname = "dxvk-async";
          src = pins.dxvk;
          version = "git+${pins.dxvk.revision}";
          patches = [
            (
              if brokenCommits.dxvkGplAsync != pins.dxvk-gplasync.revision
              then (pins.dxvk-gplasync + "/patches/dxvk-gplasync-master.patch")
              else patches/dxvk-gplasync-master.patch
            )
            (pins.dxvk-gplasync + "/patches/global-dxvk.conf.patch")
          ];
        };
        vkd3d-proton-w64 = final.vkd3d-proton-w64.overrideAttrs {
          src = pins.vkd3d-proton;
          version = "git+${pins.vkd3d-proton.revision}";
        };
        vkd3d-proton-w32 = final.vkd3d-proton-w32.overrideAttrs {
          src = pins.vkd3d-proton;
          version = "git+${pins.vkd3d-proton.revision}";
        };
      };

      wine-astral = let
        # Prev probably works just fine but future additions could change that.
        # sdl not included in the overlay to stop it from affecting other builds.
        # falseFinal = final.extend unstable-sdl;
        falseFinal = final;
      in
        falseFinal.callPackage ./pkgs/wine-astral {
          inherit (falseFinal) lib;
          inherit pins inputs;
          wine-mono = falseFinal.callPackage "${inputs.nix-gaming}/pkgs/wine-mono" {
            pins = nix-gaming-pins;
          };
        };
      wine-astral-ntsync = final.wine-astral.override {ntsync = true;};
      star-citizen = final.callPackage "${inputs.nix-gaming}/pkgs/star-citizen" {wine = final.wine-astral;};
      star-citizen-git = final.star-citizen.override {wineprefix-preparer = final.wineprefix-preparer-git;};
      star-citizen-umu = final.star-citizen.override {useUmu = true;};
      rsi-launcher = final.callPackage ./pkgs/rsi-launcher {wine = final.wine-astral;};
      rsi-launcher-git = final.rsi-launcher.override {wineprefix-preparer = final.wineprefix-preparer-git;};
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
