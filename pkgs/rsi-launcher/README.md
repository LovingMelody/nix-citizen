# RSI Launcher

Installer for [RSI Launcher](https://robertsspaceindustries.com/)

## Linux user group

Solutions for common issues can be found on the
[linux user group wiki](https://starcitizen-lug.github.io).

## Basic requirements

Make sure `vm.max_map_count` is set to at least 16777216 and `fs.file-max` is
set to 524288

Currently recommended to have at least 40GB RAM + swap. If you have less than
40GB enable zram.

## Tips

To access the wine control panel please run the following:

```bash
rsi-launcher --shell
winecfg
```

## Additional Overrides

This package has an additional overrides

- `wineDllOverrides` (not compatible with useUmu)
- `tricks` additional wine tricks (non-umu only)
- `protonPath` Proton compatibility tool if umu is used. use Ge-Proton for
  latest
- `protonVerbs`

Example:

```nix
rsi-launcher = pkgs.rsi-launcher.override (prev: {
  # Recommended to keep the previous overrides
  wineDllOverrides = prev.wineDllOverrides ++ [ "dxgi=n" ];
})
```

Example:

### Credits

- [Linux User Group](https://starcitizen-lug.github.io) - A lot of the testing
  of requirements has been done there
