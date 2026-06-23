{
  lib,
  neovim,
  neovim-unwrapped,
  neovimUtils,
  runCommand,
  wrapNeovim,
  writableTmpDirAsHomeHook,
}:

self: super:

let
  inherit (neovimUtils) treesitter;
in
{
  passthru = super.nvim-treesitter.passthru or { } // {
    inherit (treesitter)
      buildQueries
      builtGrammars
      allGrammars
      grammarPlugins
      withPlugins
      withAllGrammars
      wasmParsers
      wasmGrammarPlugins
      withWasmGrammars
      withAllWasmGrammars
      queries
      parsers
      ;

    inherit (neovimUtils) grammarToPlugin;

    tests = {
      check-queries =
        let
          nvimWithAllGrammars = neovim.override {
            configure.packages.all.start = [ treesitter.withAllGrammars ];
          };
        in
        runCommand "nvim-treesitter-check-queries"
          {
            nativeBuildInputs = [
              nvimWithAllGrammars
              writableTmpDirAsHomeHook
            ];
            CI = true;
          }
          ''
            touch $out
            ln -s ${treesitter.withAllGrammars}/CONTRIBUTING.md .
            export ALLOWED_INSTALLATION_FAILURES=ipkg,norg,verilog

            nvim --headless -l "${treesitter.withAllGrammars}/scripts/check-queries.lua" | tee log

            if grep -q Warning log; then
              echo "WARNING: warnings were emitted by the check"
              echo "Check if they were expected warnings!"
            fi
          '';

      no-queries-for-official-grammars =
        let
          pluginsToCheck = lib.filter lib.isDerivation (lib.attrValues treesitter.parsers);
        in
        runCommand "nvim-treesitter-test-no-queries-for-official-grammars" { CI = true; } ''
          touch "$out"

          function check_grammar {
            local grammar_name="$1"
            local grammar_path="$2"

            echo "checking $1..."
            if [ -d "$grammar_path/queries" ]; then
              echo "Queries directory exists in $grammar_name"
              echo "This is unexpected, see https://github.com/NixOS/nixpkgs/pull/344849#issuecomment-2381447839"
              exit 1
            fi
          }

          ${lib.concatLines (lib.forEach pluginsToCheck (g: "check_grammar \"${g.grammarName}\" \"${g}\""))}
        '';

      wasm-runtime =
        let
          nvimWithWasmGrammar = wrapNeovim (neovim-unwrapped.override { wasmSupport = true; }) {
            configure.packages.all.start = [ treesitter.wasmGrammarPlugins.nix ];
          };
        in
        runCommand "nvim-treesitter-wasm-runtime-test"
          {
            nativeBuildInputs = [
              nvimWithWasmGrammar
              writableTmpDirAsHomeHook
            ];
            CI = true;
          }
          ''
            nvim --headless --clean -u NONE \
              -c 'lua assert(vim.treesitter.language.add("nix"))' \
              -c 'lua local p = vim.treesitter.get_string_parser("{ }", "nix"); assert(p:parse()[1])' \
              -c 'q'
            touch "$out"
          '';
    };
  };

  meta = super.nvim-treesitter.meta or { } // {
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ figsoda ];
  };
}
