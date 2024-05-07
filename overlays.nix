inputs: final: prev:
let
  pins = import ./npins;
  nix-gaming = inputs.nix-gaming.packages.${final.system};
in {
  star-citizen-helper = prev.callPackage ./pkgs/star-citizen-helper { };
  dxvk-gplasync = prev.callPackage ./pkgs/dxvk-gplasync { inherit pins; };
  lug-helper = prev.callPackage ./pkgs/lug-helper { inherit pins; };
  inherit (nix-gaming) star-citizen;
}
