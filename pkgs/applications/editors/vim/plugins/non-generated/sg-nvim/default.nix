{
  lib,
  fetchFromGitHub,
  nix-update-script,
  openssl,
  pkg-config,
  rustPlatform,
  vimPlugins,
  vimUtils,
}:
let
  version = "1.1.0";
  src = fetchFromGitHub {
    owner = "sourcegraph";
    repo = "sg.nvim";
    tag = "v${version}";
    hash = "sha256-Kxp5bAMjxgiLStN8ofiSLMgfZIRKGD+8mVxXU76mR6U=";
  };

  sg-nvim-rust = rustPlatform.buildRustPackage {
    pname = "sg-nvim-rust";
    inherit version src;

    cargoHash = "sha256-2Xgz2FMSxJrgE0lKvEfecgU40iIwpWZFJ1YDeeA1HE0=";

    nativeBuildInputs = [ pkg-config ];

    buildInputs = [ openssl ];

    prePatch = ''
      rm .cargo/config.toml
    '';

    env.OPENSSL_NO_VENDOR = true;

    cargoBuildFlags = [ "--workspace" ];

    # tests are broken
    doCheck = false;
  };
in
vimUtils.buildVimPlugin {
  pname = "sg.nvim";
  inherit version src;

  dependencies = [ vimPlugins.plenary-nvim ];

  postInstall = ''
    mkdir -p $out/target/debug
    ln -s ${sg-nvim-rust}/{bin,lib}/* $out/target/debug
  '';

  passthru = {
    updateScript = nix-update-script {
      attrPath = "vimPlugins.sg-nvim.sg-nvim-rust";
    };

    # needed for the update script
    inherit sg-nvim-rust;
  };
  nvimRequireCheck = "sg";

  meta = {
    description = "Neovim plugin designed to emulate the behaviour of the Cursor AI IDE";
    homepage = "https://github.com/sourcegraph/sg.nvim/";
    license = lib.licenses.asl20;
  };
}
