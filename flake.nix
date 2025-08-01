{
  description = "Nix Flake to simplify running Star Citizen";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    nix-gaming = {
      url = "github:fufexan/nix-gaming";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-github-actions = {
      url = "github:nix-community/nix-github-actions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    systems.url = "github:nix-systems/default";
  };

  outputs = inputs @ {
    flake-parts,
    self,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        ./modules
        ./overlays.nix
        inputs.treefmt-nix.flakeModule
      ];
      systems = ["x86_64-linux"];
      flake = {
        githubActions = inputs.nix-github-actions.lib.mkGithubMatrix {
          checks =
            (inputs.nixpkgs.lib.getAttrs ["x86_64-linux"] self.checks)
            // (inputs.nixpkgs.lib.getAttrs ["x86_64-linux"] self.packages);
        };
      };
      perSystem = {
        config,
        system,
        pkgs,
        ...
      }: {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            allowInsecure = true;
            checkMeta = true;
          };
          overlays = [self.overlays.default];
        };
        packages = let
          inherit (inputs.nixpkgs.lib) optional;
        in {
          inherit
            (pkgs)
            gameglass
            lug-helper
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
            wine-astral-ntsync
            wineprefix-preparer
            wineprefix-preparer-git
            winetricks-git
            ;

          xwayland-patched = pkgs.xwayland.overrideAttrs (p: {
            patches =
              (p.patches or [])
              ++ optional (!builtins.elem ./patches/ge-xwayland-pointer-warp-fix.patch (p.patches or [])) ./patches/ge-xwayland-pointer-warp-fix.patch;
          });
        };
        treefmt = {
          # Project root
          projectRootFile = "flake.nix";
          # Terraform formatter
          programs = {
            yamlfmt.enable = true;
            # nixfmt.enable = true;
            alejandra.enable = true;
            deno.enable = true;
            deadnix = {
              enable = true;
              # Can break callPackage if this is set to false
              no-lambda-pattern-names = true;
            };
            statix.enable = true;
            rustfmt.enable = true;
            black.enable = true;
            isort.enable = true;
            shfmt.enable = true;
            beautysh.enable = true;
          };
          settings.formatter = {
            deadnix.excludes = ["npins/default.nix"];
            deno.excludes = ["npins/default.nix"];
            statix.excludes = ["npins/default.nix"];
            yamlfmt.excludes = ["npins/sources.json"];
          };
        };
      };
    };
  nixConfig = {
    allowInsecure = true;
    extra-substituters = ["https://nix-citizen.cachix.org"];
    extra-trusted-public-keys = ["nix-citizen.cachix.org-1:lPMkWc2X8XD4/7YPEEwXKKBg+SVbYTVrAaLA2wQTKCo="];
  };
}
