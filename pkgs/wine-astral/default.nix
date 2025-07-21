let
  MIN_KERNEL_VERSION_NTSYNC = "6.14";
  # BROKEN_LUG_WINE_PATCHES_COMMIT = "98d6a9b6ce102726030bec3ee9ff63e3fad59ad5";
in
  {
    inputs,
    lib,
    pins,
    pkgs,
    linuxHeaders,
    linuxPackages_latest,
    fetchurl,
    ntsync ? lib.versionAtLeast linuxHeaders.version MIN_KERNEL_VERSION_NTSYNC,
    autoconf,
    hexdump,
    perl,
    ...
  }: let
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
  in
    pkgs.wineWow64Packages.stagingFull.overrideAttrs (old: {
      src =
        old.src
        // {
          staging = old.src.staging.overrideAttrs {
            disabledPatches = [
              "ntdll-NtAlertThreadByThreadId"
              "ntdll-ForceBottomUpAlloc"
              "ntdll-Hide__Wine_Exports"
            ];
          };
        };
      pname = "wine-astral-full";
      nativeBuildInputs = old.nativeBuildInputs ++ [autoconf hexdump perl];
      patches = let
        blacklist = [
          # "10.2+_eac_fix.patch"
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
            "${tkg-patch-dir}/proton/proton-mf-patch/gstreamer-patch1.patch"
            "${tkg-patch-dir}/proton/proton-mf-patch/gstreamer-patch2-non-staging.patch"
            "${tkg-patch-dir}/misc/enable_dynamic_wow64_def/enable_dynamic_wow64_def.patch"
            "${tkg-patch-dir}/proton/LAA/LAA-unix-wow64.patch"
            "${tkg-patch-dir}/proton/proton-winevulkan/vulkan-1-Prefer-builtin.patch"
            "${tkg-patch-dir}/proton/proton-winevulkan/proton10-winevulkan.patch"
            "${tkg-patch-dir}/misc/winewayland/ge-wayland.patch"
            "${tkg-patch-dir}/misc/josh-flat-theme/josh-flat-theme.patch"
            "${tkg-patch-dir}/proton/proton-win10-default/proton-win10-default.patch"
          ]
          ++ lib.optional ntsync "${tkg-patch-dir}/misc/fastsync/ntsync5-mainline.patch"
          ++ [
            "${tkg-patch-dir}/hotfixes/GetMappedFileName/Return_nt_filename_and_resolve_DOS_drive_path.mypatch"
            "${tkg-patch-dir}/hotfixes/08cccb5/a608ef1.mypatch"
          ]
          ++ lib.optional (! ntsync) "${tkg-patch-dir}/hotfixes/shm_esync_fsync/HACK-user32-Always-call-get_message-request-after-waiting.mypatch"
          ++ [
            "${tkg-patch-dir}/hotfixes/NosTale/nostale_mouse_fix.mypatch"
            "${tkg-patch-dir}/hotfixes/autoconf-opencl-hotfix/opencl-fixup.mypatch"
          ]
          ++ map (f: "${cleanedPatches}/${f}") lug-patches;
      in
        old.patches ++ patches;
      passthru.ntsync-enabled = ntsync;
      postPatch = ''
        ${old.postPatch or ""}
        echo "Disabling wine menubuilder"
        substituteInPlace "loader/wine.inf.in" --replace-warn \
          'HKLM,%CurrentVersion%\RunServices,"winemenubuilder",2,"%11%\winemenubuilder.exe -a -r"' \
          'HKLM,%CurrentVersion%\RunServices,"winemenubuilder",2,"%11%\winemenubuilder.exe -r"'
        patchShebangs tools
      '';
      buildInputs =
        old.buildInputs
        ++ [autoconf hexdump perl]
        ++ lib.optional ntsync updatedHeaders;
    })
