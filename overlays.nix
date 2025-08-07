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
      smartApply = pin: pkg:
        if (applicable && (versionOlder pkg.version (removePrefix "vulkan-sdk-" pin.version)))
        then
          pkg.overrideAttrs ({
              version = removePrefix "vulkan-sdk-" pin.version;
              src = pin;
            }
            // (final.lib.mkIf (pkg.pname == "vulkan-tools-lunarg") {
              nativeBuildInputs = with final; [
                cmake
                python3
                jq
                which
                pkg-config
                qt6.wrapQtAppsHook
              ];

              buildInputs = with final; [
                expat
                jsoncpp
                libX11
                libXdmcp
                libXrandr
                libffi
                libxcb
                valijson
                vulkan-headers
                vulkan-loader
                vulkan-utility-libraries
                wayland
                xcbutilkeysyms
                xcbutilwm
                qt6.qtbase
                qt6.qtwayland
              ];
            }))
        else pkg;
    in {
      vulkan-headers = smartApply pins.Vulkan-Headers prev.vulkan-headers;
      vulkan-loader = smartApply pins.Vulkan-Loader prev.vulkan-loader;
      glslang = smartApply pins.glslang prev.glslang;
      vulkan-validation-layers = smartApply pins.Vulkan-Validation-Layers prev.vulkan-validation-layers;
      vulkan-tools = smartApply pins.Vulkan-Tools prev.vulkan-tools;
      vulkan-tools-lunarg = smartApply pins.Vulkan-Tools-LunarG prev.vulkan-tools-lunarg;
      vulkan-extension-layer = smartApply pins.Vulkan-ExtensionLayer prev.vulkan-extension-layer;
      vulkan-utility-libraries = smartApply pins.Vulkan-Utility-Libraries prev.vulkan-utility-libraries;
      vulkan-volk = smartApply pins.volk prev.vulkan-volk;
      spirv-headers = smartApply pins.SPIRV-Headers prev.spirv-headers;
      spirv-cross = smartApply pins.SPIRV-Cross prev.spirv-cross;
      spirv-tools = smartApply pins.SPIRV-Tools prev.spirv-tools;
    };
    patchedXwayland = _final: prev: {
      xwayland = prev.xwayland.overrideAttrs (p: {
        patches =
          (p.patches or [])
          ++ optional (!builtins.elem ./patches/ge-xwayland-pointer-warp-fix.patch (p.patches or [])) ./patches/ge-xwayland-pointer-warp-fix.patch;
      });
    };
    default = final: prev: let
      mFinal =
        # We dont want to apply the globally but we do want to apply it to wine-astral & rsi-launcher-git
        final.extend unstable-sdl;
    in {
      dxvk-w32 = mFinal.pkgsCross.mingw32.callPackage "${inputs.nix-gaming}/pkgs/dxvk" {
        withSdl2 = true;
        withGlfw = true;
        pins = nix-gaming-pins;
      };
      dxvk-w64 = mFinal.pkgsCross.mingwW64.callPackage "${inputs.nix-gaming}/pkgs/dxvk" {
        withSdl2 = true;
        withGlfw = true;
        pins = nix-gaming-pins;
      };

      dxvk-nvapi-w32 = mFinal.pkgsCross.mingw32.callPackage "${inputs.nix-gaming}/pkgs/dxvk-nvapi" {pins = nix-gaming-pins;};
      dxvk-nvapi-w64 = mFinal.pkgsCross.mingwW64.callPackage "${inputs.nix-gaming}/pkgs/dxvk-nvapi" {pins = nix-gaming-pins;};
      dxvk-nvapi-vkreflex-layer = mFinal.callPackage "${inputs.nix-gaming}/pkgs/dxvk-nvapi/vkreflex-layer.nix" {pins = nix-gaming-pins;};
      dxvk-nvapi-vkreflex-layer-git = mFinal.dxvk-nvapi-vkreflex-layer.overrideAttrs {
        src = pins.dxvk-nvapi;
        version = "git+${pins.dxvk-nvapi.revision}";
      };

      vkd3d-proton-w32 = mFinal.pkgsCross.mingw32.callPackage "${inputs.nix-gaming}/pkgs/vkd3d-proton" {
        pins = nix-gaming-pins;
        wine64 = final.wine-astral;
      };
      vkd3d-proton-w64 = mFinal.pkgsCross.mingwW64.callPackage "${inputs.nix-gaming}/pkgs/vkd3d-proton" {
        pins = nix-gaming-pins;
        wine64 = final.wine-astral;
      };
      winetricks-git = mFinal.callPackage "${inputs.nix-gaming}/pkgs/winetricks-git" {pins = nix-gaming-pins;};
      wineprefix-preparer = mFinal.callPackage "${inputs.nix-gaming}/pkgs/wineprefix-preparer" {};

      wineprefix-preparer-git = mFinal.wineprefix-preparer.override {
        dxvk-w64 = mFinal.dxvk-w64.overrideAttrs {
          pname = "dxvk-gplasync";
          src = pins.dxvk;
          version = "git+${pins.dxvk.revision}";
          patches = [
            "${pins.dxvk-gplasync}/patches/dxvk-gplasync-master.patch"
            "${pins.dxvk-gplasync}/patches/global-dxvk.conf.patch"
          ];
        };
        dxvk-w32 = mFinal.dxvk-w32.overrideAttrs {
          pname = "dxvk-async";
          src = pins.dxvk;
          version = "git+${pins.dxvk.revision}";
          patches = [
            "${pins.dxvk-gplasync}/patches/dxvk-gplasync-master.patch"
            "${pins.dxvk-gplasync}/patches/global-dxvk.conf.patch"
          ];
        };
        dxvk-nvapi-w64 = mFinal.dxvk-nvapi-w64.overrideAttrs {
          src = pins.dxvk-nvapi;
          version = "git+${pins.dxvk-nvapi.revision}";
        };
        dxvk-nvapi-w32 = mFinal.dxvk-nvapi-w32.overrideAttrs {
          src = pins.dxvk-nvapi;
          version = "git+${pins.dxvk-nvapi.revision}";
        };
        vkd3d-proton-w64 = mFinal.vkd3d-proton-w64.overrideAttrs {
          src = pins.vkd3d-proton;
          version = "git+${pins.vkd3d-proton.revision}";
        };
        vkd3d-proton-w32 = mFinal.vkd3d-proton-w32.overrideAttrs {
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

      rsi-launcher-unwrapped = final.callPackage ./pkgs/rsi-launcher {
        wine = final.wine-astral;
        winetricks = final.winetricks-git;
      };
      rsi-launcher-unwrapped-git = mFinal.rsi-launcher.override {
        wineprefix-preparer = mFinal.wineprefix-preparer-git;
        wine = mFinal.wine-astral;
      };
      rsi-launcher = final.callPackage ./pkgs/rsi-launcher/wrapped.nix {
        wine = final.wine-astral;
        winetricks = final.winetricks-git;
      };
      rsi-launcher-git = mFinal.rsi-launcher.override {
        rsi-launcher-unwrapped = mFinal.rsi-launcher-unwrapped-git;
        dxvk-nvapi-vkreflex-layer = mFinal.dxvk-nvapi-vkreflex-layer-git;
        wine = mFinal.wine-astral;
      };
      rsi-launcher-umu = final.rsi-launcher-unwrapped.override {useUmu = true;};

      star-citizen-unwrapped = final.rsi-launcher-unwrapped.override {pname = "star-citizen";};
      star-citizen-unwrapped-git = mFinal.rsi-launcher-unwrapped-git.override {
        pname = "star-citizen";
        wineprefix-preparer = mFinal.wineprefix-preparer-git;
      };
      star-citizen = (final.rsi-launcher.override {rsi-launcher-unwrapped = final.star-citizen-unwrapped;}).override {pname = "star-citizen";};
      star-citizen-git = mFinal.star-citizen.override {
        rsi-launcher-unwrapped = mFinal.star-citizen-unwrapped-git;
        dxvk-nvapi-vkreflex-layer = mFinal.dxvk-nvapi-vkreflex-layer-git;
      };
      star-citizen-umu = final.star-citizen-unwrapped.override {useUmu = true;};

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
