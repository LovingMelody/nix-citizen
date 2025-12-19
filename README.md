# nix-citizen - A Star Citizen helper flake

![Helper Flake Logo](logo.png)

## Install & Run

While it is possible to install this without using nix flakes. I'm not familiar
with this and cannot provide assistance. If you would like to learn how to use
flakes please see the
[Nixos & Flakes Book (unoffical)](https://nixos-and-flakes.thiscute.world/)

### Whats included in this flake

| Package                                                                             | Description                                                                                                                            |
| ----------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| [star-citizen](https://github.com/fufexan/nix-gaming/tree/master/pkgs/star-citizen) | Star Citizen game (standalone) This package is repackaged from nix-gaming. This has been modified to use wine-astral                   |
| [star-citizen-git](./overlays.nix)                                                  | Same as `star-citizen` but uses the latest commits for dxvk dxvk-nvapi and vkd3d-proton                                                |
| [star-citizen-umu](./overlays.nix)                                                  | Same as `star-citizen` but uses umu-launcher & proton-ge                                                                               |
| [rsi-launcher](./pkgs/rsi-launcher)                                                 | RSI Launcher (standalone). App icon & name matches the RSI Launcher. **This is the recommended Package**                               |
| [rsi-launcher-git](./pkgs/rsi-launcher)                                             | Same as `rsi-launcher` but uses the latest commits for dxvk dxvk-nvapi and vkd3d-proton                                                |
| [rsi-launcher-umu](./overlays.nix)                                                  | Same as `rsi-launcher` but uses umu-launcher & proton-ge                                                                               |
| [lug-helper](./pkgs/lug-helper)                                                     | Star Citizen's Linux Users Group Helper Script. Includes a setup script if you wish to use lutris instead of the rsi-launcher package. |
| [wine-astral](./flake.nix)                                                          | Custom Wine build (TKG, Lug, Staging + Some other patches)                                                                             |

### Cachix

Build caches are available

```nix
# configuration.nix
{
    nix.settings = {
        substituters = ["https://nix-citizen.cachix.org"];
        trusted-public-keys = ["nix-citizen.cachix.org-1:lPMkWc2X8XD4/7YPEEwXKKBg+SVbYTVrAaLA2wQTKCo="];
    };
}
```

### Flakes

Add these packages to your `home.packages` or `environment.systemPackages` after
adding nix-citizen as an input

Optionally, you are able to use the
[nix-citizen module](./modules/nixos/star-citizen)

```nix
# flake.nix
{
    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
        home-manager.url = "github:nix-community/home-manager";

        # ...

        nix-citizen.url = "github:LovingMelody/nix-citizen";

        # Optional - updates underlying without waiting for nix-citizen to update
        nix-gaming.url = "github:fufexan/nix-gaming";
        nix-citizen.inputs.nix-gaming.follows = "nix-gaming";
    };

    outputs = {self, nixpkgs, ...}@inputs: {
        # NixOS Setup
        nixosConfigurations.HOST = nixpkgs.lib.nixosSystem {
            specialArgs = {inherit inputs;};

            modules = [
                ./configuration.nix
                # ....
            ];
        };

        # HomeManager...
        homeConfigurations.HOST = inputs.home-manager.lib.homeManagerConfiguration {
            pkgs = import nixpkgs {
                system = "x86_64-linux";
                config.allowUnfree = true;
            };

            extraSpecialArgs = {inherit inputs;};
            modules = [
                ./home.nix
                # ...
             ]
        };
    };
}
```

Then to add packages....

```nix
{pkgs, inputs, ....}: {
    environment.systemPackages = with pkgs; [ #`home.packages` if using home manager
        # replace or repeat for any included package
        inputs.nix-citizen.packages.${system}.rsi-launcher
    ];

};
```

## Tips

To access the [Wine Control Panel](https://wiki.winehq.org/Control) (ex. editing
Joystick overrides) run the following:

```bash
# Adjust command to `star-citizen` if you are using the `star-citizen` package 
rsi-launcher --shell

# Wait to enter shell
wine control
```

Likewise for [winecfg](https://wiki.winehq.org/Winecfg) (ex. registry edits,
some graphics settings):

```bash
# If you used the rsi-launcher package the command is rsi-launcher
rsi-launcher --shell

# You can run your usual wine commands once you enter the shell
winecfg
```

Gstreamer errors:

```bash
rsi-launcher --shell

#
# Once you enter the shell:
wine reg add "HKCU\\Software\\Wine\\MediaFoundation" /v DisableGstByteStreamHandler /t REG_DWORD /d 1 /f
#
```

The [LUG wiki](https://wiki.starcitizen-lug.org) contains many other useful
troubleshooting steps & tips

## Credits

- [starcitizen-lug/lug-helper](https://github.com/starcitizen-lug/lug-helper) -
  Layed the ground work for the star-citizen package
- [fufexan/nix-gaming](https://github.com/fufexan/nix-gaming) - Maintaining
  Wine-GE & DXVK packages
