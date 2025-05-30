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
      knownVulnerabilities = lib.optionals (info.version == "7.0.2") [
        # Quite a few of these have POC available...
        "Cause Electron 31.7.8: CVE-2025-4664"
        "Cause Electron 31.7.8: CVE-2025-4609"
        "Cause Electron 31.7.8: CVE-2025-2783"
        "Cause Electron 31.7.8: CVE-2025-1920"
        "Cause Electron 31.7.8: CVE-2025-0999"
        "Cause Electron 31.7.8: CVE-2025-0998"
        "Cause Electron 31.7.8: CVE-2025-0995"
        "Cause Electron 31.7.8: CVE-2025-0612"
        "Cause Electron 31.7.8: CVE-2025-0611"
        "Cause Electron 31.7.8: CVE-2025-0445"
        "Cause Electron 31.7.8: CVE-2024-12695"
        "Cause Electron 31.7.8: CVE-2024-12694"
        "Cause Electron 31.7.8: CVE-2024-12693"
        "Cause Electron 31.7.8: CVE-2024-10231"
        "Cause Electron 31.7.8: CVE-2024-10230"
        "Cause Electron 31.7.8: CVE-2024-10229"
      ];
    };
  }
