{
  lib,
  stdenvNoCC,
  fetchurl,
  p7zip,
  imagemagick,
  ...
}: let
  info = builtins.fromJSON (builtins.readFile ./info.json);
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "rsi-installer";
    inherit (info) version;

    src = fetchurl {
      url = "https://install.robertsspaceindustries.com/rel/2/RSI%20Launcher-Setup-${finalAttrs.version}.exe";
      name = "RSI Launcher-Setup-${finalAttrs.version}.exe";
      inherit (info) hash;
    };
    nativeBuildInputs = [imagemagick p7zip];
    unpackPhase = ''
      7z e -y $src app-64.7z -r
      7z e -y app-64.7z RSI\ Launcher.exe -r
      rm app-64.7z
      7z e -y RSI\ Launcher.exe 4.ico -r
      rm RSI\ Launcher.exe
    '';
    installPhase = ''
      for size in 16 32 48 256; do
        outPath=$out/share/icons/hicolor/"$size"x"$size"/apps/rsi-launcher.png
        install -d "$(dirname "$outPath")"
        magick -background none 4.ico -resize "$size"x"$size" "$outPath"
      done
      install -D -m744 "$src" "$out/bin/RSI-Launcher-Setup-${finalAttrs.version}.exe"
    '';
    meta = {
      description = "RSI Launcher installer";
      homepage = "https://robertsspaceindustries.com/";
      license = lib.licenses.unfree;
      maintainers = with lib.maintainers; [fuzen];
      platforms = ["x86_64-linux"];
      mainProgram = "RSI-Launcher-Setup-${finalAttrs.version}.exe";
    };
  })
