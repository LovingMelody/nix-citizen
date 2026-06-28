{
  self,
  inputs,
  ...
}: let
  inherit (inputs.nixpkgs.lib) optional;
  # inherit (inputs.nixpkgs.lib) assertOneOf optionalString warn;
  pins = import "${self}/npins";
  shortRev = s: builtins.substring 0 7 s;
  # mkDeprecated = variant: return: {
  #   target,
  #   name,
  #   instructions,
  #   date ? "",
  #   renamed ? false,
  # }: let
  #   optionalDate = optionalString (date != "") " as of ${date}";
  #   type =
  #     if renamed
  #     then "renamed"
  #     else "depricated";
  #
  #   # constructed warning message
  #   message = assert assertOneOf "target" target ["package" "module"]; ''
  #     The ${target} ${name} in nix-citizen has been ${type}${optionalDate}.
  #
  #
  #     ${instructions}
  #   '';
  # in
  #   if variant == "warn"
  #   then warn message return
  #   else if variant == "throw"
  #   then throw message
  #   else
  #     # could this be asserted earlier?
  #     throw ''
  #       Unknown variant: ${variant}. Must be one of:
  #         - warn
  #         - throw
  #     '';
in rec {
  patchedXwayland = _final: prev: {
    xwayland = prev.xwayland.overrideAttrs (p: {
      patches =
        (p.patches or [])
        ++ optional (!builtins.elem ./patches/ge-xwayland-pointer-warp-fix.patch (p.patches or [])) ./patches/ge-xwayland-pointer-warp-fix.patch;
    });
  };
  _nix-citizen = final: prev: {
    low-latency-layer = prev.low-latency-layer.override {inherit pins;};

    dxvk-nvapi-vkreflex-layer-git = final.dxvk-nvapi-vkreflex-layer.overrideAttrs {
      src = pins.dxvk-nvapi;
      version = prev.dxvk-nvapi-vkreflex-layer.version + "+${pins.dxvk-nvapi.revision}";
    };

    vkd3d-proton-w32 = prev.vkd3d-proton-w32.override {wine64 = final.wine-astral;};
    vkd3d-proton-w64 = prev.vkd3d-proton-w64.override {wine64 = final.wine-astral;};
    vkd3d-proton-w32-git =
      (final.vkd3d-proton-w32.override {
        wine64 = final.wine-astral;
      }).overrideAttrs (o: {
        src = pins.vkd3d-proton;
        version = o.version + "+${shortRev pins.vkd3d-proton.revision}";
      });
    vkd3d-proton-w64-git =
      (final.vkd3d-proton-w64.override {
        wine64 = final.wine-astral;
      }).overrideAttrs (o: {
        src = pins.vkd3d-proton;
        version = o.version + "+${shortRev pins.vkd3d-proton.revision}";
      });

    dxvk-nvapi-w32-git = final.dxvk-nvapi-w32.overrideAttrs (o: {
      version = o.version + "${shortRev pins.dxvk-nvapi.revision}";
      src = pins.dxvk-nvapi;
    });
    dxvk-nvapi-w64-git = final.dxvk-nvapi-w64.overrideAttrs (o: {
      version = o.version + "${shortRev pins.dxvk-nvapi.revision}";
      src = pins.dxvk-nvapi;
    });

    wineprefix-preparer-git = final.wineprefix-preparer.override {
      dxvk-nvapi-w64 = final.dxvk-nvapi-w64-git;
      dxvk-nvapi-w32 = final.dxvk-nvapi-w32-git;
      vkd3d-proton-w64 = final.vkd3d-proton-w64-git;
      vkd3d-proton-w32 = final.vkd3d-proton-w32-git;
    };

    wine-astral = final.callPackage ./pkgs/wine-astral {
      inherit (final) lib;
      inherit inputs;
    };
    inherit
      (inputs.nix-gaming.packages.${final.stdenv.hostPlatform.system})
      wine-tkg
      wine-cachyos
      ;
    rsi-installer = final.callPackage ./pkgs/rsi-launcher/installer.nix {};
    rsi-launcher-unwrapped = final.callPackage ./pkgs/rsi-launcher {
      wine = final.wine-astral;
      winetricks = final.winetricks-git;
    };
    rsi-launcher-unwrapped-git = final.rsi-launcher-unwrapped.override {
      wineprefix-preparer = final.wineprefix-preparer-git;
      wine = final.wine-astral;
    };
    rsi-launcher = final.callPackage ./pkgs/rsi-launcher/wrapped.nix {
      wine = final.wine-astral;
      winetricks = final.winetricks-git;
    };
    rsi-launcher-git = final.rsi-launcher.override {
      rsi-launcher-unwrapped = final.rsi-launcher-unwrapped-git;
      wineprefix-preparer = final.wineprefix-preparer-git;
      dxvk-nvapi-vkreflex-layer = final.dxvk-nvapi-vkreflex-layer-git;
      wine = final.wine-astral;
    };
    rsi-launcher-umu = final.rsi-launcher-unwrapped.override {useUmu = true;};

    star-citizen-unwrapped = final.rsi-launcher-unwrapped.override {pname = "star-citizen";};
    star-citizen-unwrapped-git = final.rsi-launcher-unwrapped-git.override {
      pname = "star-citizen";
      wineprefix-preparer = final.wineprefix-preparer-git;
    };
    star-citizen = (final.rsi-launcher.override {rsi-launcher-unwrapped = final.star-citizen-unwrapped;}).override {pname = "star-citizen";};
    star-citizen-git = final.star-citizen.override {
      rsi-launcher-unwrapped = final.star-citizen-unwrapped-git;
      dxvk-nvapi-vkreflex-layer = final.dxvk-nvapi-vkreflex-layer-git;
      wineprefix-preparer = final.wineprefix-preparer-git;
    };
    star-citizen-umu = final.star-citizen-unwrapped.override {useUmu = true;};

    gameglass = final.callPackage ./pkgs/gameglass {};
    lug-helper =
      final.callPackage ./pkgs/lug-helper {winetricks = final.winetricks-git;};
    lug-wine-bin = final.callPackage ./pkgs/lug-wine-bin {};
  };

  steamcompattools = final: prev: let
    compattools = final.callPackage ./pkgs/steamcompattools {inherit (prev) proton-ge-bin;};
  in {
    inherit (compattools) proton-ge-bin dw-proton-bin proton-cachyos-bin proton-em-bin;
  };

  default = inputs.nixpkgs.lib.composeManyExtensions [
    inputs.nix-gaming.overlays.default
    _nix-citizen
    steamcompattools
  ];
}
