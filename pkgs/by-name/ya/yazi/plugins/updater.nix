{
  lib,
  python3Packages,
  makeWrapper,
  nix-prefetch-git,
  git,
  curl,
}:

python3Packages.buildPythonApplication {
  pname = "yazi-plugins-updater";
  version = "0.1";

  format = "other";

  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  nativeCheckInputs = [ python3Packages.ruff ];

  doCheck = true;

  propagatedBuildInputs = with python3Packages; [
    requests
    packaging
  ];

  installPhase = ''
    mkdir -p $out/bin
    cp ${./update.py} $out/bin/yazi-plugins-updater
    chmod +x $out/bin/yazi-plugins-updater

    wrapProgram $out/bin/yazi-plugins-updater \
      --prefix PATH : "${
        lib.makeBinPath [
          nix-prefetch-git
          git
          curl
        ]
      }"
  '';

  checkPhase = ''
    ruff check ${./update.py}
  '';

  meta = {
    description = "Update script for Yazi plugins";
    maintainers = with lib.maintainers; [ khaneliman ];
    mainProgram = "yazi-plugins-updater";
  };
}