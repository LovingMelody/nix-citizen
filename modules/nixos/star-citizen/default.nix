{self, ...}: {
  flake.nixosModules.StarCitizen = {
    config,
    lib,
    pkgs,
    ...
  }: let
    flake-packages = self.packages.${pkgs.stdenv.hostPlatform};
    cfg = config.nix-citizen.starCitizen;
    smartPackage = pname:
      if (builtins.hasAttr pname pkgs)
      then pkgs.${pname}
      else
        builtins.trace
        "Warning: pkgs does not include ${pname} (missing overlay?) using nix-citizen's package"
        flake-packages.${pname};
  in
    with lib; {
      options.nix-citizen.starCitizen = {
        enable = mkEnableOption "Enable star-citizen";
        # If you manually define  your nixpkgs set, this wont work but it wont error
        includeOverlay =
          mkEnableOption "Enable nix-citizen overlay"
          // {
            default = true;
          };
        patchXwayland = mkEnableOption ''
          Enable xwayland overlay with a patch intended to help fix cursor issues
        '';
        package = mkOption {
          description = "Package to use for star-citizen";
          type = types.package;
          default = smartPackage "star-citizen";
          apply = star-citizen:
            star-citizen.override (_old: {
              useUmu = cfg.umu.enable;
              disableEac = cfg.disableEAC;
              umu-launcher = pkgs.umu-launcher.override (prev: {
                extraLibraries = pkgs: let
                  prevLibs =
                    if prev ? extraLibraries
                    then prev.extraLibraries pkgs
                    else [];
                  graphicsLibs = with config.hardware.graphics;
                    if pkgs.stdenv.hostPlatform.is64bit
                    then [package] ++ extraPackages
                    else [package32] ++ extraPackages32;
                  gamemodeLibs = lib.optional config.programs.gamemode.enable pkgs.gamemode.lib;
                  additionalLibs = graphicsLibs ++ gamemodeLibs;
                in
                  prevLibs ++ additionalLibs;
              });
              preCommands = ''
                ${cfg.preCommands}
              '';
              inherit (cfg) postCommands location;
            });
        };
        umu = {
          enable = mkEnableOption "Enable umu launcher";
          proton = mkOption {
            type = types.str;
            default = "GE-Proton";
            description = "Proton Version";
          };
        };
        disableEAC =
          mkEnableOption "Disable EasyAntiCheat"
          // {
            default = true;
          };
        location = mkOption {
          default = "$HOME/Games/star-citizen";
          type = types.str;
          description = "Path to install star-citizen";
        };
        preCommands = mkOption {
          default = "";
          type = types.str;
          description = "Additional commands to be run before star-citizen is run";
          example = ''
            export DXVK_HUD=compiler
            export MANGO_HUD=1
          '';
        };
        postCommands = mkOption {
          default = "";
          type = types.str;
          description = "Additional commands to be run after star-citizen is run";
        };
        helperScript = {
          enable = mkOption {
            default = false;
            type = types.bool;
          };
          package = mkOption {
            description = "Package to use for star-citizen-helper";
            type = types.package;
          };
        };
        setLimits = mkOption {
          type = types.bool;
          default = true;
          description = ''
            Configures your system to meet some of the requirements to run star-citizen
            Set `vm.max_map_count` default to `16777216` (sysctl(8))
            Set `fs.file-max` default to `524288` (sysctl(8))

            Also sets `security.pam.loginLimits` to increase hard (limits.conf(5))

            Changes outlined in  https://github.com/starcitizen-lug/knowledge-base/wiki/Manual-Installation#prerequisites
          '';
        };
      };
      config = mkIf cfg.enable {
        assertions = [
          {
            assertion = cfg.helperScript.enable;
            message = "This `helperScript` has been removed nix-citizen as the feature has been added to the RSI Launcher";
          }
        ];
        boot.kernel.sysctl = mkIf cfg.setLimits {
          "vm.max_map_count" = mkOverride 999 16777216;
          "fs.file-max" = mkOverride 999 524288;
        };
        security.pam = mkIf cfg.setLimits {
          loginLimits = [
            {
              domain = "*";
              type = "soft";
              item = "nofile";
              value = "16777216";
            }
          ];
        };
        environment.systemPackages = [cfg.package];
        nixpkgs.overlays =
          lib.optional cfg.includeOverlay self.overlays.default
          ++ lib.optional cfg.patchXwayland self.overlays.patchedXwayland;
      };
    };
}
