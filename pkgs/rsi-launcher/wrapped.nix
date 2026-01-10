{
  lib,
  steam,
  rsi-launcher-unwrapped,
  extraPkgs ? _pkgs: [],
  extraLibs ? _pkgs: [],
  extraProfile ? "", # string to append to shell profile
  extraEnvVars ? {}, # Environment variables to include in shell profile
  winetricks,
  wine,
  wineprefix-preparer,
  dxvk-nvapi-vkreflex-layer,
  includeGamemode ? false,
  gamemode,
  gameScopeEnable ? false,
  gamescope,
  includeMangoHud ? true,
  mangohud,
  pname ? "rsi-launcher",
  ...
} @ args: let
  baseArgs = builtins.removeAttrs args [
    "lib"
    "steam"
    "rsi-launcher-unwrapped"
    "gamemode"
    "mangohud"
    "includeMangoHud"
    "includeGamemode"

    "dxvk-nvapi-vkreflex-layer"
  ];
  rsi-launcher = rsi-launcher-unwrapped.override baseArgs;
in
  steam.buildRuntimeEnv {
    inherit pname;
    inherit (rsi-launcher) version meta;
    passthru = {
      inherit (rsi-launcher.passthru) extraArgs;
    };

    extraPkgs = pkgs:
      [rsi-launcher winetricks wine wineprefix-preparer]
      ++ lib.optional includeGamemode gamemode
      ++ lib.optional gameScopeEnable gamescope
      ++ extraPkgs pkgs;
    extraLibraries = pkgs:
      [dxvk-nvapi-vkreflex-layer]
      ++ lib.optional includeGamemode gamemode
      ++ lib.optional gameScopeEnable gamescope
      ++ lib.optional includeMangoHud mangohud
      ++ extraLibs pkgs;
    extraEnv = extraEnvVars;
    inherit extraProfile;

    executableName = rsi-launcher.meta.mainProgram;
    runScript = lib.getExe rsi-launcher;

    dieWithParent = false;

    extraInstallCommands = ''
      ln -s ${rsi-launcher}/share $out/share
    '';
  }
