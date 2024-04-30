inputs: final: prev:
let
  pins = import ./npins;
  nix-gaming = inputs.nix-gaming.packages.${final.system};
in {
  star-citizen-helper = prev.callPackage ./pkgs/star-citizen-helper { };
  lug-helper = prev.callPackage ./pkgs/lug-helper { inherit pins; };
  inherit (nix-gaming) star-citizen;
}
