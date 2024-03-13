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
      default = if (builtins.hasAttr "star-citizen" pkgs) then
        pkgs.star-citizen
      else
        builtins.trace
        "warning: pkgs does not include star-citizen, (missing overlay?) using nix-citizen's package"
        flake-packages.star-citizen;
    };
    setKernelLimits = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Set vm.max_map_count and fs.file-max for you";
      };
      maxMapCount = mkOption {
        type = types.int;
        default = 16777216;
      };
      fileMax = mkOption {
        type = types.int;
        default = 524288;
      };
    };
    setLoginLimit = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Set security.pam.loginLimits";
      };
      limit = mkOption {
        type = types.int;
        default = 16777216;
      };
    };
  };
  config = mkIf cfg.enable {
    boot.kernel.sysctl = mkIf cfg.setKernelLimits.enable {
      "vm.max_map_count" = mkOverride 999 cfg.setKernelLimits.maxMapCount;
      "fs.file-max" = mkOverride 999 cfg.setKernelLimits.fileMax;
    };
    security.pam = mkIf cfg.setLoginLimit.enable {
      loginLimits = [{
        domain = "*";
        type = "soft";
        item = "nofile";
        value = "${toString cfg.setLoginLimit.limit}";
      }];
    };
    environment.systemPackages = [ cfg.package ];
  };
}
