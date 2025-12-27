{
  lib,
  stdenvNoCC,
  fetchzip,
  staging ? false,
  ...
}: let
  info = builtins.fromJSON (builtins.readFile ./sources.json);
in
  stdenvNoCC.mkDerivation {
    pname = "lug-wine${lib.optionalString staging "-staging"}-bin";
    inherit (info) version;
    src = fetchzip {
      url =
        if staging
        then info.staging_url
        else info.base_url;
      hash =
        if staging
        then info.staging_hash
        else info.base_hash;
    };
    installPhase = "cp -r $src $out";
    meta = {
      description = "lug-wine prebuilt binaries intended for FHS environments";
      homepage = "https://github.com/starcitizen-lug/lug-wine";
      license = lib.licenses.mit;
      maintainers = with lib.maintainers; [fuzen];
    };
  }
