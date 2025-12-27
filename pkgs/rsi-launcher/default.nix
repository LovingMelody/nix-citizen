{
  lib,
  makeDesktopItem,
  writeScript,
  writeScriptBin,
  gamescope,
  winetricks,
  wine,
  wineprefix-preparer,
  umu-launcher,
  proton-ge-bin,
  stdenvNoCC,
  fetchurl,
  p7zip,
  imagemagick,
  bash,
  makeWrapper,
  pname ? "rsi-launcher",
  wineFlags ? "",
  location ? "$HOME/Games/${pname}",
  tricks ? ["powershell" "corefonts" "tahoma"],
  useUmu ? false,
  protonPath ? "${proton-ge-bin.steamcompattool}/",
  protonVerbs ? ["waitforexitandrun"],
  wineDllOverrides ? ["winemenubuilder.exe=d" "nvapi=n" "nvapi64=n" "icuuc=b" "icuin=b"],
  gameScopeEnable ? false,
  gameScopeArgs ? [],
  preCommands ? "",
  postCommands ? "",
  enableGlCache ? true,
  glCacheSize ? 10737418240, # 10GB
  disableEac ? false,
  extraLibs ? [],
  extraEnvVars ? {},
  enforceWaylandDrv ? false, # May help with vulkan but causes issues w/ some WMs
  experiments ? false,
  ... # Dont error from extra args for compatibility
} @ args: let
  extraArgs = builtins.removeAttrs args [
    "lib"
    "makeDesktopItem"
    "writeScript"
    "writeScriptBin"
    "gamescope"
    "winetricks"
    "wine"
    "wineprefix-preparer"
    "umu-launcher"
    "proton-ge-bin"
    "stdenvNoCC"
    "fetchurl"
    "p7zip"
    "bash"
    "makeWrapper"
    "pname"
    "wineFlags"
    "location"
    "tricks"
    "useUmu"
    "protonPath"
    "protonVerbs"
    "wineDllOverrides"
    "gameScopeEnable"
    "gameScopeArgs"
    "preCommands"
    "postCommands"
    "enableGlCache"
    "glCacheSize"
    "disableEac"
    "extraLibs"
    "extraEnvVars"
    "enforceWaylandDrv"
    "experiments"
  ];
  inherit (lib.strings) concatStringsSep optionalString toShellVars;
  inherit (lib) optional;
  info = builtins.fromJSON (builtins.readFile ./info.json);
  # Latest version can be found: https://install.robertsspaceindustries.com/rel/2/latest.yml

  gameScope = lib.strings.optionalString gameScopeEnable "gamescope ${concatStringsSep " " gameScopeArgs} --";
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    inherit (info) version;
    inherit pname;
    src = fetchurl {
      url = "https://install.robertsspaceindustries.com/rel/2/RSI%20Launcher-Setup-${finalAttrs.version}.exe";
      name = "RSI Launcher-Setup-${finalAttrs.version}.exe";
      inherit (info) hash;
    };
    buidInputs =
      [p7zip]
      ++ (
        if useUmu
        then [umu-launcher]
        else [wine winetricks wineprefix-preparer]
      )
      ++ optional gameScopeEnable gamescope;
    nativeBuildInputs = [p7zip makeWrapper imagemagick];
    desktopItem = makeDesktopItem {
      name = finalAttrs.pname;
      exec = "${finalAttrs.pname} %U";
      icon = finalAttrs.pname;
      comment = "Roberts Space Industries Launcher";
      desktopName =
        if finalAttrs.pname == "star-citizen"
        then "Star Citizen"
        else "RSI Launcher";
      categories = ["Game"];
      mimeTypes = ["application/x-${finalAttrs.pname}"];
    };

    script = writeScript "${finalAttrs.pname}" ''
      set -x
      export WINETRICKS_LATEST_VERSION_CHECK=disabled
      export WINEARCH="win64"
      mkdir -p "${location}"
      export WINEPREFIX="$(readlink -f "${location}")"
      ${
        optionalString
        #this option doesn't work on umu, an umu TOML config file will be needed instead
        (!useUmu)
        ''
          export WINEFSYNC=1
          export WINEESYNC=1
          export WINEDLLOVERRIDES="${lib.strings.concatStringsSep ";" wineDllOverrides}"
          export WINEDEBUG=-all

        ''
      }
      # ID for umu, not used for now
      export GAMEID="umu-starcitizen"
      export STORE="none"

      ${optionalString enableGlCache ''
        # NVIDIA
        export __GL_SHADER_DISK_CACHE=1;
        export __GL_SHADER_DISK_CACHE_SIZE=${builtins.toString glCacheSize};
        export __GL_SHADER_DISK_CACHE_PATH="$WINEPREFIX";
        export __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1;
        # MESA (Intel & AMD)
        export MESA_SHADER_CACHE_DIR="$WINEPREFIX";
        export MESA_SHADER_CACHE_MAX_SIZE="${builtins.toString (builtins.floor (glCacheSize / 1024 / 1024 / 1024))}G";

      ''}
      export DXVK_ENABLE_NVAPI=1


      USER="$(whoami)"
      RSI_LAUNCHER="$WINEPREFIX/drive_c/Program Files/Roberts Space Industries/RSI Launcher/RSI Launcher.exe"

      # Begin extra vars
      ${toShellVars extraEnvVars}

      # FIX: ICU/.NET 7+ compatibility for RSI Launcher
      # The RSI Launcher uses .NET 7+ which calls unimplemented Wine ICU functions
      # (ulocdata_getCLDRVersion, uloc_canonicalize, etc.)
      # Reference: https://forum.winehq.org/viewtopic.php?p=149288
      export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=true

      # FIX: Activate wine-astral EAC timeout patch
      # Creates /tmp/eac_wine_pid_* for EAC IPC communication
      # Only set for star-citizen (not rsi-launcher)
      # Auto-detect game channel (LIVE, PTU, EPTU) for flexibility
      if [ "${pname}" = "star-citizen" ]; then
        for channel in LIVE PTU EPTU; do
          eac_path="$WINEPREFIX/drive_c/Program Files/Roberts Space Industries/StarCitizen/$channel/EasyAntiCheat"
          if [ -d "$eac_path" ]; then
            export EAC_LAUNCHERDIR="$eac_path"
            break
          fi
        done
      fi
      # End extra vars

      if [ "${"\${1:-}"}" = "--remove-eac-dir" ]; then
         wine cmd /c "echo Deleting: %APPDATA%\EasyAntiCheat & rmdir /s /q \"%APPDATA%\\EasyAntiCheat\""
      fi

      ${
        if useUmu
        then ''
          export PROTON_VERBS="${concatStringsSep "," protonVerbs}"
          export PROTONPATH="${protonPath}"
          if [ ! -f "$RSI_LAUNCHER" ]  || [ "${"\${1:-}"}"  = "--force-install" ]; then umu-run "@RSI_LAUNCHER_INSTALLER@" /S; fi
        ''
        else ''
          # Ensure all tricks are installed
          ${toShellVars {
            inherit tricks;
            tricksInstalled = 1;
          }}

          wineprefix-preparer

          for trick in "${"\${tricks[@]}"}"; do
             if ! winetricks list-installed | grep -qw "$trick"; then
               echo "winetricks: Installing $trick"
               winetricks -q -f "$trick"
               tricksInstalled=0
             fi
          done
          if [ "$tricksInstalled" -eq 0 ]; then
            # Ensure wineserver is restarted after tricks are installed
            wineserver -k
          fi

          if [ ! -e "$RSI_LAUNCHER" ] || [ "${"\${1:-}"}"  = "--force-install" ]; then
            mkdir -p "$WINEPREFIX/drive_c/Program Files/Roberts Space Industries/StarCitizen/"{LIVE,PTU}

            # install launcher using silent install
            WINEDLLOVERRIDES="dxwebsetup.exe,dotNetFx45_Full_setup.exe,winemenubuilder.exe=d" wine @RSI_LAUNCHER_INSTALLER@ /S

            wineserver -k
          fi
        ''
      }
      ${lib.optionalString disableEac ''
        # Anti-cheat
        export EOS_USE_ANTICHEATCLIENTNULL=1
      ''}
      # Enforce wayland driver if not using x11
      # Vulkan doesnt work without this
      ${
        lib.optionalString enforceWaylandDrv ''
          if [ $XDG_SESSION_TYPE != "x11" ]; then
            export DISPLAY=
          fi''
      }
      cd "$WINEPREFIX"

      if [ "${"\${1:-}"}"  = "--shell" ]; then
        set +x
        echo "Entered Shell for star-citizen"
        exec ${lib.getExe bash};
      fi

      if [ -z "$DISPLAY" ]; then
        set -- "$@" "--in-process-gpu"
      fi

      # Only execute gamemode if it exists on the system
      if command -v gamemoderun > /dev/null 2>&1; then
        gamemode="gamemoderun"
      else
        gamemode=""
      fi
      # dlss fixes
      for dll in 'cryptbase.dll' 'devobj.dll' 'drvstore.dll'; do
        if [ ! -e "$WINEPREFIX/drive_c/windows/system32/$dll" ]; then
          ln -sv "$WINEPREFIX/drive_c/windows/system32/cryptui.dll" "$WINEPREFIX/drive_c/windows/system32/$dll"
        fi
      done

      # Experimental compatibility with lug-helper
      # Note, this will overwrite the actual sc-launch.sh
      ${lib.optionalString experiments ''
        echo "export WINEPREFIX=$WINEPREFIX" > "$WINEPREFIX/sc-launch.sh"
        echo 'export wine_path=${lib.getBin wine}' >> "$WINEPREFIX/sc-launch.sh"
        echo "export launch_log=$WINEPREFIX/sc-launch.log" >> "$WINEPREFIX/sc-launch.sh"
      ''}

      ${preCommands}
      ${
        if useUmu
        then ''
          ${gameScope} $gamemode umu-run "$RSI_LAUNCHER" "$@"
        ''
        else ''
          if [[ -t 1 ]]; then
              ${gameScope} $gamemode wine ${wineFlags} "$RSI_LAUNCHER" "$@"
          else
              export LOG_DIR=$(mktemp -d)
              echo "Working arround known launcher error by outputting logs to $WINEPREFIX/sc-launch.log"
              ${gameScope} $gamemode wine ${wineFlags} "$RSI_LAUNCHER" "$@" > "$WINEPREFIX/sc-launch.log" 2>&1
          fi
          wineserver -w
        ''
      }
      ${postCommands}
    '';
    unpackPhase = ''
      7z e -y $src app-64.7z -r
      7z e -y app-64.7z RSI\ Launcher.exe -r
      rm app-64.7z
      7z e -y RSI\ Launcher.exe 4.ico -r
      rm RSI\ Launcher.exe
    '';
    installPhase = ''
      for size in 16 32 48 256; do
        outPath=$out/share/icons/hicolor/"$size"x"$size"/apps/${finalAttrs.pname}.png
        install -d "$(dirname "$outPath")"
        magick -background none 4.ico -resize "$size"x"$size" "$outPath"
      done
      install -D -m744 "${finalAttrs.script}" $out/bin/${finalAttrs.pname}
      install -D -m444 "$src" "$out/lib/RSI-Launcher-Setup-${finalAttrs.version}.exe"
      install -D -m744 "${finalAttrs.desktopItem}/share/applications/${finalAttrs.pname}.desktop" "$out/share/applications/${finalAttrs.pname}.desktop"

      substituteInPlace "$out/bin/${finalAttrs.pname}" \
        --replace-fail '@RSI_LAUNCHER_INSTALLER@' "$out/lib/RSI-Launcher-Setup-${finalAttrs.version}.exe"

      wrapProgram $out/bin/${finalAttrs.pname} \
         --prefix PATH : ${lib.makeBinPath ((
          if useUmu
          then [umu-launcher]
          else [wine winetricks wineprefix-preparer]
        )
        ++ optional gameScopeEnable gamescope)} \
         --prefix XDG_DATA_DIRS : "$out"
    '';

    passthru = {
      updateScript = writeScriptBin "rsi-launcher-update.sh" builtins.readFile ./update.sh;
      extraArgs =
        lib.warnIf (extraArgs != {}) ''
          ${pname}: Extra arguments are not used in the derivation, they will be ignored.
            In a future update this will error.
        ''
        builtins.attrNames
        extraArgs;
    };

    meta = {
      description = "RSI Launcher installer and launch script";
      homepage = "https://robertsspaceindustries.com/";
      license = lib.licenses.unfree;
      maintainers = with lib.maintainers; [fuzen];
      platforms = ["x86_64-linux"];
      mainProgram = finalAttrs.pname;
    };
  })
