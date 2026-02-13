let
  MIN_KERNEL_VERSION_NTSYNC = "6.14";
  # BROKEN_LUG_WINE_PATCHES_COMMIT = "98d6a9b6ce102726030bec3ee9ff63e3fad59ad5";
in
  {
    lib,
    inputs,
    pkgs,
    pkgsCross,
    callPackage,
    moltenvk,
    overrideCC,
    wrapCCMulti,
    gcc_latest,
    stdenv,
    linuxHeaders,
    linuxPackages_latest,
    fetchurl,
    autoconf,
    util-linux,
    hexdump,
    perl,
    python3,
    gitMinimal,
    llvmBuild ? true,
    enableAvx2 ? stdenv.hostPlatform.avx2Support,
    enableFma ? stdenv.hostPlatform.fmaSupport,
    llvmPackages_latest,
    openxr-loader,
    bash,
    fetchgit,
    astralSources ? pkgs.callPackage ./sources.nix {inherit fetchgit fetchurl;},
  }: let
    sources = (import "${inputs.nixpkgs}/pkgs/applications/emulators/wine/sources.nix" {inherit pkgs;}).unstable;
    supportFlags = import ./supportFlags.nix;
    nixpkgs-wine = builtins.path {
      path = inputs.nixpkgs;
      name = "source";
      filter = path: type: let
        wineDir = "${inputs.nixpkgs}/pkgs/applications/emulators/wine/";
      in
        (type == "directory" && (lib.hasPrefix path wineDir))
        || (type != "directory" && (lib.hasPrefix wineDir path));
    };
    updatedHeaders =
      if (lib.versionAtLeast linuxHeaders.version MIN_KERNEL_VERSION_NTSYNC)
      then linuxHeaders
      else
        throw ''
          Package: `wine-astral`
          Repo: https://LovingMelody/nix-citizen
          You are attempting to use NTSYNC but the requirements have not been met
          NTSYNC requires a kernel version of ${MIN_KERNEL_VERSION_NTSYNC} or newer
            Detected latest version: ${linuxPackages_latest.kernel.version}
          To fix this error try the followwing
            - Update your pinned nixpkgs
        '';

    base = {
      inherit supportFlags moltenvk;
      buildScript = null;
      configureFlags = ["--disable-tests" "--enable-archs=x86_64,i386"];

      geckos = with sources; [gecko32 gecko64];
      mingwGccs = with pkgsCross; [mingw32.buildPackages.gcc_latest mingwW64.buildPackages.gcc_latest];
      monos = [astralSources.mono];
      pkgArches = [pkgs];
      platforms = ["x86_64-linux"];
      stdenv =
        if llvmBuild
        then llvmPackages_latest.stdenv
        else overrideCC stdenv (wrapCCMulti gcc_latest);
      # wineRelease = "unstable";
      mainProgram = "wine";
    };
  in
    (callPackage "${nixpkgs-wine}/pkgs/applications/emulators/wine/base.nix"
      (lib.recursiveUpdate base {
        pname = "wine-astral-full";
        version = (builtins.fromJSON (builtins.readFile ./wine.json)).version + "-${builtins.substring 0 7 astralSources.wine.rev}";
        src = null; # astralSources.wine;
        patches = [];
      })).overrideAttrs
    (old: rec {
      inherit (astralSources) wineopenxr vk_version;
      srcs = with astralSources; [
        vk_video_xml
        vk_xml
        wine
        wine-staging
        wineopenxr
        wine-tkg-git
        lug-patches
        ./../../patches
      ];
      stagingPatches = [
        # "loader-KeyboardLayouts"
        "ntdll-NtDevicePath"
        "wine.inf-Dummy_CA_Certificate"
        "winecfg-Libraries"
        "winecfg-Staging"
        "winedevice-Default_Drivers"
      ];
      lugBlacklist = [
        "10.2+_eac_fix.patch"
        "winewayland-no-enter-move-if-relative.patch"
        # "hidewineexports.patch"
        "reg_show_wine.patch"
        "reg_hide_wine.patch"
        "printkey_x11-staging.patch"
        "printkey_wld.patch"
        "real_path.patch"
        "9196_process_idle_event_client_side.patch"
        "revert-egl-default.patch"
        "winefacewarehacks-minimal.patch"
        "default-to-wayland.patch"
        "0001-wineopenxr_add.patch"
        # "0002-wineopenxr_enable.patch"
        # "cache-committed-size.patch"
      ];
      tkgPatches = [
        "misc/CSMT-toggle/CSMT-toggle.patch"
        #"proton/LAA/LAA-unix-wow64.patch"
        "proton/proton-win10-default/proton-win10-default.patch"
        "proton-tkg-specific/proton_battleye/proton_battleye.patch"
        "proton-tkg-specific/proton_eac/Revert-ntdll-Get-rid-of-the-wine_nt_to_unix_file_nam.patch"
        "proton-tkg-specific/proton_eac/proton-eac_bridge.patch"
        "proton-tkg-specific/proton_eac/wow64_loader_hack.patch"
        "misc/enable_dynamic_wow64_def/enable_dynamic_wow64_def.patch"
        "hotfixes/GetMappedFileName/Return_nt_filename_and_resolve_DOS_drive_path.mypatch"
        "hotfixes/08cccb5/a608ef1.mypatch"
        "hotfixes/NosTale/nostale_mouse_fix.mypatch"
        "hotfixes/autoconf-opencl-hotfix/opencl-fixup.mypatch"
      ];
      patches = [];

      sourceRoot = "wine";
      unpackPhase = ''
        runHook preUnpack
        mkdir -p wine
        mkdir -p patches
        chmod a+w wine
        chmod a+w patches
        for src in $srcs; do
          case "$src" in
              *-video.xml)
                  cp "$src" video.xml
                  ;;
              *-vk.xml)
                  cp "$src" vk.xml
                  ;;
              *-wine-staging-* )
                  cp -r "$src" wine-staging
                  ;;
              *-wine-tkg-git-* )
                  cp -r "$src" wine-tkg-git
                  ;;
              *-Proton-* )
                  mkdir -p wine/dlls
                  chmod a+w wine/dlls
                  cp -r "$src/wineopenxr" wine/dlls/wineopenxr
                  ;;
              *-wine-* )
                  cp -r "$src"/* wine/
                  ;;
              *-patches-* )
                  cp -r "$src" lug-patches
                  ;;
              *-patches )
                  cp -r "$src" patches
          esac
        done
        mkdir -p tmp
        runHook postUnpack
      '';

      prePatch = ''
        # Copy over wineopenxr to the source root
        ${lib.optionalString ((old.prePatch or null) != null) (old.prePatch or "")}
        patchShebangs tools
        patchShebangs dlls
        patchShebangs ../wine-staging/staging
        patchShebangs ../wine-staging/patches
        chmod -R a+w .
      '';

      patchPhase = ''

        runHook prePatch
        ./../wine-staging/staging/patchinstall.py DESTDIR=. ${builtins.concatStringsSep " " stagingPatches}
        ${builtins.concatStringsSep "\n" (builtins.map (p: "patch -p1 -i ../wine-tkg-git/wine-tkg-git/wine-tkg-patches/${p}") tkgPatches)}
        for patch in ../lug-patches/wine/*; do
                # Extract the filename without the path
                filename=$(basename "$patch")
                # Check if the filename is not in the blacklist
                ${builtins.concatStringsSep "\n" (builtins.map (p: "[[ $patch =~ '${p}' ]] && continue") lugBlacklist)}
                patch -p1 -i "$patch"
        done
        for patch in ../patches/*.mypatch; do
          patch -p1 < "$patch"
        done
        runHook postPatch
      '';
      postPatch = ''
        XDG_CACHE_HOME="$src/../tmp"
        ${old.postPatch or ""}
        chmod a+w dlls/winevulkan
        ./dlls/winevulkan/make_vulkan --xml ${astralSources.vk_xml} --video-xml ${astralSources.vk_video_xml}
        ./tools/make_requests
        ./tools/make_specfiles
        autoreconf -f
        autoreconf -fiv
      '';

      #  NOTE: Star Citizen requires a minimum of x86-64-v3 due to AVX requirements.
      # We can build wine-astral with support since its intended for Star Citizen.
      env = {
        XDG_CACHE_HOME = "$src/build-cache";
        NIX_CFLAGS_COMPILE =
          builtins.concatStringsSep " "
          (
            [
              "-Wno-error=implicit-function-declaration"
              "-Wno-error=incompatible-pointer-types"
              "-Wno-error=int-conversion"
            ]
            ++ lib.optional (! enableAvx2) "-mavx"
            ++ lib.optional enableAvx2 "-mavx2"
            ++ lib.optional enableFma "-mfma"
          );
      };

      nativeBuildInputs =
        (old.nativeBuildInputs or [])
        ++ [
          autoconf
          hexdump
          perl
          python3
          gitMinimal
          bash
        ];
      buildInputs =
        old.buildInputs
        ++ [
          autoconf
          perl
          gitMinimal
          updatedHeaders
          openxr-loader
          bash
        ]
        ++ lib.optional stdenv.hostPlatform.isLinux util-linux;
      passthru = {};
    })
