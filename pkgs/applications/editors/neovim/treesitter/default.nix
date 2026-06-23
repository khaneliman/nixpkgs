{
  lib,
  callPackage,
  runCommandLocal,
  vimUtils,
  tree-sitter,
  grammarToPlugin,
  nvim-treesitter,
}:

let
  buildQueries =
    {
      language,
      requires ? [ ],
    }:
    vimUtils.toVimPlugin (
      # Just mkdir + ln -s; cheaper to build than to substitute (and not
      # on cache.nixos.org anyway since release.nix doesn't recurse into
      # passthru.queries). With ~300 languages under withAllGrammars,
      # round-tripping each to a remote builder is very slow.
      runCommandLocal "nvim-treesitter-queries-${language}"
        {
          passthru = {
            inherit language requires;
            isTreesitterQuery = true;
          };
          meta.description = "Queries for ${language} from nvim-treesitter";
        }
        ''
          mkdir -p "$out/queries"
          if [ -d "${nvim-treesitter}/runtime/queries/${language}" ]; then
            ln -s "${nvim-treesitter}/runtime/queries/${language}" "$out/queries/${language}"
          else
            echo "Error: there are no queries for ${language}."
            exit 1
          fi
        ''
    );

  generated = callPackage ./generated.nix {
    inherit (tree-sitter) buildGrammar;
    inherit buildQueries;
  };

  inherit (generated) parsers queries;

  queriesWithDeps = lib.mapAttrs (
    lang: query:
    let
      requires = query.requires or [ ];
      dependencies = map (req: queries.${req}) requires;
    in
    if dependencies != [ ] then
      query.overrideAttrs (old: {
        passthru = old.passthru or { } // {
          inherit dependencies;
        };
      })
    else
      query
  ) queries;

  parsersWithQueries = lib.mapAttrs (
    lang: parser:
    if lib.hasAttr lang queriesWithDeps then
      parser.overrideAttrs (old: {
        passthru = old.passthru or { } // {
          associatedQuery = queriesWithDeps.${lang};
        };
      })
    else
      parser
  ) parsers;

  parsersWithMeta = lib.mapAttrs (
    lang: parser:
    let
      requires = parser.requires or [ ];
      dependencies = map (req: grammarToPlugin parsersWithQueries.${req}) requires;
    in
    if dependencies != [ ] then
      parser.overrideAttrs (old: {
        passthru = old.passthru or { } // {
          inherit dependencies;
        };
      })
    else
      parser
  ) parsersWithQueries;

  # add aliases so grammars from `tree-sitter` are overwritten in `withPlugins`
  # for example, for ocaml_interface, the following aliases will be added
  #   ocaml-interface
  #   tree-sitter-ocaml-interface
  #   tree-sitter-ocaml_interface
  builtGrammars =
    parsersWithMeta
    // lib.concatMapAttrs (
      k: v:
      let
        replaced = lib.replaceStrings [ "_" ] [ "-" ] k;
      in
      {
        "tree-sitter-${k}" = v;
      }
      // lib.optionalAttrs (k != replaced) {
        ${replaced} = v;
        "tree-sitter-${replaced}" = v;
      }
    ) parsersWithMeta;

  allGrammars = lib.attrValues parsersWithMeta;

  # Usage:
  # pkgs.neovimUtils.treesitter.withPlugins (p: [ p.c p.java ... ])
  # or for all grammars:
  # pkgs.neovimUtils.treesitter.withAllGrammars
  withPlugins =
    f:
    let
      selectedGrammars = f (tree-sitter.builtGrammars // builtGrammars);

      grammarPlugins = map grammarToPlugin selectedGrammars;

      queryPlugins = lib.pipe selectedGrammars [
        (map (g: g.associatedQuery or null))
        (lib.filter (q: q != null))
      ];
    in
    nvim-treesitter.overrideAttrs {
      passthru.dependencies = grammarPlugins ++ queryPlugins;
    };

  withAllGrammars = withPlugins (_: allGrammars);
  grammarPlugins = lib.mapAttrs (_: grammarToPlugin) parsersWithMeta;
in
{
  inherit
    buildQueries
    builtGrammars
    allGrammars
    grammarPlugins
    withPlugins
    withAllGrammars
    ;

  queries = queriesWithDeps;
  parsers = grammarPlugins;
}
