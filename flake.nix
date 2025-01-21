{
  description = "Nix Flake to simplify running Star Citizen";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    umu = {
      url = "git+https://github.com/LovingMelody/umu-launcher/?dir=packaging\/nix&submodules=1&";
      # Unreleased changed to umu in nixpkgs, we won't override it
      # inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-gaming = {
      url = "github:fufexan/nix-gaming";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.umu.follows = "umu";
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

  outputs =
    inputs@{ flake-parts, self, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        ./modules
        ./overlays.nix
        inputs.flake-parts.flakeModules.easyOverlay
        inputs.treefmt-nix.flakeModule
      ];
      systems = [ "x86_64-linux" ];
      flake = {
        githubActions = inputs.nix-github-actions.lib.mkGithubMatrix {
          checks =
            (inputs.nixpkgs.lib.getAttrs [ "x86_64-linux" ] self.checks)
            // (inputs.nixpkgs.lib.getAttrs [ "x86_64-linux" ] self.packages);
        };
      };
      perSystem =
        {
          config,
          system,
          pkgs,
          ...
        }:
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          overlayAttrs = config.packages;
          packages =
            let
              inherit (inputs.nixpkgs.lib) optional warn;
            in
            {
              xwayland-patched = pkgs.xwayland.overrideAttrs (p: {
                patches =
                  (p.patches or [ ])
                  ++ optional (
                    !builtins.elem ./patches/ge-xwayland-pointer-warp-fix.patch (p.patches or [ ])
                  ) ./patches/ge-xwayland-pointer-warp-fix.patch;
              });
              star-citizen-helper = pkgs.callPackage ./pkgs/star-citizen-helper { };
              inherit (inputs.umu.packages.${system}) umu-launcher;
              dxvk-gplasync = warn "This package will be removed in a future update and is now just an alias for dxvk" pkgs.dxvk;
              star-citizen = inputs.nix-gaming.packages.${system}.star-citizen.override {
                umu = self.packages.${system}.umu-launcher;
              };
              star-citizen-umu = self.packages.${system}.star-citizen.override { useUmu = true; };
              lug-helper =
                let
                  pkg = pkgs.callPackage ./pkgs/lug-helper { };
                in
                # We only use the local lug-helper if nixpkgs doesn't have it
                # And if the nixpkgs version isnt older than local
                if (builtins.hasAttr "lug-helper" pkgs) then
                  if (inputs.nixpkgs.lib.strings.versionOlder pkgs.lug-helper.version pkg.version) then
                    pkg
                  else
                    pkgs.lug-helper
                else
                  pkg;
              inherit (inputs.nix-gaming.packages.${system}) winetricks-git;

            };
          treefmt = {
            # Project root
            projectRootFile = "flake.nix";
            # Terraform formatter
            programs = {
              yamlfmt.enable = true;
              nixfmt.enable = true;
              deno.enable = true;
              deadnix = {
                enable = true;
                # Can break callPackage if this is set to false
                no-lambda-pattern-names = true;
              };
              statix.enable = true;
              rustfmt.enable = true;
              beautysh.enable = true;
            };
            settings.formatter = {
              deadnix.excludes = [ "npins/default.nix" ];
              nixfmt.excludes = [ "npins/default.nix" ];
              deno.excludes = [ "npins/default.nix" ];
              statix.excludes = [ "npins/default.nix" ];
              yamlfmt.excludes = [ "npins/sources.json" ];
            };
          };
        };
    };
}
