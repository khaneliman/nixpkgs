{ lib
, stdenv
, fetchFromGitHub
, boost
, brotli
, bzip2
, bzip3
, lz4
, pcre2
, xz
, zlib
, zstd
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "ugrep";
  version = "5.0.0";

  src = fetchFromGitHub {
    owner = "Genivia";
    repo = "ugrep";
    rev = "v${finalAttrs.version}";
    hash = "sha256-VAfnj/2EdkDpcS30DveUUYLSNj07sy+gvKxyGkg2mvA=";
  };

  buildInputs = [
    boost
    brotli
    bzip2
    bzip3
    lz4
    pcre2
    xz
    zlib
    zstd
  ];

  meta = with lib; {
    description = "Ultra fast grep with interactive query UI";
    homepage = "https://github.com/Genivia/ugrep";
    changelog = "https://github.com/Genivia/ugrep/releases/tag/v${finalAttrs.version}";
    maintainers = with maintainers; [ numkem mikaelfangel ];
    license = licenses.bsd3;
    platforms = platforms.all;
  };
})
