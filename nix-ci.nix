{
  enable = true;
  cachix = {
    name = "nix-citizen";
    public-key = "nix-citizen.cachix.org-1:lPMkWc2X8XD4/7YPEEwXKKBg+SVbYTVrAaLA2wQTKCo=";
  };
  doNotBuild = [
    "gameglass"
  ];
}
