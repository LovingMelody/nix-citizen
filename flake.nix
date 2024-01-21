{
  description = "Nix Flake to simplify running Star Citizen";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nix-gaming.url = "github:fufexan/nix-gaming";
    nix-gaming.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, ... }@inputs:
    with inputs;
    let forAllSystems = nixpkgs.lib.genAttrs flake-utils.lib.defaultSystems;
    in {
      overlays.default = import ./overlays.nix;
      nixosModules.StarCitizen = (import ./module.nix) self;
      formatter =
        forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system}.extend self.overlays.default;
        in {
          inherit (nix-gaming.packages.${system}) star-citizen;
          inherit (pkgs) star-citizen-helper lug-helper;
        });
    };
}
