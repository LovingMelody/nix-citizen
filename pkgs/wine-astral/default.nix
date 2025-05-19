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

  base = let
    sources = (import "${inputs.nixpkgs}/pkgs/applications/emulators/wine/sources.nix" {inherit pkgs;}).unstable;
  in {
    inherit supportFlags moltenvk;
    buildScript = "${nixpkgs-wine}/pkgs/applications/emulators/wine/builder-wow.sh";
    configureFlags = ["--disable-tests"];
    geckos = with sources; [gecko32 gecko64];
    mingwGccs = with pkgsCross; [mingw32.buildPackages.gcc14 mingwW64.buildPackages.gcc14];
    monos = with sources; [mono];
    pkgArches = [pkgs pkgsi686Linux];
    platforms = ["x86_64-linux"];
    stdenv = overrideCC stdenv (wrapCCMulti gcc14);
    wineRelease = "unstable";
  };
in
  callPackage "${nixpkgs-wine}/pkgs/applications/emulators/wine/base.nix"
  (lib.recursiveUpdate base rec {
    pname = "wine-astral-full";
    version = lib.removeSuffix "\n" (lib.removePrefix "Wine version " (builtins.readFile "${src}/VERSION"));
    src = pins.wine-tkg;
    patches = let
      blacklist = [
        "10.2+_eac_fix.patch"
        "real_path.patch"
        "winewayland-no-enter-move-if-relative.patch"
      ];
      filter = name: _type: ! (builtins.elem (builtins.baseNameOf name) blacklist);
      cleanedPatches = builtins.filterSource filter "${pins.lug-patches}/wine";
      lug-patches = builtins.attrNames (builtins.readDir cleanedPatches);
      patches = map (f: "${cleanedPatches}/${f}") lug-patches;
    in
      patches;
  })
