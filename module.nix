flake-self:
{ lib, config, pkgs,

... }:
with lib; {
  options.programs.star-citizen = {
    enable = mkEnable "Enable the star-citizen program";
    package = mkOption {
      default = flake-self.pacakges.${pkgs.system}.star-citizen;
      description = "Package for StarCitizen";
    };
    config = { };

  };
}

