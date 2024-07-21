{
  description = "Nix Flake to simplify running Star Citizen";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
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
    systems.url = "github:nix-systems/default";
  };

  outputs =
    { self, systems, ... }@inputs:
    with inputs;
    let
      eachSystem =
        f:
        nixpkgs.lib.genAttrs (import systems) (
          system: f (nixpkgs.legacyPackages.${system}.extend self.overlays.default)
        );
      treefmtEval = eachSystem (pkgs: treefmt-nix.lib.evalModule pkgs ./treefmt.nix);
    in
    {
      overlays.default = (import ./overlays.nix) inputs;
      nixosModules.StarCitizen = (import ./modules/nixos/star-citizen) self;
      formatter = eachSystem (pkgs: treefmtEval.${pkgs.system}.config.build.wrapper);
      checks = eachSystem (pkgs: {
        formatting = treefmtEval.${pkgs.system}.config.build.check self;
      });
      packages = eachSystem (pkgs: {
        inherit (pkgs)
          star-citizen-helper
          lug-helper
          star-citizen
          star-citizen-umu
          dxvk-gplasync
          umu
          ;
      });
      githubActions = nix-github-actions.lib.mkGithubMatrix {
        checks =
          (nixpkgs.lib.getAttrs [ "x86_64-linux" ] self.checks)
          // (nixpkgs.lib.getAttrs [ "x86_64-linux" ] self.packages);
      };
    };
}
