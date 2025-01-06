{ self, inputs, ... }:

let
  inherit (inputs.nixpkgs.lib) optional;
in
{
  flake.overlays.patchedXwayland = _self: super: {

    xwayland = super.xwayland.overrideAttrs (p: {
      patches =
        (p.patches or [ ])
        ++ optional (
          !builtins.elem ./patches/ge-xwayland-pointer-warp-fix.patch (p.patches or [ ])
        ) ./patches/ge-xwayland-pointer-warp-fix.patch;
    });
  };
}
