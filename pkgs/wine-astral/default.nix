let
  MIN_KERNEL_VERSION_NTSYNC = "6.14";
  # BROKEN_LUG_WINE_PATCHES_COMMIT = "98d6a9b6ce102726030bec3ee9ff63e3fad59ad5";
in
  {
    lib,
    inputs,
    pins,
    pkgs,
    pkgsCross,
    callPackage,
    moltenvk,
    overrideCC,
    wrapCCMulti,
    gcc14,
    stdenv,
    linuxHeaders,
    linuxPackages_latest,
    fetchurl,
    wine-mono,
    autoconf,
    util-linux,
    hexdump,
    perl,
    python3,
    gitMinimal,
    ffmpeg,
    ntsync ? lib.versionAtLeast linuxHeaders.version MIN_KERNEL_VERSION_NTSYNC,
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
      else if (linuxPackages_latest.kernelAtLeast MIN_KERNEL_VERSION_NTSYNC)
      then
        pkgs.makeLinuxHeaders {
          version = "6.15";
          src = fetchurl {
            url = "mirror://kernel/linux/kernel/v6.x/linux-6.15.tar.xz";
            hash = "sha256-dYaWJUeAO+fsxAVu/JJ/slIUVIcivSgXEXLzWZq7l2Q=";
          };
        }
      else
        throw ''
          Package: `wine-astral`
          Repo: https://LovingMelody/nix-citizen
          You are attempting to use NTSYNC but the requirements have not been met
          NTSYNC requires a kernel version of ${MIN_KERNEL_VERSION_NTSYNC} or newer
            Detected latest version: ${linuxPackages_latest.kernel.version}
          To fix this error try the followwing
            - Update your pinned nixpkgs
            - wine-astral.override { ntsync = false; }
        '';

    base = {
      inherit supportFlags moltenvk;
      buildScript = null;
      configureFlags =
        ["--disable-tests" "--enable-archs=x86_64,i386"]
        ++ lib.optional (supportFlags.ffmpegSupport or true) "--with-ffmpeg";

      geckos = with sources; [gecko32 gecko64];
      mingwGccs = with pkgsCross; [mingw32.buildPackages.gcc14 mingwW64.buildPackages.gcc14];
      monos = [wine-mono];
      pkgArches = [pkgs];
      platforms = ["x86_64-linux"];
      stdenv = overrideCC stdenv (wrapCCMulti gcc14);
      wineRelease = "unstable";
      mainProgram = "wine";
    };
    nixPatches = sources.patches;
  in
    (callPackage "${nixpkgs-wine}/pkgs/applications/emulators/wine/base.nix"
      (lib.recursiveUpdate base rec {
        pname = "wine-astral-full";
        # version = lib.removeSuffix "\n" (lib.removePrefix "Wine version " (builtins.readFile "${src}/VERSION"));
        version = "10.12";
        src = fetchurl {
          url = "https://dl.winehq.org/wine/source/10.x/wine-${version}.tar.xz";
          hash = "sha256-zVcscaPXLof5hJCyKMfCaq6z/eON2eefw7VjkdWZ1r8=";
        };
        # src =
        #   if ntsync
        #   then pins.wine-tkg-ntsync
        #   else pins.wine-tkg;
        patches = let
          blacklist = [
            "10.2+_eac_fix.patch"
            "winewayland-no-enter-move-if-relative.patch"
            "hidewineexports.patch"
            "reg_show_wine.patch"
            "reg_hide_wine.patch"
            "printkey_x11-staging.patch"
            "printkey_wld.patch"
            # "cache-committed-size.patch"
          ];
          filter = name: _type: ! (builtins.elem (builtins.baseNameOf name) blacklist);
          cleanedPatches = builtins.filterSource filter "${pins.lug-patches}/wine";
          lug-patches = builtins.attrNames (builtins.readDir cleanedPatches);
          tkg-patch-dir = "${pins.wine-tkg-git}/wine-tkg-git/wine-tkg-patches";
          patches =
            [
              "${tkg-patch-dir}/proton/proton-mf-patch/gstreamer-patch1.patch"
              "${tkg-patch-dir}/proton/proton-mf-patch/gstreamer-patch2-non-staging.patch"
              "${tkg-patch-dir}/misc/enable_dynamic_wow64_def/enable_dynamic_wow64_def.patch"
              # "${tkg-patch-dir}/proton/proton-winevulkan/vulkan-1-Prefer-builtin.patch"
              # "${tkg-patch-dir}/proton/proton-winevulkan/proton10-winevulkan.patch"
              "${tkg-patch-dir}/misc/winewayland/ge-wayland.patch"
            ]
            ++ lib.optionals (! ntsync) [
              "${tkg-patch-dir}/wine-tkg-patches/proton/esync/esync-unix-mainline.patch"
              "${tkg-patch-dir}/proton/fsync/fsync-unix-mainline.patch"
              "${tkg-patch-dir}/proton/fsync/fsync_futex_waitv.patch"
            ]
            ++ [
              "${tkg-patch-dir}/misc/CSMT-toggle/CSMT-toggle.patch"
              # "${tkg-patch-dir}/proton/LAA/LAA-unix-wow64.patch"
              "${tkg-patch-dir}/proton/proton-win10-default/proton-win10-default.patch"
            ]
            ++ lib.optional ntsync "${tkg-patch-dir}/misc/fastsync/ntsync5-mainline.patch"
            ++ lib.optional (! ntsync) "${tkg-patch-dir}/hotfixes/shm_esync_fsync/HACK-user32-Always-call-get_message-request-after-waiting.mypatch"
            ++ [
              "${tkg-patch-dir}/hotfixes/GetMappedFileName/Return_nt_filename_and_resolve_DOS_drive_path.mypatch"
              "${tkg-patch-dir}/hotfixes/NosTale/nostale_mouse_fix.mypatch"
              "${tkg-patch-dir}/hotfixes/autoconf-opencl-hotfix/opencl-fixup.mypatch"
              "${tkg-patch-dir}/hotfixes/08cccb5/a608ef1.mypatch"
              "${tkg-patch-dir}/proton-tkg-specific/proton_battleye/proton_battleye.patch"
              "${tkg-patch-dir}/proton-tkg-specific/proton_eac/proton-eac_bridge.patch"
              "${tkg-patch-dir}/proton-tkg-specific/proton_eac/wow64_loader_hack.patch"
            ]
            ++ [
              (pkgs.fetchurl {
                url = "https://cdn.discordapp.com/attachments/979298119747518505/1411308578618347541/eac_60101_timeout.patch?ex=68b4d7c9&is=68b38649&hm=32ad3bbb7f86b581c47ca0ea4854af7c2cdb80e06c3ff4938848b4e0cf05d343&";
                name = "eac_60101_timeout.patch";
                hash = "sha256-hsNwkvajSein+Y9xSIpWaAlG9pULzxUMT2bND1ijX2s=";
              })
            ]
            ++ map (f: "${cleanedPatches}/${f}") lug-patches;
        in
          nixPatches ++ patches;
      })).overrideAttrs (old: {
      passthru = {
        ntsync-enabled = ntsync;
        inherit (sources) updateScript;
      };
      prePatch = ''
        ${old.prePatch or ""}
        patchShebangs tools
        # WineTKG patches need this path to exist for patches to apply properly
        echo -e "*.patch\n*.orig\n*~\n.gitignore\nautom4te.cache/*" > .gitignore
      '';
      postPatch = ''
        ${old.postPatch or ""}
        echo "Disabling wine menubuilder"
        substituteInPlace "loader/wine.inf.in" --replace-warn \
          'HKLM,%CurrentVersion%\RunServices,"winemenubuilder",2,"%11%\winemenubuilder.exe -a -r"' \
          'HKLM,%CurrentVersion%\RunServices,"winemenubuilder",2,"%11%\winemenubuilder.exe -r"'
        autoreconf -f
        autoreconf -fiv
      '';

      #  NOTE: Star Citizen requires a minimum of x86-64-v3 due to AVX requirements.
      # We can build wine-astral with support since its intended for Star Citizen.
      env.CFLAGS = lib.strings.optionalString stdenv.hostPlatform.isx86_64 "-march=x86-64-v3";
      nativeBuildInputs =
        (old.nativeBuildInputs or [])
        ++ [
          autoconf
          hexdump
          perl
          python3
          gitMinimal
        ]
        ++ lib.optional (supportFlags.ffmpegSupport or true) ffmpeg;
      buildInputs =
        old.buildInputs
        ++ [
          autoconf
          perl
          gitMinimal
        ]
        ++ lib.optional (supportFlags.ffmpegSupport or true) ffmpeg
        ++ lib.optional stdenv.hostPlatform.isLinux util-linux
        ++ lib.optional ntsync updatedHeaders;
    })
