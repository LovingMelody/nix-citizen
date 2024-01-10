final: prev:
let
  pins = import ./npins;
in
{
  star-citizen-helper = prev.callPackage ./pkgs/star-citizen-helper { };
  lug-helper = prev.callPackage ./pkgs/lug-helper { inherit pins; };
}
