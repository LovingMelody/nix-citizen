{
  lib,
  proton-ge-bin,
  fetchzip,
}: let
  sources = builtins.fromJSON (builtins.readFile ./sources.json);
  mkCompatTool = {
    steamDisplayName,
    url,
    hash,
    version,
    pname,
  }:
    (proton-ge-bin.override {inherit steamDisplayName;}).overrideAttrs {
      inherit version pname;
      src = fetchzip {
        inherit url hash;
      };
    };
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
  }
