{
  lib,
  stdenv,
  fetchFromGitHub,
  nix-update-script,
  rustPlatform,
  vimUtils,
}:
let
  version = "2.3.2";
  src = fetchFromGitHub {
    owner = "vyfor";
    repo = "cord.nvim";
    tag = version;
    hash = "sha256-n7a+K+n3PkVNEV8m0qvX13Ex3NUAVAaq3tYmC7ssSRY=";
  };
  extension = if stdenv.hostPlatform.isDarwin then "dylib" else "so";
  cord-nvim-rust = rustPlatform.buildRustPackage {
    pname = "cord.nvim-rust";
    inherit version src;

    cargoHash = "sha256-uJKREEHezfKIEzxz3sstyu5F2gUHb5OmkMWSaIqxf9k=";

    installPhase =
      let
        cargoTarget = stdenv.hostPlatform.rust.cargoShortTarget;
      in
      ''
        install -D target/${cargoTarget}/release/libcord.${extension} $out/lib/cord.${extension}
      '';
  };
in
vimUtils.buildVimPlugin {
  pname = "cord.nvim";
  inherit version src;

  nativeBuildInputs = [
    cord-nvim-rust
  ];

  buildPhase = ''
    runHook preBuild

    install -D ${cord-nvim-rust}/lib/cord.${extension} cord.${extension}

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -D cord $out/lua/cord.${extension}

    runHook postInstall
  '';

  doInstallCheck = true;
  nvimRequireCheck = "cord";

  passthru = {
    updateScript = nix-update-script {
      attrPath = "vimPlugins.cord-nvim.cord-nvim-rust";
    };

    # needed for the update script
    inherit cord-nvim-rust;
  };

  meta = {
    homepage = "https://github.com/vyfor/cord.nvim";
    license = lib.licenses.asl20;
  };
}
