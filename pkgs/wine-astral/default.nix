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
        src =
          if ntsync
          then pins.wine-tkg-ntsync
          else pins.wine-tkg;
        patches = let
          blacklist = [
            "10.2+_eac_fix.patch"
            "real_path.patch"
            "winewayland-no-enter-move-if-relative.patch" # See BROKEN_LUG_WINE_PATCHES_COMMIT
            "cache-committed-size.patch"
          ];
          filter = name: _type: ! (builtins.elem (builtins.baseNameOf name) blacklist);
          cleanedPatches = builtins.filterSource filter "${pins.lug-patches}/wine";
          lug-patches = builtins.attrNames (builtins.readDir cleanedPatches);
          patches = map (f: "${cleanedPatches}/${f}") lug-patches;
        in
          patches;
      })).overrideAttrs (old: {
      passthru.ntsync-enabled = ntsync;
      prePatch = ''
        ${old.prepatch or ""}
        echo "Disabling wine menubuilder"
        substituteInPlace "loader/wine.inf.in" --replace-warn \
          'HKLM,%CurrentVersion%\RunServices,"winemenubuilder",2,"%11%\winemenubuilder.exe -a -r"' \
          'HKLM,%CurrentVersion%\RunServices,"winemenubuilder",2,"%11%\winemenubuilder.exe -r"'
      '';
      buildInputs =
        old.buildInputs
        ++ lib.optional ntsync updatedHeaders;
    })
