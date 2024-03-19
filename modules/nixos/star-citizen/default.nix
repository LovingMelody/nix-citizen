flake-self:
{ config, lib, pkgs, ... }:
let
  flake-packages = flake-self.packages.${pkgs.system};
  cfg = config.nix-citizen.starCitizen;
in with lib; {
  options.nix-citizen.starCitizen = {
    enable = mkEnableOption "Enable star-citizen";
    package = mkOption {
      description = "Package to use for star-citizen";
      type = types.package;
      default = if (builtins.hasAttr "star-citizen" pkgs) then
        pkgs.star-citizen
      else
        builtins.trace
        "warning: pkgs does not include star-citizen, (missing overlay?) using nix-citizen's package"
        flake-packages.star-citizen;
      apply = star-citizen:
        star-citizen.override {
          preCommands = ''
            ${cfg.preCommands}
            ${if cfg.helperScript.enable then
              "${cfg.helperScript.package}/bin/star-citizen-helper"
            else
              ""}
          '';
          inherit (cfg) postCommands location;

        };
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
        default = if (builtins.hasAttr "star-citizen-helper" pkgs) then
          pkgs.star-citizen-helper
        else
          builtins.trace
          "warning: pkgs does not include star-citizen-helper, (missing overlay?) using nix-citizen's package"
          flake-packages.star-citizen-helper;
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
    boot.kernel.sysctl = mkIf cfg.setLimits {
      "vm.max_map_count" = mkOverride 999 16777216;
      "fs.file-max" = mkOverride 999 524288;
    };
    security.pam = mkIf cfg.setLimits {
      loginLimits = [{
        domain = "*";
        type = "soft";
        item = "nofile";
        value = "16777216";
      }];
    };
    environment.systemPackages = [ cfg.package ];
  };
}
