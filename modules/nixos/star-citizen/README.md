# nix-citizen module for star citizen

This module is meant to help simplify your system with opinionated defaults...

NameSpace: `nix-citizen.starCitizen` and `programs.rsi-launcher`

## Example Setup

```nix
{
  inputs = {
       nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
       nix-citizen.url = "github:LovingMelody/nix-citizen";
       # Optional - (Invalidates build cache if you use the cachix section)
       nix-gaming.url = "github:fufexan/nix-gaming";
       nix-citizen.inputs.nix-gaming.follows = "nix-gaming";
  };
  
  outputs = { self, nixpkgs, ...}: @inputs: {
       nixosConfigurations.HOST = nixpkgs.lib.nixosSystem {
           specialArgs = {inherit inputs;};
           modules = [
               ./configuration.nix
               nix-citizen.nixosModules.default
               {
                   # Cachix setup
                    nix.settings = {
                        substituters = ["https://nix-citizen.cachix.org"];
                        trusted-public-keys = ["nix-citizen.cachix.org-1:lPMkWc2X8XD4/7YPEEwXKKBg+SVbYTVrAaLA2wQTKCo="];
                    };
                    programs.rsi-launcher = {
                       # Enables the star citizen module
                       enable = true;
                       # Additional commands before the game starts
                       preCommands = ''
                           export DXVK_HUD=compiler;
                           export MANGO_HUD=1;
                       '';
                       # # This option is enabled by default
                       # #  Configures your system to meet some of the requirements to run star-citizen
                       # # Set `vm.max_map_count` default to `16777216` (sysctl(8))
                       # #Set `fs.file-max` default to `524288` (sysctl(8))
                       # #Also sets `security.pam.loginLimits` to increase hard (limits.conf(5))
                       # # Changes outlined in  https://github.com/starcitizen-lug/knowledge-base/wiki/Manual-Installation#prerequisites
                       # setLimits = false;
                   };
               }
               # ....
           ];
       };
    };
}
```
