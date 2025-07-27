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
  bash,
  freetype,
  vulkan-loader,
  makeWrapper,
  wineFlags ? "",
  location ? "$HOME/Games/rsi-launcher",
  tricks ? ["powershell" "corefonts" "tahoma"],
  useUmu ? false,
  protonPath ? "${proton-ge-bin.steamcompattool}/",
  protonVerbs ? ["waitforexitandrun"],
  wineDllOverrides ? ["winemenubuilder.exe=d" "nvapi=n" "nvapi64=n"],
  gameScopeEnable ? false,
  gameScopeArgs ? [],
  preCommands ? "",
  postCommands ? "",
  enableGlCache ? true,
  glCacheSize ? 10737418240, # 10GB
  disableEac ? false,
  extraLibs ? [],
  extraEnvVars ? {},
  enforceWaylandDrv ? (! useUmu), # Needed for Vulkan
  experiments ? false,
}: let
  inherit (lib.strings) concatStringsSep optionalString toShellVars;
  inherit (lib) optional;
  # Latest version can be found: https://install.robertsspaceindustries.com/rel/2/latest.yml

  gameScope = lib.strings.optionalString gameScopeEnable "gamescope ${concatStringsSep " " gameScopeArgs} --";
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    version = "2.6.0";
    pname = "rsi-launcher";
    src = fetchurl {
      url = "https://install.robertsspaceindustries.com/rel/2/RSI%20Launcher-Setup-${finalAttrs.version}.exe";
      name = "RSI Launcher-Setup-${finalAttrs.version}.exe";
      hash = "sha512-stzxoe6aS2mJ5AGJnvf89/kls+zTheF1IhrdTSdlxEh3Vyx1dobQ802qey9n3VNyWXVbz53TdKBLRx7XGxQ95g==";
    };
    buidInputs =
      [p7zip]
      ++ (
        if useUmu
        then [umu-launcher]
        else [wine winetricks wineprefix-preparer]
      )
      ++ optional gameScopeEnable gamescope;
    nativeBuildInputs = [p7zip makeWrapper];
    desktopItem = makeDesktopItem {
      name = "rsi-launcher";
      exec = "rsi-launcher %U";
      icon = "rsi-launcher";
      comment = "Roberts Space Industries Launcher";
      desktopName = "RSI Launcher";
      categories = ["Game"];
      mimeTypes = ["application/x-rsi-launcher"];
    };

    script = writeScript "rsi-launcher" ''
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
      # End extra vars

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
      ${lib.optionalString experiments ''
        # Patch libcuda if it exists...
        if [ -e /run/opengl-driver/lib/libcuda.so ]; then
          mkdir -p "$WINEPREFIX/patchedCuda"
          echo -ne $(od -An -tx1 -v /run/opengl-driver/lib/libcuda.so | tr -d '\n' | sed -e 's/00 00 00 f8 ff 00 00 00/00 00 00 f8 ff ff 00 00/g' -e 's/ /\\x/g') > "$WINEPREFIX/patchedCuda/libcuda.so"
        fi
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
              echo "Working arround known launcher error by outputting logs to $LOG_DIR"
              ${gameScope} $gamemode wine ${wineFlags} "$RSI_LAUNCHER" "$@" >"$LOG_DIR/RSIout" 2>"$LOG_DIR/RSIerr"
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
      7z e -y RSI\ Launcher.exe 1.ico 2.ico 3.ico 4.ico -r
      rm RSI\ Launcher.exe
    '';
    installPhase = ''
      install -D -m444 1.ico $out/share/icons/hicolor/16x16/apps/rsi-launcher.ico
      install -D -m444 2.ico $out/share/icons/hicolor/32x32/apps/rsi-launcher.ico
      install -D -m444 3.ico $out/share/icons/hicolor/48x48/apps/rsi-launcher.ico
      install -D -m444 4.ico $out/share/icons/hicolor/256x256/apps/rsi-launcher.ico
      install -D -m744 "${finalAttrs.script}" $out/bin/${finalAttrs.pname}
      install -D -m444 "$src" "$out/lib/RSI-Launcher-Setup-${finalAttrs.version}.exe"
      install -D -m744 "${finalAttrs.desktopItem}/share/applications/rsi-launcher.desktop" "$out/share/applications/rsi-launcher.desktop"

      substituteInPlace "$out/bin/${finalAttrs.pname}" \
        --replace-fail '@RSI_LAUNCHER_INSTALLER@' "$out/lib/RSI-Launcher-Setup-${finalAttrs.version}.exe"

      wrapProgram $out/bin/rsi-launcher \
        --prefix PATH : ${lib.makeBinPath (
        (
          if useUmu
          then [umu-launcher]
          else [wine winetricks wineprefix-preparer]
        )
        ++ optional gameScopeEnable gamescope
      )} \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath ([freetype vulkan-loader] ++ extraLibs)}${lib.optionalString experiments '':"$WINEPREFIX/patchedCuda"''}:/run/opengl-driver/lib:/run/opengl-driver-32/lib \
        --prefix XDG_DATA_DIRS : "$out"
    '';

    passthru = {
      updateScript = writeScriptBin "rsi-launcher-update.sh" ''
        #!/usr/bin/env nix-shell
        #! nix-shell -i bash -p curl yq-go common-updater-scripts

        export FILE=$(mktemp)
        curl -o "$FILE" 'https://install.robertsspaceindustries.com/rel/2/latest.yml'

        export VERSION="$(yq -r '.version' "$FILE")"
        export SHA512=$(yq -r '.files[] | select(.url | test("\\.exe$")).sha512' "$FILE")
        export SRI_HASH="$(nix hash to-sri --type sha512 "$SHA512")"
        update-source-version rsi-launcher "$VERSION" "$SRI_HASH"
      '';
    };

    meta = {
      description = "RSI Launcher installer and launch script";
      homepage = "https://robertsspaceindustries.com/";
      license = lib.licenses.unfree;
      maintainers = with lib.maintainers; [fuzen];
      platforms = ["x86_64-linux"];
      mainProgram = "rsi-launcher";
    };
  })
