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

  outputs = inputs @ {
    flake-parts,
    self,
    ...
  }: let
    pins = import ./npins;
  in
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        ./modules
        ./overlays.nix
        inputs.flake-parts.flakeModules.easyOverlay
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
          config.allowUnfree = true;
        };
        overlayAttrs = config.packages;
        packages = let
          inherit (inputs.nixpkgs.lib) optional warn;
        in {
          wine-astral = inputs.nix-gaming.packages.x86_64-linux.wine-tkg.override (o: {
            pname = "wine-astral-full";
            patches = let
              blacklist = [
                "10.2+_eac_fix.patch"
                "real_path.patch"
                "winewayland-no-enter-move-if-relative.patch"
              ];
              filter = name: _type: ! (builtins.elem (builtins.baseNameOf name) blacklist);
              cleanedPatches = builtins.filterSource filter "${pins.lug-patches}/wine";
              lug-patches = builtins.attrNames (builtins.readDir cleanedPatches);
              patches = map (f: "${cleanedPatches}/${f}") lug-patches;
            in
              (o.patches or [])
              ++ patches;
          });

          gameglass = pkgs.callPackage ./pkgs/gameglass {};
          xwayland-patched = pkgs.xwayland.overrideAttrs (p: {
            patches =
              (p.patches or [])
              ++ optional (!builtins.elem ./patches/ge-xwayland-pointer-warp-fix.patch (p.patches or [])) ./patches/ge-xwayland-pointer-warp-fix.patch;
          });
          star-citizen-helper = pkgs.callPackage ./pkgs/star-citizen-helper {};
          inherit (inputs.nix-gaming.packages.${system}) umu-launcher star-citizen star-citizen-umu;
          dxvk-gplasync = warn "This package will be removed in a future update and is now just an alias for dxvk" pkgs.dxvk;
          lug-helper = let
            pkg = pkgs.callPackage ./pkgs/lug-helper {};
          in
            # We only use the local lug-helper if nixpkgs doesn't have it
            # And if the nixpkgs version isnt newer than local
            if (builtins.hasAttr "lug-helper" pkgs)
            then
              if (inputs.nixpkgs.lib.strings.versionOlder pkg.version pkgs.lug-helper.version)
              then pkgs.lug-helper
              else pkg
            else pkg;

          inherit (inputs.nix-gaming.packages.${system}) winetricks-git;
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
}
