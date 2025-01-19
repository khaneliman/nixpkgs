{
  buildNpmPackage,

  libsecret,
  python3,
  pkg-config,

  pname,
  src,
  version,
}:
buildNpmPackage {
  pname = "${pname}-node-deps";
  inherit version src;

  npmDepsHash = "sha256-4CCvOh7XOUsdI/gzDfx0OwzE7rhdCYFO49wVv6Gn/J0=";

  nativeBuildInputs = [
    python3
    pkg-config
  ];

  buildInputs = [ libsecret ];

  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib
    cp -r node_modules $out/lib

    runHook postInstall
  '';
}
