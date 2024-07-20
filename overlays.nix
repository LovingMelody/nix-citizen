inputs: final: prev:
let
  pins = import ./npins;
  nix-gaming = inputs.nix-gaming.packages.${final.system};
in {
  star-citizen-helper = prev.callPackage ./pkgs/star-citizen-helper { };
  dxvk-gplasync = let
    inherit (pins) dxvk-gplasync;
    inherit (dxvk-gplasync) version;
  in final.dxvk.overrideAttrs (old: {
    name = "dxvk-gplasync";
    inherit version;
    patches = [
      "${dxvk-gplasync}/patches/dxvk-gplasync-${version}.patch"
      "${dxvk-gplasync}/patches/global-dxvk.conf.patch"
    ] ++ old.patches or [ ];
  });
  lug-helper = prev.callPackage ./pkgs/lug-helper { inherit pins; };
  inherit (nix-gaming) star-citizen;
}
