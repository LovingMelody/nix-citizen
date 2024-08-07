{
  stdenv,
  lib,
  makeDesktopItem,
  makeWrapper,
  copyDesktopItems,
  bash,
  coreutils,
  findutils,
  gnome,
  zenity ? gnome.zenity,
  fetchFromGitHub,
  nix-update-script,
  ...
}:
let
  version = "2.17";
in
stdenv.mkDerivation rec {
  name = "lug-helper";
  inherit version;
  src = fetchFromGitHub {
    owner = "starcitizen-lug";
    repo = "lug-helper";
    rev = "v${version}";
    hash = "sha256-iJMyhjCzHsS8Kgukt+j8avF+WIzh4am7rtJmy0j4Tjk=";
  };

  buildInputs = [
    bash
    coreutils
    findutils
    zenity
  ];
  nativeBuildInputs = [
    copyDesktopItems
    makeWrapper
  ];
  desktopItems = [
    (makeDesktopItem {
      name = "lug-helper";
      exec = "lug-helper";
      icon = "${src}/lug-logo.png";
      comment = "Star Citizen LUG Helper";
      desktopName = "LUG Helper";
      categories = [ "Utility" ];
      mimeTypes = [ "application/x-lug-helper" ];
    })
  ];

  postInstall = ''
    mkdir -p $out/bin
    mkdir -p $out/share/lug-helper
    mkdir -p $out/share/pixmaps

    cp lug-helper.sh $out/bin/lug-helper
    cp -r lib/* $out/share/lug-helper/
    cp lug-logo.png $out/share/pixmaps/lug-helper.png
    wrapProgram $out/bin/lug-helper \
      --prefix PATH : ${
        lib.makeBinPath [
          bash
          coreutils
          findutils
          zenity
        ]
      }

  '';
  passthru.updateScript = nix-update-script { };
  meta = with lib; {
    description = "script to manage and optimize star citizen on linux";
    longDescription = ''
      lug-helper is a script designed to help you manage and optimize star citizen on linux.
    '';
    homepage = "https://github.com/starcitizen-lug/lug-helper";
    license = licenses.gpl3;
    maintainers = with maintainers; [ fuzen ];
    platforms = platforms.linux;
  };
}
