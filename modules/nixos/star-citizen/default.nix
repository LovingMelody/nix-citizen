{self, ...}: rec {
  flake.nixosModules.default = flake.nixosModules.StarCitizen;
  flake.nixosModules.StarCitizen = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit
      (lib)
      mkEnableOption
      mkIf
      mkMerge
      mkOption
      mkOverride
      optional
      types
      ;

    flake-packages = self.packages.${pkgs.stdenv.hostPlatform};
    legacy = config.nix-citizen.starCitizen;
    cfg = config.programs.rsi-launcher;

    smartPackage = pname:
      if (builtins.hasAttr pname pkgs)
      then pkgs.${pname}
      else
        builtins.trace
        "Warning: pkgs does not include ${pname} (missing overlay?) using nix-citizen's package"
        flake-packages.${pname};

    optionSet = {
      enable = mkEnableOption "Enable rsi-launcher";
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
        description = "Package to use for rsi-launcher";
        type = types.package;
        default = smartPackage "rsi-launcher";
        apply = rsi-launcher:
          rsi-launcher.override (_old: {
            inherit (cfg) enforceWaylandDrv;
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
          default = false;
        };
      location = mkOption {
        default = "$HOME/Games/rsi-launcher";
        type = types.str;
        description = "Path to install rsi-launcher";
      };
      preCommands = mkOption {
        default = "";
        type = types.str;
        description = "Additional commands to be run before rsi-launcher is run";
        example = ''
          export DXVK_HUD=compiler
          export MANGO_HUD=1
        '';
      };
      postCommands = mkOption {
        default = "";
        type = types.str;
        description = "Additional commands to be run after rsi-launcher is run";
      };
      setLimits = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Configures your system to meet some of the requirements to run rsi-launcher
          Set `vm.max_map_count` default to `16777216` (sysctl(8))
          Set `fs.file-max` default to `524288` (sysctl(8))

          Also sets `security.pam.loginLimits` to increase hard (limits.conf(5))

          Changes outlined in  https://github.com/starcitizen-lug/knowledge-base/wiki/Manual-Installation#prerequisites
        '';
      };
      enableNTsync = mkOption {
        type = types.bool;
        default = lib.versionAtLeast config.boot.kernelPackages.kernel.version "6.14";
        description = "Enable NTsync kernel module";
      };
      enforceWaylandDrv = mkOption {
        type = types.bool;
        default = false;
        description = "enforce wayland drv if wayland is detected. May help with Vulkan though is problematic for some WMs. Also helps with cursor issues";
      };
    };
  in {
    options.nix-citizen.starCitizen =
      (lib.removeAttrs optionSet ["package" "location"])
      // {
        package = mkOption {
          description = "Package to use for rsi-launcher";
          type = types.package;
          default = smartPackage "star-citizen";
          apply = rsi-launcher:
            rsi-launcher.override (_old: {
              inherit (cfg) enforceWaylandDrv;
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
        location = mkOption {
          default = "$HOME/Games/star-citizen";
          type = types.str;
          description = "Path to install rsi-launcher";
        };
      };
    options.programs.rsi-launcher = optionSet;
    config = mkMerge [
      {
        assertions = [
          {
            assertion = lib.versionAtLeast config.boot.kernelPackages.kernel.version "6.14" || (! cfg.enableNTsync);
            message = "Your kernel must be at least 6.14 for ntsync";
          }
        ];
        warnings = optional legacy.enable ''
          warning: `nix-citizen.StarCitizen` has been renamed to `programs.rsi-launcher`"

            This does come with breaking changes, 
            `programs.rsi-launcher.location` default path has been changed
             Old Path: `"$HOME/Games/star-citizen"`
             New Path: `"$HOME/Games/rsi-launcher"``

            The default `programs.rsi-launcher.package` has also been changed from `star-citizen` to `rsi-launcher`
            This will change your desktop shortcut to `RSI Launcher` instead of
            `Star Citizen` the package default install location is the same as above
            and will respect the location specified above.

            option `nix-citizen.starCitizen` will be removed in a future update.'';
      }
      (mkIf legacy.enable {
        programs.rsi-launcher = {
          inherit
            (legacy)
            enable
            disableEAC
            enableNTsync
            enforceWaylandDrv
            includeOverlay
            location
            package
            patchXwayland
            postCommands
            preCommands
            setLimits
            umu
            ;
        };
      })

      (mkIf cfg.enable {
        boot.kernel.sysctl = mkIf cfg.setLimits {
          "vm.max_map_count" = mkOverride 999 16777216;
          "fs.file-max" = mkOverride 999 524288;
        };
        boot = {
          extraModulePackages = with config.boot.kernelPackages; [v4l2loopback];
          kernelModules = ["snd-aloop"] ++ lib.optional cfg.enableNTsync "ntsync";
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
        # services.udev.packages = lib.optional cfg.enableNTsync [
        #   (pkgs.writeTextFile {
        #     name = "ntsync-udev-rules";
        #     text = ''KERNEL=="ntsync", MODE="0660", TAG+="uaccess"'';
        #     destination = "/etc/udev/rules.d/70-ntsync.rules";
        #   })
        # ];
        nixpkgs.overlays =
          lib.optional cfg.includeOverlay self.overlays.default
          ++ lib.optional cfg.patchXwayland self.overlays.patchedXwayland;
      })
    ];
  };
}
