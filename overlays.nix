inputs: final: prev:
let
  pins = import ./npins;
  nix-gaming = inputs.nix-gaming.packages.${final.system};
  inherit (inputs.nixpkgs.lib.strings) versionOlder;
in
{
  star-citizen-helper = prev.callPackage ./pkgs/star-citizen-helper { };
  dxvk-gplasync =
    let
      inherit (pins) dxvk-gplasync;
      inherit (dxvk-gplasync) version;
    in
    final.dxvk.overrideAttrs (old: {
      name = "dxvk-gplasync";
      inherit version;
      patches = [
        "${dxvk-gplasync}/patches/dxvk-gplasync-${version}.patch"
        "${dxvk-gplasync}/patches/global-dxvk.conf.patch"
      ] ++ old.patches or [ ];
    });
  lug-helper =
    let
      pkg = prev.callPackage ./pkgs/lug-helper { };
    in
    # We only use the local lug-helper if nixpkgs doesn't have it
    # And if the nixpkgs version isnt older than local
    if (builtins.hasAttr "lug-helper" prev) then
      if (versionOlder prev.lug-helper.version pkg.version) then pkg else prev.lug-helper
    else
      pkg;
  inherit (nix-gaming)
    star-citizen
    star-citizen-umu
    umu
    winetricks-git
    ;
}
