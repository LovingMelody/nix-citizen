{
  self,
  inputs,
  ...
}: let
  inherit (inputs.nixpkgs.lib) optional;
  # inherit (inputs.nixpkgs.lib) assertOneOf optionalString warn;
  inherit (inputs.nixpkgs.lib.strings) removePrefix versionOlder versionAtLeast;
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
    latestFFMPEG = final: prev: {
      opencv =
        if (versionAtLeast prev.opencv.version "4.12")
        then
          if (versionAtLeast prev.ffmpeg.version prev.ffmpeg_8.version)
          then prev.opencv
          else
            ((prev.opencv.override {inherit (final) ffmpeg;}).overrideAttrs (o: {
              patches =
                (o.patches or [])
                ++ final.lib.optional (o.version == "4.12.0") (final.fetchpatch2 {
                  url = "https://github.com/opencv/opencv/commit/90c444abd387ffa70b2e72a34922903a2f0f4f5a.patch";
                  hash = "sha256-wRL2mLxclO5NpWg1rBKso/8oTO13I5XJ6pEW+Y3PsPc=";
                });
            }))
        else prev.opencv;
      ffmpeg =
        if
          (versionAtLeast prev.opencv.version "4.12")
          && (builtins.hasAttr "ffmpeg_8" final)
          && (versionOlder prev.ffmpeg.version final.ffmpeg_8.version)
        then final.ffmpeg_8
        else prev.ffmpeg;

      ffmpeg-headless =
        if
          (versionAtLeast prev.opencv.version "4.12")
          && (builtins.hasAttr "ffmpeg_8" final)
          && (versionOlder prev.ffmpeg.version final.ffmpeg_8.version)
        then final.ffmpeg_8-headless
        else prev.ffmpeg-headless;
      ffmpeg-full =
        if
          (versionAtLeast prev.opencv.version "4.12")
          && (builtins.hasAttr "ffmpeg_8" final)
          && (versionOlder prev.ffmpeg.version final.ffmpeg_8.version)
        then final.ffmpeg_8-full
        else prev.ffmpeg-full;
    };
    upated-vulkan-sdk = final: prev: let
      version = removePrefix "vulkan-sdk-" pins.Vulkan-Headers.version;
      # Safety check, we only want to update the vulkan-sdk if the vulkan-headers version is older than the one we have
      # The loader & headers versions should always match
      applicable = (pins.Vulkan-Loader.version == pins.Vulkan-Headers.version) && (versionOlder prev.vulkan-headers.version version);
      smartApply = pin: pkg:
        if (applicable && (versionOlder pkg.version (removePrefix "vulkan-sdk-" pin.version)))
        then
          if pkg.pname == "vulkan-tools-lunarg"
          then final.callPackage ./pkgs/vulkan-tools-lunarg {inherit pins;}
          else
            pkg.overrideAttrs {
              version = removePrefix "vulkan-sdk-" pin.version;
              src = pin;
              passthru.smartUpdated = true;
            }
        else pkg;
    in {
      vulkan-headers = smartApply pins.Vulkan-Headers prev.vulkan-headers;
      vulkan-loader = smartApply pins.Vulkan-Loader prev.vulkan-loader;
      glslang = smartApply pins.glslang prev.glslang;
      vulkan-validation-layers = smartApply pins.Vulkan-Validation-Layers prev.vulkan-validation-layers;
      vulkan-tools = smartApply pins.Vulkan-Tools prev.vulkan-tools;
      vulkan-tools-lunarg = let
        pkg = smartApply pins.Vulkan-Tools-LunarG prev.vulkan-tools-lunarg;
      in
        if (pkg.passthru ? smartUpdated)
        then
          pkg.overrideAttrs {
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

            cmakeFlags = [
              "-DVULKAN_HEADERS_INSTALL_DIR=${final.vulkan-headers}"
            ];
          }
        else pkg;
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
    default = final: _prev: {
      cnc-ddraw = final.callPackage "${inputs.nix-gaming}/pkgs/cnc-ddraw" {};
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
      dxvk-nvapi-vkreflex-layer = final.callPackage "${inputs.nix-gaming}/pkgs/dxvk-nvapi/vkreflex-layer.nix" {pins = nix-gaming-pins;};
      dxvk-nvapi-vkreflex-layer-git = final.dxvk-nvapi-vkreflex-layer.overrideAttrs {
        src = pins.dxvk-nvapi;
        version = "git+${pins.dxvk-nvapi.revision}";
      };

      vkd3d-proton-w32 = final.pkgsCross.mingw32.callPackage "${inputs.nix-gaming}/pkgs/vkd3d-proton" {
        pins = nix-gaming-pins;
        wine64 = final.wine-astral;
      };
      vkd3d-proton-w64 = final.pkgsCross.mingwW64.callPackage "${inputs.nix-gaming}/pkgs/vkd3d-proton" {
        pins = nix-gaming-pins;
        wine64 = final.wine-astral;
      };
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
        dxvk-nvapi-w64 = final.dxvk-nvapi-w64.overrideAttrs {
          src = pins.dxvk-nvapi;
          version = "git+${pins.dxvk-nvapi.revision}";
        };
        dxvk-nvapi-w32 = final.dxvk-nvapi-w32.overrideAttrs {
          src = pins.dxvk-nvapi;
          version = "git+${pins.dxvk-nvapi.revision}";
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
      inherit
        (inputs.nix-gaming.packages.${final.system})
        wine-tkg
        wine-cachyos
        ;

      rsi-launcher-unwrapped = final.callPackage ./pkgs/rsi-launcher {
        wine = final.wine-astral;
        winetricks = final.winetricks-git;
      };
      rsi-launcher-unwrapped-git = final.rsi-launcher.override {
        wineprefix-preparer = final.wineprefix-preparer-git;
        wine = final.wine-astral;
      };
      rsi-launcher = final.callPackage ./pkgs/rsi-launcher/wrapped.nix {
        wine = final.wine-astral;
        winetricks = final.winetricks-git;
      };
      rsi-launcher-git = final.rsi-launcher.override {
        rsi-launcher-unwrapped = final.rsi-launcher-unwrapped-git;
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
      };
      star-citizen-umu = final.star-citizen-unwrapped.override {useUmu = true;};

      gameglass = final.callPackage ./pkgs/gameglass {};
      star-citizen-helper = final.callPackage ./pkgs/star-citizen-helper {};
      lug-helper =
        final.callPackage ./pkgs/lug-helper {winetricks = final.winetricks-git;};
    };
  };
}
