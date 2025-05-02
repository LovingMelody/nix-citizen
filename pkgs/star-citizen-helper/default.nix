{
  lib,
  makeDesktopItem,
  rustPlatform,
  pname ? "star-citizen-helper",
  gnome,
  zenity ? gnome.zenity,
  pkg-config,
  openssl,
  makeWrapper,
  ...
}: let
  tomlConfig = builtins.fromTOML (builtins.readFile ./Cargo.toml);
  inherit (tomlConfig.package) name version;
  binPath = lib.makeBinPath [zenity];
in
  rustPlatform.buildRustPackage {
    inherit name version;
    src = ./.;

    cargoLock.lockFile = ./Cargo.lock;
    nativeBuildInputs = [
      pkg-config
      makeWrapper
    ];
    buildInputs = [openssl];

    postInstall = ''
      wrapProgram "$out/bin/${name}" --prefix PATH : "${binPath}"
    '';

    desktopItems = makeDesktopItem {
      name = pname;
      exec = "${name} %U";
      icon = ./../../logo.png;
      comment = "Star Citizen Helper script EXPERIMENTAL";
      desktopName = "Star Citizen Helper (Experimental)";
      categories = ["Utility"];
      mimeTypes = ["application/x-star-citizen-helper"];
    };
    meta = {
      description = "Star Citizen helper script (Experimental)";
      homepage = "https://github.com/LovingMelody/NixCitizen";
      license = lib.licenses.gpl3;
      maintainers = with lib.maintainers; [fuzen];
      platforms = ["x86_64-linux"];
    };
  }
