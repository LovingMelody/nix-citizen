let
  MIN_KERNEL_VERSION_NTSYNC = "6.14";
  # BROKEN_LUG_WINE_PATCHES_COMMIT = "98d6a9b6ce102726030bec3ee9ff63e3fad59ad5";
in
  {
    inputs,
    lib,
    pins,
    pkgs,
    pkgsCross,
    pkgsi686Linux,
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
    ntsync ? lib.versionAtLeast linuxHeaders.version MIN_KERNEL_VERSION_NTSYNC,
  }: let
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

    base = let
      sources = (import "${inputs.nixpkgs}/pkgs/applications/emulators/wine/sources.nix" {inherit pkgs;}).unstable;
    in {
      inherit supportFlags moltenvk;
      buildScript = "${nixpkgs-wine}/pkgs/applications/emulators/wine/builder-wow.sh";
      configureFlags = ["--disable-tests"];
      geckos = with sources; [gecko32 gecko64];
      mingwGccs = with pkgsCross; [mingw32.buildPackages.gcc14 mingwW64.buildPackages.gcc14];
      monos = [wine-mono];
      pkgArches = [pkgs pkgsi686Linux];
      platforms = ["x86_64-linux"];
      stdenv = overrideCC stdenv (wrapCCMulti gcc14);
      wineRelease = "unstable";
    };
  in
    (callPackage "${nixpkgs-wine}/pkgs/applications/emulators/wine/base.nix"
      (lib.recursiveUpdate base rec {
        pname = "wine-astral-full";
        version = lib.removeSuffix "\n" (lib.removePrefix "Wine version " (builtins.readFile "${src}/VERSION"));
        src = pins.wine;
        patches = let
          blacklist = [
            "10.2+_eac_fix.patch"
            "winewayland-no-enter-move-if-relative.patch"
            "reg_show_wine.patch"
            # "cache-committed-size.patch"
          ];
          filter = name: _type: ! (builtins.elem (builtins.baseNameOf name) blacklist);
          cleanedPatches = builtins.filterSource filter "${pins.lug-patches}/wine";
          lug-patches = builtins.attrNames (builtins.readDir cleanedPatches);
          tkg-patch-dir = "${pins.wine-tkg-git}/wine-tkg-git/wine-tkg-patches";
          patches =
            lib.optionals (! ntsync) [
              "${tkg-patch-dir}/wine-tkg-patches/proton/esync/esync-unix-mainline.patch"
              "${tkg-patch-dir}/proton/fsync/fsync-unix-mainline.patch"
              "${tkg-patch-dir}/proton/fsync/fsync_futex_waitv.patch"
            ]
            ++ [
              "${tkg-patch-dir}/misc/CSMT-toggle/CSMT-toggle.patch"
              "${tkg-patch-dir}/proton/LAA/LAA-unix-wow64.patch"
              "${tkg-patch-dir}/proton/proton-win10-default/proton-win10-default.patch"
            ]
            ++ lib.optional ntsync "${tkg-patch-dir}/misc/fastsync/ntsync5-mainline.patch"
            ++ lib.optional (! ntsync) "${tkg-patch-dir}/hotfixes/shm_esync_fsync/HACK-user32-Always-call-get_message-request-after-waiting.mypatch"
            ++ [
              "${tkg-patch-dir}/hotfixes/NosTale/nostale_mouse_fix.mypatch"
              "${tkg-patch-dir}/hotfixes/autoconf-opencl-hotfix/opencl-fixup.mypatch"
              "${tkg-patch-dir}/hotfixes/08cccb5/a608ef1.mypatch"
              "${tkg-patch-dir}/proton-tkg-specific/proton_battleye/proton_battleye.patch"
              "${tkg-patch-dir}/proton-tkg-specific/proton_eac/proton-eac_bridge.patch"
              "${tkg-patch-dir}/proton-tkg-specific/proton_eac/wow64_loader_hack.patch"
            ]
            ++ map (f: "${cleanedPatches}/${f}") lug-patches;
        in
          patches;
      })).overrideAttrs (old: {
      passthru.ntsync-enabled = ntsync;
      patchArgs = ["-p1" "--forward"];
      prePatch = ''
        ${old.prePatch or ""}
        patchShebangs tools
      '';
      postPatch = ''
        ${old.postPatch or ""}
        echo "Disabling wine menubuilder"
        substituteInPlace "loader/wine.inf.in" --replace-warn \
          'HKLM,%CurrentVersion%\RunServices,"winemenubuilder",2,"%11%\winemenubuilder.exe -a -r"' \
          'HKLM,%CurrentVersion%\RunServices,"winemenubuilder",2,"%11%\winemenubuilder.exe -r"'
      '';
      nativeBuildInputs =
        old.nativeBuildInputs
        ++ [autoconf]
        ++ lib.optional ntsync updatedHeaders;
      buildInputs =
        old.buildInputs
        ++ [autoconf]
        ++ lib.optional ntsync updatedHeaders;
    })
