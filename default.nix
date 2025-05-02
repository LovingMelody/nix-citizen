(
  import
  (
    builtins.fetchTarball {
      url = "https://github.com/edolstra/flake-compat/archive/refs/tags/v1.1.0.tar.gz";
      sha256 = "19d2z6xsvpxm184m41qrpi1bplilwipgnzv9jy17fgw421785q1m";
    }
  )
  {
    src = ./.;
  }
)
.defaultNix
