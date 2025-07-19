let
  MIN_KERNEL_VERSION_NTSYNC = "6.14";
  # BROKEN_LUG_WINE_PATCHES_COMMIT = "98d6a9b6ce102726030bec3ee9ff63e3fad59ad5";
in
  {
    lib,
    pins,
    pkgs,
    linuxHeaders,
    linuxPackages_latest,
    fetchurl,
    ntsync ? lib.versionAtLeast linuxHeaders.version MIN_KERNEL_VERSION_NTSYNC,
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
    pkgs.wineWow64Packages.unstable.overrideAttrs (old: {
      pname = "wine-astral-full";
      patches = let
        blacklist = [
          "10.2+_eac_fix.patch"
          "winewayland-no-enter-move-if-relative.patch"
          # "cache-committed-size.patch"
        ];
        filter = name: _type: ! (builtins.elem (builtins.baseNameOf name) blacklist);
        cleanedPatches = builtins.filterSource filter "${pins.lug-patches}/wine";
        lug-patches = builtins.attrNames (builtins.readDir cleanedPatches);
        patches =
          map (f: "${cleanedPatches}/${f}") lug-patches
          ++ lib.optionals ntsync [
            "${pins.wine-tkg-git}/wine-tkg-git/wine-tkg-patches/misc/fastsync/ntsync5-mainline.patch"
          ];
      in
        old.patches ++ patches;
      passthru.ntsync-enabled = ntsync;
      postPatch = ''
        ${old.postPatch or ""}
        echo "Disabling wine menubuilder"
        substituteInPlace "loader/wine.inf.in" --replace-warn \
          'HKLM,%CurrentVersion%\RunServices,"winemenubuilder",2,"%11%\winemenubuilder.exe -a -r"' \
          'HKLM,%CurrentVersion%\RunServices,"winemenubuilder",2,"%11%\winemenubuilder.exe -r"'
      '';
      buildInputs =
        old.buildInputs
        ++ lib.optional ntsync updatedHeaders;
    })
