{
  fetchFromGitHub,
  fetchNpmDeps,
  imagemagick,
  librsvg,
  lib,
  nix-update-script,
  nodejs,
  npmHooks,
  vimPlugins,
  vimUtils,
}:

vimUtils.buildVimPlugin rec {
  pname = "mdmath.nvim";
  version = "0-unstable-2024-12-27";

  src = fetchFromGitHub {
    owner = "Thiago4532";
    repo = "mdmath.nvim";
    rev = "699acb27fd34bfdf92a43ce0abdd17f0c7a948fe";
    hash = "sha256-ykpzCFshAi6YrJ1n6Ca62dLmZGeeBJ4xgbqe4oqRgPs=";
  };

  npmRoot = "mdmath-js";

  npmDeps = fetchNpmDeps {
    inherit src;
    name = "${pname}-${version}-npm-deps";
    sourceRoot = "${src.name}/${npmRoot}";
    hash = "sha256-yUyLKZQGIibS/9nHWnh0yvtZqza3qEpN9UNqRaNK53Y=";
  };

  nativeBuildInputs = [
    nodejs
    npmHooks.npmConfigHook
  ];

  dependencies = with vimPlugins; [
    nvim-treesitter-parsers.markdown_inline
  ];

  runtimeDeps = [
    imagemagick
    librsvg
    nodejs
  ];

  nvimSkipModules = [
    # Build script, not a plugin module.
    "build"
    # These modules require mdmath.setup() before import.
    "mdmath.Equation"
    "mdmath.Processor"
    "mdmath.marks"
    "mdmath.overlay"
  ];

  passthru.updateScript = nix-update-script { };

  meta = {
    homepage = "https://github.com/Thiago4532/mdmath.nvim/";
    license = lib.licenses.mit;
  };
}
