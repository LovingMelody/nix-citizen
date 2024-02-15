inputs: final: prev:
let
  pins = import ./npins;
  dxvk = inputs.nixpkgs_dxvk.legacyPackages.${final.system}.dxvk;
  nix-gaming = inputs.nix-gaming.packages.${final.system};
in {
  star-citizen-helper = prev.callPackage ./pkgs/star-citizen-helper { };
  lug-helper = prev.callPackage ./pkgs/lug-helper { inherit pins; };
  star-citizen = nix-gaming.star-citizen.override { inherit dxvk; };
}
