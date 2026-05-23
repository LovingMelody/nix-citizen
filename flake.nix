{
  description = "Nix Flake to simplify running Star Citizen";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-gaming = {
      url = "github:fufexan/nix-gaming";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-compat = {
      url = "github:NixOS/flake-compat";
      flake = false;
    };
    glitzy = {
      url = "github:getchoo/glitzy";
      flake = false;
    };
  };

  outputs = inputs @ {self, ...}: let
    system = "x86_64-linux";
    pkgConfig = arch:
      if (arch == "x86-64-v3" || (arch != null && (inputs.nixpkgs.lib.systems.architectures.hasInferior arch "x86-64-v3")))
      then
        import inputs.nixpkgs {
          # inherit system;
          config = {
            allowUnfree = true;
            allowInsecure = true;
            checkMeta = true;
          };
          overlays = [
            self.overlays.default
            self.overlays.steamcompattools
          ];
          localSystem =
            {
              inherit system;
            }
            // (builtins.mapAttrs
              (_name: function: function arch)
              inputs.nixpkgs.lib.systems.architectures.predicates);
        }
      else
        import inputs.nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            allowInsecure = true;
            checkMeta = true;
          };
          overlays = [
            self.overlays.default
            self.overlays.steamcompattools
          ];
        };

    treefmtEval = pkgs: inputs.treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
  in {
    overlays = import ./overlays.nix {inherit self inputs;};
    modules = import ./modules/nixos/star-citizen/default.nix {inherit self;};
    packages = let
      pkgSet = pkgs: {
        inherit
          (pkgs)
          stdenv
          gameglass
          lug-helper
          lug-wine-bin
          rsi-launcher
          rsi-launcher-git
          rsi-launcher-umu
          rsi-launcher-unwrapped
          rsi-launcher-unwrapped-git
          star-citizen
          star-citizen-git
          star-citizen-umu
          star-citizen-unwrapped
          star-citizen-unwrapped-git
          umu-launcher
          wine-astral
          wine-tkg
          wineprefix-preparer
          wineprefix-preparer-git
          winetricks-git
          proton-ge-bin
          dw-proton-bin
          proton-cachyos-bin
          proton-em-bin
          ;
        xwayland-patched = pkgs.xwayland.overrideAttrs (p: {
          patches =
            (p.patches or [])
            ++ pkgs.lib.optional (!builtins.elem ./patches/ge-xwayland-pointer-warp-fix.patch (p.patches or [])) ./patches/ge-xwayland-pointer-warp-fix.patch;
        });
      };
    in {
      x86_64-linux = pkgSet (pkgConfig null);
      x86_64-linux-v3 = pkgSet (pkgConfig "x86-64-v3");
    };

    formatter = {
      x86_64-linux = (treefmtEval (pkgConfig null)).config.build.wrapper;
      x86_64-linux-v3 = (treefmtEval (pkgConfig "x86-64-v3")).config.build.wrapper;

      checks.${system} = {
        x86_64-linux = (treefmtEval (pkgConfig null)).config.build.check self;
        x86_64-linux-v3 = (treefmtEval (pkgConfig "x86-64-v3")).config.check self;
      };
    };
  };
  nixConfig = {
    allowInsecure = true;
    extra-substituters = ["https://nix-citizen.cachix.org"];
    extra-trusted-public-keys = ["nix-citizen.cachix.org-1:lPMkWc2X8XD4/7YPEEwXKKBg+SVbYTVrAaLA2wQTKCo="];
  };
}
