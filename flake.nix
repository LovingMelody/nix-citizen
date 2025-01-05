{
  description = "Nix Flake to simplify running Star Citizen";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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

  outputs =
    inputs@{ flake-parts, self, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        ./modules
        inputs.flake-parts.flakeModules.easyOverlay
        inputs.flake-parts.flakeModules.modules
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
              pins = import ./npins;
            in
            {
              xwayland = pkgs.xwayland.overrideAttrs (_p: {
                patches = [ ./patches/ge-xwayland-pointer-warp-fix.patch ];
              });
              star-citizen-helper = pkgs.callPackage ./pkgs/star-citizen-helper { };

              dxvk-gplasync =
                let
                  inherit (pins) dxvk-gplasync;
                  inherit (dxvk-gplasync) version;
                in
                pkgs.dxvk.overrideAttrs (old: {
                  name = "dxvk-gplasync";
                  inherit version;
                  patches = [
                    "${dxvk-gplasync}/patches/dxvk-gplasync-${version}.patch"
                    "${dxvk-gplasync}/patches/global-dxvk.conf.patch"
                  ] ++ old.patches or [ ];
                });

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
              inherit (inputs.nix-gaming.packages.${system})
                star-citizen
                star-citizen-umu
                umu
                winetricks-git
                ;

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
