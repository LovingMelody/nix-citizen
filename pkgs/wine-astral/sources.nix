#./openxr-source.json
# ./lug-patches.json
# ./vk-sources.json
# ./wine-staging-source.json
# ./wine-source.json
# ./wine-tkg-git-source.json
{
  fetchgit,
  fetchurl,
  ...
}: let
  vk = builtins.fromJSON (builtins.readFile ./vk.json);
in rec {
  wineopenxr = fetchgit {
    inherit (builtins.fromJSON (builtins.readFile ./openxr.json)) url rev hash fetchSubmodules;
    sparseCheckout = [
      "wineopenxr"
    ];
  };
  lug-patches = fetchgit {
    inherit (builtins.fromJSON (builtins.readFile ./lug-patches.json)) url rev hash fetchSubmodules;
  };
  wine-tkg-git = fetchgit {
    inherit (builtins.fromJSON (builtins.readFile ./wine-tkg-git.json)) url rev hash fetchSubmodules;
  };
  wine-staging = fetchgit {
    inherit (builtins.fromJSON (builtins.readFile ./wine-staging.json)) url rev hash fetchSubmodules;
  };
  wine = fetchgit {
    inherit (builtins.fromJSON (builtins.readFile ./wine.json)) url rev hash fetchSubmodules;
  };
  # The build requires running ${wine}/dlls/winevulkan/make_vukan
  # but this attempts to fetch the XMLs on the web
  # Which isnt allowed due to sandboxing
  # To fix this, fetch the expected version from the script
  # And provide the expected files as arguments
  vk_version = vk.version;
  vk_xml = fetchurl {
    url = "https://raw.githubusercontent.com/KhronosGroup/Vulkan-Docs/v${vk_version}/xml/vk.xml";
    hash = vk.vk_hash;
  };
  vk_video_xml = fetchurl {
    url = "https://raw.githubusercontent.com/KhronosGroup/Vulkan-Docs/v${vk_version}/xml/video.xml";
    hash = vk.video_hash;
  };
  mono = fetchurl rec {
    inherit (builtins.fromJSON (builtins.readFile ./mono.json)) version hash;
    url = "https://github.com/wine-mono/wine-mono/releases/download/${version}/${version}-x86.msi";
  };
}
