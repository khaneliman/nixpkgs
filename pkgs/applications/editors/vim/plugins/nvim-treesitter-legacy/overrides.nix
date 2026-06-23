{
  lib,
  neovimUtils,
}:
self: super:
let
  inherit (neovimUtils) treesitter;

  withPlugins =
    f:
    let
      from-main = treesitter.withPlugins f;
    in
    self.nvim-treesitter-legacy.overrideAttrs {
      passthru = { inherit (from-main) dependencies; };
    };

  withAllGrammars = withPlugins (_: treesitter.allGrammars);
in

{
  postPatch = ''
    rm -r parser
  '';

  passthru = (super.nvim-treesitter-legacy.passthru or { }) // {
    inherit (treesitter)
      builtGrammars
      allGrammars
      grammarPlugins
      parsers
      ;
    inherit (neovimUtils) grammarToPlugin;
    inherit
      withPlugins
      withAllGrammars
      ;
  };

  meta = super.nvim-treesitter-legacy.meta or { } // {
    license = lib.licenses.asl20;
    maintainers = [ ];
  };
}
