{
  fetchurl,
  appimageTools,
  lib,
}:
# Latest Version can be found here: https://download.gameglass.gg/hub/latest-linux.yml
let
  info = builtins.fromJSON (builtins.readFile ./sources.json);
in
  appimageTools.wrapType2 {
    pname = "gameglass";
    inherit (info) version;
    src = fetchurl {
      url = "https://download.gameglass.gg/hub/GameGlass.AppImage";
      inherit (info) hash;
    };

    extraPkgs = pkgs:
      with pkgs; [
        libevdev
        libnotify
        xorg.libXtst
        nss_latest
        xorg.libxcb
        # Screenshot deps
        xorg.libXrandr
        dbus.lib
        xorg.xcbutilwm
      ];
    meta = {
      homepage = "https://gameglass.gg/";
      description = "GameGlass is a remote control app for PC games.";
      license = lib.licenses.unfree;
      insecure = true; # This package uses an insecure version of electron
    };
  }
