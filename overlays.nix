{
  self,
  inputs,
  ...
}: let
  # inherit (inputs.nixpkgs.lib) assertOneOf optional optionalString warn;
  inherit (inputs.nixpkgs.lib) optional;
  inherit (inputs.nixpkgs.lib.strings) removePrefix versionOlder hasSuffix;
  pins = import "${self}/npins";
  nix-gaming-pins = import "${inputs.nix-gaming}/npins";
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
in {
  flake.overlays = rec {
    unstable-sdl = final: prev: {
      sdl3 =
        if (hasSuffix pins.sdl.revision prev.sdl3.version)
        then prev.sdl3
        else
          prev.sdl3.overrideAttrs (o: rec {
            src = pins.sdl;
            # Not perfect but it works
            version = "${o.version}-${src.revision}";
            meta.changelog = "https://github.com/libsdl-org/SDL/releases";
          });
      SDL2 =
        if (hasSuffix pins.sdl2-compat.revision prev.SDL2.version)
        then prev.SDL2
        else
          (prev.SDL2.override {inherit (final) sdl3;}).overrideAttrs (o: rec {
            src = pins.sdl2-compat;
            # Not perfect but it works
            version = "${o.version}-${src.revision}";
            meta.changelog = "https://github.com/libsdl-org/sdl2-compat/releases/";
          });
    };
    updated-vulkan-sdk = final: prev: let
      version = removePrefix "vulkan-sdk-" pins.Vulkan-Headers.version;
      # Safety check, we only want to update the vulkan-sdk if the vulkan-headers version is older than the one we have
      # The loader & headers versions should always match
      applicable = (pins.Vulkan-Loader.version == pins.Vulkan-Headers.version) && (versionOlder prev.vulkan-headers.version version);
    in {
      vulkan-headers =
        if applicable
        then
          prev.vulkan-headers.overrideAttrs {
            version = removePrefix "vulkan-sdk-" pins.Vulkan-Headers.version;
            src = pins.Vulkan-Headers;
          }
        else prev.vulkan-headers;
      vulkan-loader =
        if applicable
        then
          (prev.vulkan-loader.overrideAttrs
            {
              version = removePrefix "vulkan-sdk-" pins.Vulkan-Loader.version;
              src = pins.Vulkan-Loader;
            }).override {
            inherit (final) vulkan-headers;
          }
        else prev.vulkan-loader;
    };
    patchedXwayland = _final: prev: {
      xwayland = prev.xwayland.overrideAttrs (p: {
        patches =
          (p.patches or [])
          ++ optional (!builtins.elem ./patches/ge-xwayland-pointer-warp-fix.patch (p.patches or [])) ./patches/ge-xwayland-pointer-warp-fix.patch;
      });
    };
    default = final: prev:
    #let
    # We dont want to apply the globally but we do want to apply it to wine-astral & rsi-launcher-git
    # ffDeps = (final.extend unstable-sdl).extend updated-vulkan-sdk;
    #in
    {
      dxvk-w32 = final.pkgsCross.mingw32.callPackage "${inputs.nix-gaming}/pkgs/dxvk" {
        withSdl2 = true;
        withGlfw = true;
        pins = nix-gaming-pins;
      };
      dxvk-w64 = final.pkgsCross.mingwW64.callPackage "${inputs.nix-gaming}/pkgs/dxvk" {
        withSdl2 = true;
        withGlfw = true;
        pins = nix-gaming-pins;
      };

      dxvk-nvapi-w32 = final.pkgsCross.mingw32.callPackage "${inputs.nix-gaming}/pkgs/dxvk-nvapi" {pins = nix-gaming-pins;};
      dxvk-nvapi-w64 = final.pkgsCross.mingwW64.callPackage "${inputs.nix-gaming}/pkgs/dxvk-nvapi" {pins = nix-gaming-pins;};

      vkd3d-proton-w32 = final.pkgsCross.mingw32.callPackage "${inputs.nix-gaming}/pkgs/vkd3d-proton" {pins = nix-gaming-pins;};
      vkd3d-proton-w64 = final.pkgsCross.mingwW64.callPackage "${inputs.nix-gaming}/pkgs/vkd3d-proton" {pins = nix-gaming-pins;};
      winetricks-git = final.callPackage "${inputs.nix-gaming}/pkgs/winetricks-git" {pins = nix-gaming-pins;};
      wineprefix-preparer = final.callPackage "${inputs.nix-gaming}/pkgs/wineprefix-preparer" {};

      wineprefix-preparer-git = final.wineprefix-preparer.override {
        dxvk-w64 = final.dxvk-w64.overrideAttrs {
          pname = "dxvk-gplasync";
          src = pins.dxvk;
          version = "git+${pins.dxvk.revision}";
          patches = [
            "${pins.dxvk-gplasync}/patches/dxvk-gplasync-master.patch"
            "${pins.dxvk-gplasync}/patches/global-dxvk.conf.patch"
          ];
        };
        dxvk-w32 = final.dxvk-w32.overrideAttrs {
          pname = "dxvk-async";
          src = pins.dxvk;
          version = "git+${pins.dxvk.revision}";
          patches = [
            "${pins.dxvk-gplasync}/patches/dxvk-gplasync-master.patch"
            "${pins.dxvk-gplasync}/patches/global-dxvk.conf.patch"
          ];
        };
        vkd3d-proton-w64 = final.vkd3d-proton-w64.overrideAttrs {
          src = pins.vkd3d-proton;
          version = "git+${pins.vkd3d-proton.revision}";
        };
        vkd3d-proton-w32 = final.vkd3d-proton-w32.overrideAttrs {
          src = pins.vkd3d-proton;
          version = "git+${pins.vkd3d-proton.revision}";
        };
      };

      wine-astral = final.callPackage ./pkgs/wine-astral {
        inherit (final) lib;
        inherit pins inputs;
        wine-mono = final.callPackage "${inputs.nix-gaming}/pkgs/wine-mono" {
          pins = nix-gaming-pins;
        };
      };
      wine-astral-ntsync = final.wine-astral.override {ntsync = true;};
      star-citizen = final.callPackage "${inputs.nix-gaming}/pkgs/star-citizen" {
        wine = final.wine-astral;
        disableEac = false;
      };
      star-citizen-git = final.star-citizen.override {wineprefix-preparer = final.wineprefix-preparer-git;};
      star-citizen-umu = final.star-citizen.override {useUmu = true;};
      rsi-launcher = final.callPackage ./pkgs/rsi-launcher {wine = final.wine-astral;};
      rsi-launcher-git = final.rsi-launcher.override {wineprefix-preparer = final.wineprefix-preparer-git;};
      rsi-launcher-umu = final.rsi-launcher.override {useUmu = true;};

      gameglass = final.callPackage ./pkgs/gameglass {};
      star-citizen-helper = final.callPackage ./pkgs/star-citizen-helper {};
      lug-helper = let
        pkg = final.callPackage ./pkgs/lug-helper {};
      in
        # We only use the local lug-helper if nixpkgs doesn't have it
        # And if the nixpkgs version isn't newer than local
        if (builtins.hasAttr "lug-helper" prev)
        then
          if (versionOlder pkg.version prev.lug-helper.version)
          then prev.lug-helper
          else pkg
        else pkg;
    };
  };
}
