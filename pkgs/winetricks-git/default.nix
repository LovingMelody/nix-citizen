{ winetricks, npins, ... }:
let
  winetricks-git = npins.winetricks;
  version = builtins.substring 0 8 winetricks-git.revision;
in
winetricks.overrideAttrs(old: { version = version; src = winetricks-git; }) 
