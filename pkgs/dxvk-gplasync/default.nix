{ dxvk, pins, ... }:
let
  inherit (pins) dxvk-gplasync;
  inherit (dxvk-gplasync) version;
in
dxvk.overrideAttrs (old: {
  name = "dxvk-gplasync";
  patches = [
    "${dxvk-gplasync}/patches/dxvk-gplasync-${version}.patch"
    "${dxvk-gplasync}/patches/global-dxvk.conf.patch"
  ] ++ old.patches or [ ];
})
