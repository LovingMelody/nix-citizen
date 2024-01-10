{ lib, makeDesktopItem, writeShellScriptBin, symlinkJoin, location ? ""
, pname ? "star-citizen-helper", gnome, zenity ? gnome.zenity, pkgs, curl }:
let
  version = "0.1a";
  script = writeShellScriptBin pname ''
    zenity_prompt() {
      ${zenity}/bin/zenity --question --text="$1" --title="$2" --width=500 --height=100
    }
    KNOWN_PATH=${location};
    if [ -z "$KNOWN_PATH" ]; then
       MANIFEST_PATH="$WINEPREFIX/drive_c/Program Files/Roberts Space Industries/StarCitizen/LIVE/build_manifest.id"
    else
       MANIFEST_PATH="$KNOWN_PATH/drive_c/Program Files/Roberts Space Industries/StarCitizen/LIVE/build_manifest.id"
    fi
    P4VER=$( cat "$MANIFEST_PATH" | grep -Po '"RequestedP4ChangeNum": "\K[^"]*')
    APPDATA_DIR="$WINEPREFIX/drive_c/users/$USER/AppData/Local/Star Citizen"
    if [ -z "$P4VER" ]; then
        echo "Error: Failed to get manifest version"
        exit 1
    fi
    USER="$(whoami)"
    set -e
    LATEST_VERSION="$(${curl}/bin/curl -s 'https://status.robertsspaceindustries.com/index.xml' | grep '🚀 Star Citizen.*-live.* deployed' | head -1)"
    if (echo "$LATEST_VERSION" | grep -q "$P4VER"); then
        echo "Star citizen client is up to date"
    else
        echo "Update detected removing shader cache..."
        if !(zenity_prompt "Update detected, do you want to remove shader cache? (Recommended)" "Star Citizen Helper"); then
            echo "Aborted";
            exit 0;
        fi
        for datadir in "$APPDATA_DIR/*"; do
            if [ -d "$datadir/shaders" ]; then
                echo "Deleting $datadir/shaders ..."
                rm -r "$datadir/shaders"
            fi
        done
    fi
  '';
  icon = ./../../logo.png;
  desktopItems = makeDesktopItem {
    name = pname;
    exec = "${script}/bin/${pname} %U";
    inherit icon;
    comment = "Star Citizen Helper script EXPERIMENTAL";
    desktopName = "Star Citizen Helper (Experimental)";
    categories = [ "Utility" ];
    mimeTypes = [ "application/x-star-citizen-helper" ];
  };
in symlinkJoin {
  name = pname;
  paths = [ desktopItems script ];

  meta = {
    description = "Star Citizen helper script (Experimental)";
    homepage = "https://github.com/LovingMelody/NixCitizen";
    license = lib.licenses.gpl3;
    maintainers = with lib.maintainers; [ fuzen ];
    platforms = [ "x86_64-linux" ];
  };
}
