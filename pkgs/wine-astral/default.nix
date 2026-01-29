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
    gcc15,
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
    llvmBuild ? true,
    enableAvx2 ? stdenv.hostPlatform.avx2Support,
    enableFma ? stdenv.hostPlatform.fmaSupport,
    llvmPackages_latest,
    openxr-loader,
    bash,
    runCommand,
  }: let
    sources = (import "${inputs.nixpkgs}/pkgs/applications/emulators/wine/sources.nix" {inherit pkgs;}).unstable;
    extraSources = builtins.fromJSON (builtins.readFile ./vk-sources.json);
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
          version = "6.17";
          src = fetchurl {
            url = "mirror://kernel/linux/kernel/v6.x/linux-6.17.tar.xz";
            hash = "sha256-m2BxZqHJmdgyYJgSEiL+sICiCjJTl1/N+i3pa6f3V6c=";
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
        '';

    base = {
      inherit supportFlags moltenvk;
      buildScript = null;
      configureFlags = ["--disable-tests" "--enable-archs=x86_64,i386"];

      geckos = with sources; [gecko32 gecko64];
      mingwGccs = with pkgsCross; [mingw32.buildPackages.gcc15 mingwW64.buildPackages.gcc15];
      monos = [wine-mono];
      pkgArches = [pkgs];
      platforms = ["x86_64-linux"];
      stdenv =
        if llvmBuild
        then llvmPackages_latest.stdenv
        else overrideCC stdenv (wrapCCMulti gcc15);
      wineRelease = "unstable";
      mainProgram = "wine";
    };
  in
    (callPackage "${nixpkgs-wine}/pkgs/applications/emulators/wine/base.nix"
      (lib.recursiveUpdate base rec {
        pname = "wine-astral-full";
        version = (lib.removeSuffix "\n" (lib.removePrefix "Wine version " (builtins.readFile "${src}/VERSION"))) + "-${builtins.substring 0 7 pins.wine.revision}";
        src = pins.wine;
        patches = let
          blacklist = [
            "10.2+_eac_fix.patch"
            "winewayland-no-enter-move-if-relative.patch"
            "hidewineexports.patch"
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
            "0002-wineopenxr_enable.patch"
            # "cache-committed-size.patch"
          ];
          filter = name: _type: ! (builtins.elem (builtins.baseNameOf name) blacklist);
          cleanedPatches = builtins.filterSource filter "${pins.lug-patches}/wine";
          lug-patches = builtins.attrNames (builtins.readDir cleanedPatches);
          tkg-patch-dir = "${pins.wine-tkg-git}/wine-tkg-git/wine-tkg-patches";
          addStagingPatchSet = patchSet: builtins.attrNames (builtins.readDir (builtins.filterSource (n: _: lib.hasPrefix n ".patch") "${pins.wine-staging}/patches/${patchSet}"));
          patches =
            (addStagingPatchSet "crypt32-CMS_Certificates")
            ++ (addStagingPatchSet "loader-KeyboardLayouts")
            ++ (addStagingPatchSet "ntdll-Junction_Points")
            ++ (addStagingPatchSet "ntdll-NtDevicePath")
            ++ (addStagingPatchSet "nvapi-Stub_DLL")
            ++ (addStagingPatchSet "nvcuda-CUDA_Support")
            ++ (addStagingPatchSet "nvcuvid-CUDA_Video_Support")
            ++ (addStagingPatchSet "nvencodeapi-Video_Encoder")
            ++ (addStagingPatchSet "wine.inf-Dummy_CA_Certificate")
            ++ (addStagingPatchSet "winecfg-Libraries")
            ++ (addStagingPatchSet "winecfg-Staging")
            ++ (addStagingPatchSet "winecfg-Unmounted_Devices")
            ++ (addStagingPatchSet "winedevice-Default_Drivers")
            ++ [
              "${tkg-patch-dir}/misc/CSMT-toggle/CSMT-toggle.patch"
              # "${tkg-patch-dir}/proton/LAA/LAA-unix-wow64.patch"
              "${tkg-patch-dir}/proton/proton-win10-default/proton-win10-default.patch"
              "${tkg-patch-dir}/proton-tkg-specific/proton_battleye/proton_battleye.patch"
              "${tkg-patch-dir}/proton-tkg-specific/proton_eac/Revert-ntdll-Get-rid-of-the-wine_nt_to_unix_file_nam.patch"
              "${tkg-patch-dir}/proton-tkg-specific/proton_eac/proton-eac_bridge.patch"
              "${tkg-patch-dir}/proton-tkg-specific/proton_eac/wow64_loader_hack.patch"
              "${tkg-patch-dir}/misc/enable_dynamic_wow64_def/enable_dynamic_wow64_def.patch"
              "${tkg-patch-dir}/hotfixes/GetMappedFileName/Return_nt_filename_and_resolve_DOS_drive_path.mypatch"
              "${tkg-patch-dir}/hotfixes/08cccb5/a608ef1.mypatch"
              "${tkg-patch-dir}/hotfixes/NosTale/nostale_mouse_fix.mypatch"
              "${tkg-patch-dir}/hotfixes/autoconf-opencl-hotfix/opencl-fixup.mypatch"
              "${inputs.self}/patches/hags.mypatch"
              "${inputs.self}/patches/0002-wineopenxr_enable.patch"
              "${inputs.self}/patches/disable-winemenubuilder.patch"
            ]
            ++ map (f: "${cleanedPatches}/${f}") lug-patches;
        in
          patches;
      })).overrideAttrs
    (old: rec {
      inherit (pins) proton;
      passthru = {
        inherit (sources) updateScript;

        patchedSrc = let
          applyPatches = builtins.concatStringsSep "\n" (builtins.map (p: ''patch --dir "$out/wine-source" --no-backup-if-mismatch -p1 -i '${p}' '') old.patches);
        in
          runCommand "prepare-source" {} ''
            PATH=${lib.makeBinPath (nativeBuildInputs ++ buildInputs)}:$PATH
            mkdir -p "$out"
            cp --reflink=auto -av '${old.src}' "$out/wine-source"
            chmod -R +w "$out"
            cp --reflink=auto -av ${proton}/wineopenxr "$out/wine-source/dlls/wineopenxr"
            chmod -R +w "$out"
            echo -e "*.patch\n*.orig\n*~\n.gitignore\nautom4te.cache/*" > $out/wine-source/.gitignore
            ${applyPatches}
            cd $out/wine-source
            mkdir -p tmp
            XDG_CACHE_HOME="$out/wine-source/tmp" ${lib.getExe python3} ./dlls/winevulkan/make_vulkan --xml ${vk_xml} --video-xml ${vk_video_xml}
            ${lib.getExe perl} -w   ./tools/make_requests
            ${lib.getExe perl} -w  ./tools/make_specfiles
            rm -rf tmp
            ${lib.getExe' autoconf "autoreconf"} -f
            ${lib.getExe' autoconf "autoreconf"} -fiv
            echo "wine-astral: Full patch source details can be found at https://github.com/lovingmelody/nix-citizen" > astral-info
            echo "Wine: ${old.version}" >> astral-info
            echo "TKG Patches: ${pins.wine-tkg-git.revision}" >> astral-info
            echo "Proton@bleeding-edge: ${pins.proton.revision}" >> astral-info
            echo "LUG Patches: ${pins.lug-patches.revision}" >> astral-info
          '';
      };
      prePatch = ''
        # Copy over wineopenxr to the source root
        cp --reflink=auto -av ${proton}/wineopenxr ./dlls/wineopenxr
        chmod -R +w .
        ${old.prePatch or ""}
        patchShebangs tools
        patchShebangs dlls
        # WineTKG patches need this path to exist for patches to apply properly
        echo -e "*.patch\n*.orig\n*~\n.gitignore\nautom4te.cache/*" > .gitignore
      '';
      postPatch = ''
        ${old.postPatch or ""}
        ./dlls/winevulkan/make_vulkan --xml ${vk_xml} --video-xml ${vk_video_xml}
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

      # We have to call dlls/winevulkan/make_vukan
      # but this attempts to fetch the XMLs on the web
      # Which isnt allowed due to sandboxing
      # To fix this, we fetch the expected version from the script
      # And provide the expected files as arguments
      vk_version = let
        script = builtins.readFile "${old.src}/dlls/winevulkan/make_vulkan";

        lines = builtins.filter builtins.isString (builtins.split "\n" script);

        matches = builtins.filter (m: m != null) (map (
            line:
              builtins.match ''^[[:space:]]*VK_XML_VERSION[[:space:]]*=[[:space:]]*"([^"]+)".*'' line
          )
          lines);
      in
        if matches == []
        then throw "VK_XML_VERSION not found in dlls/winevulkan/make_vulkan"
        else builtins.elemAt (builtins.head matches) 0;

      vk_xml = fetchurl {
        url = "https://raw.githubusercontent.com/KhronosGroup/Vulkan-Docs/v${vk_version}/xml/vk.xml";
        hash = extraSources.vk_hash;
      };
      vk_video_xml = fetchurl {
        url = "https://raw.githubusercontent.com/KhronosGroup/Vulkan-Docs/v${vk_version}/xml/video.xml";
        hash = extraSources.video_hash;
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
    })
