{
  lib,
  proton-ge-bin,
  fetchzip,
  stdenv,
}: let
  sources = builtins.fromJSON (builtins.readFile ./sources.json);
  mkCompatTool = {
    steamDisplayName,
    url,
    hash,
    version,
    pname,
    meta ? {},
  }:
    (proton-ge-bin.override {inherit steamDisplayName;}).overrideAttrs (o: {
      inherit version pname;
      src = fetchzip {
        inherit url hash;
      };
      meta = o.meta // meta;
    });
  v4 = stdenv.targetPlatform.isx86_64 && stdenv.targetPlatform.avx512Support;
  v3 = stdenv.targetPlatform.isx86_64 && stdenv.targetPlatform.avxSupport;
  # v2 = stdenv.targetPlatform.isx86_64 && stdenv.targetPlatform.sse4_2Support;
  arm = stdenv.isAarch64;
in
  lib.recurseIntoAttrs {
    proton-ge-bin = mkCompatTool {
      inherit (sources.proton-ge-bin) version url hash steamDisplayName;
      pname = "proton-ge-bin";
    };
    dw-proton-bin = mkCompatTool {
      inherit (sources.dw-proton-bin) version url hash steamDisplayName;
      pname = "dw-proton-bin";
    };
    proton-cachyos-bin = mkCompatTool {
      inherit
        (
          if arm
          then sources.proton-cachyos-amd64-bin
          else if v4
          then sources.proton-cachyos-x86_64_v4-bin
          else if v3
          then sources.proton-cachyos-x86_64_v3-bin
          else sources.proton-cachyos-bin
        )
        version
        url
        hash
        steamDisplayName
        ;
      pname = "proton-cachyos-bin";
      meta.platforms = ["x86_64-linux" "aarch64-linux"];
    };
    proton-em-bin = mkCompatTool {
      inherit (sources.proton-em-bin) version url hash steamDisplayName;
      pname = "proton-em-bin";
    };
  }
