{
  lua,
  hello,
  wrapLua,
  lib,
  pkgs,
}:
let
  runTest =
    lua:
    { name, command }:
    pkgs.runCommandLocal "test-${lua.name}-${name}"
      {
        nativeBuildInputs = [ lua ];
        meta.platforms = lua.meta.platforms;
      }
      (
        ''
          source ${./assert.sh}
        ''
        + command
        + "touch $out"
      );

  wrappedHello = hello.overrideAttrs {
    propagatedBuildInputs = [
      wrapLua
      lua.pkgs.cjson
    ];
    postFixup = ''
      wrapLuaPrograms
    '';
  };

  luaWithModule = lua.withPackages (ps: [
    ps.lua-cjson
  ]);

  golden_LUA_PATHS = {

    # Looking at lua interpreter 'setpath' code
    # for instance https://github.com/lua/lua/blob/69ea087dff1daba25a2000dfb8f1883c17545b7a/loadlib.c#L599
    # replace ";;" by ";LUA_PATH_DEFAULT;"
    "5.1" =
      ";./?.lua;${lua}/share/lua/5.1/?.lua;${lua}/share/lua/5.1/?/init.lua;${lua}/lib/lua/5.1/?.lua;${lua}/lib/lua/5.1/?/init.lua;";
    "5.2" =
      ";${lua}/share/lua/5.2/?.lua;${lua}/share/lua/5.2/?/init.lua;${lua}/lib/lua/5.2/?.lua;${lua}/lib/lua/5.2/?/init.lua;./?.lua;";
    "5.3" =
      ";${lua}/share/lua/5.3/?.lua;${lua}/share/lua/5.3/?/init.lua;${lua}/lib/lua/5.3/?.lua;${lua}/lib/lua/5.3/?/init.lua;./?.lua;./?/init.lua;";
    # lua > 5.4 seems to be smarter about it and dont add the lua separators when nothing left or right
    "5.4" =
      "${lua}/share/lua/5.4/?.lua;${lua}/share/lua/5.4/?/init.lua;${lua}/lib/lua/5.4/?.lua;${lua}/lib/lua/5.4/?/init.lua;./?.lua;./?/init.lua";
    "5.5" =
      "${lua}/share/lua/5.5/?.lua;${lua}/share/lua/5.5/?/init.lua;${lua}/lib/lua/5.5/?.lua;${lua}/lib/lua/5.5/?/init.lua;./?.lua;./?/init.lua";

    # luajit versions
    "2.0" =
      ";./?.lua;${lua}/share/luajit-2.0/?.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/?/init.lua;${lua}/share/lua/5.1/?.lua;${lua}/share/lua/5.1/?/init.lua;";
    "2.1" =
      ";./?.lua;${lua}/share/luajit-2.1/?.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/?/init.lua;${lua}/share/lua/5.1/?.lua;${lua}/share/lua/5.1/?/init.lua;";
  };
in
lib.recurseIntoAttrs {

  checkInterpreterPath =
    let
      golden_LUA_PATH = golden_LUA_PATHS.${lib.versions.majorMinor lua.version};
    in
    runTest lua {
      name = "check-default-lua-path";
      command = ''
        export LUA_PATH=";;"
        generated=$(lua -e 'print(package.path)')
        assertStringEqual "$generated" "${golden_LUA_PATH}"
      '';
    };

  checkWrapping = pkgs.runCommandLocal "test-${lua.name}-wrapping" { } ''
    grep -- 'LUA_PATH=' ${wrappedHello}/bin/hello
    touch $out
  '';

  # checks that lua's setup-hook adds dependencies to LUA_PATH
  # Prevents the following regressions
  # $ env NIX_PATH=nixpkgs=. nix-shell --pure -Q -p luajitPackages.lua luajitPackages.alt-getopt
  # nix-shell$ luajit
  # > require('alt-getopt')
  # stdin:1: module 'alt-getopt' not found:
  checkSetupHook =
    pkgs.runCommandLocal "test-${lua.name}-setup-hook"
      {
        nativeBuildInputs = [ lua ];
        buildInputs = [ lua.pkgs.alt-getopt ];
        meta.platforms = lua.meta.platforms;
      }
      ''
        ${lua}/bin/lua -e "require'alt_getopt'"
        touch $out
      '';

  checkRelativeImports = pkgs.runCommandLocal "test-${lua.name}-relative-imports" { } ''
    source ${./assert.sh}

    lua_vanilla_package_path="$(${lua}/bin/lua -e "print(package.path)")"
    lua_with_module_package_path="$(${luaWithModule}/bin/lua -e "print(package.path)")"

    assertStringContains "$lua_vanilla_package_path" "./?.lua"
    assertStringContains "$lua_vanilla_package_path" "./?/init.lua"

    assertStringContains "$lua_with_module_package_path" "./?.lua"
    assertStringContains "$lua_with_module_package_path" "./?/init.lua"

    touch $out
  '';

  # Check that a lua package's propagatedBuildInputs end up in LUA_PATH
  checkPropagatedBuildInputs =
    pkgs.runCommandLocal "test-${lua.name}-setup-hook"
      {
        buildInputs = [ lua.pkgs.luacov ];
      }
      # `datafile` is a propagatedBuildInput of luacov
      ''
        ${lua}/bin/lua -e "require'datafile'"
        touch $out
      '';

  # The rockspec pins versions nixpkgs does not have, so luarocks rejects it
  # unless luarocksRelaxDeps drops the constraints.
  checkRelaxDeps =
    let
      build =
        {
          luarocksRelaxDeps,
          luaDep ? "lua >= 5.1",
          known ? false,
          lockfile ? false,
          topLevelReturn ? false,
        }:
        let
          src = pkgs.runCommandLocal "relax-deps-test-src" { } (
            ''
              mkdir -p "$out"
              cat > "$out/relax-deps-test-0.1-1.rockspec" <<'EOF'
              rockspec_format = "3.0"
              package = "relax-deps-test"
              version = "0.1-1"
              source = { url = "." }
              description = { summary = "alt-getopt ~> 0.1" }
              dependencies = {
                "${luaDep}",
                "alt-getopt ~> 0.1",
                [[datafile == 0.0]],
                -- luarocks merges platform lists by index; nil keeps the base entry
                platforms = { unix = { nil, "alt-getopt ~> 0.1" } },
              }
              build_dependencies = { "alt-getopt ~> 0.1" }
              build = { type = "none" }
              EOF
            ''
            + lib.optionalString lockfile ''
              echo 'return { dependencies = { ["alt-getopt"] = "0.1-1" } }' > "$out/luarocks.lock"
            ''
            # like fennel's rockspec; statements appended after it cannot run
            + lib.optionalString topLevelReturn ''
              echo 'return nil' >> "$out/relax-deps-test-0.1-1.rockspec"
            ''
          );
        in
        lua.pkgs.buildLuarocksPackage {
          pname = "relax-deps-test";
          version = "0.1-1";
          inherit src luarocksRelaxDeps;
          # the builder copies a knownRockspec from the store, so the copy is read-only
          knownRockspec = if known then "${src}/relax-deps-test-0.1-1.rockspec" else null;
          propagatedBuildInputs = [
            lua.pkgs.alt-getopt
            lua.pkgs.datafile
          ];
          # strings outside dependency tables stay as written, and the hook is not
          # listed as an external dependency
          postInstall = ''
            grep -F 'summary = "alt-getopt ~> 0.1"' "$(find "$out" -name relax-deps-test-0.1-1.rockspec)"
            if grep -F luarocks-relax-deps-hook "$LUAROCKS_CONFIG"; then exit 1; fi
          '';
        };

      failsWith =
        message: drv:
        pkgs.runCommandLocal "${drv.name}-fails" { failed = pkgs.testers.testBuildFailure drv; } ''
          grep -F ${lib.escapeShellArg message} "$failed/testBuildFailure.log"
          touch $out
        '';
    in
    lib.recurseIntoAttrs {
      names = build {
        luarocksRelaxDeps = [
          "alt-getopt"
          "datafile"
        ];
        known = true;
      };
      all = build { luarocksRelaxDeps = true; };
      partial = failsWith "Could not satisfy dependency datafile" (build {
        luarocksRelaxDeps = [ "alt-getopt" ];
      });
      keepsLua = failsWith "lua >= 9.0" (build {
        luarocksRelaxDeps = true;
        luaDep = "lua >= 9.0";
      });
      relaxesLua = build {
        luarocksRelaxDeps = [
          "lua"
          "alt-getopt"
          "datafile"
        ];
        luaDep = "lua >= 9.0";
      };
      unknownName = failsWith ''"nosuch" is not a dependency'' (build {
        luarocksRelaxDeps = [ "nosuch" ];
      });
      lockfile = failsWith "luarocksRelaxDepsHook: luarocks.lock" (build {
        luarocksRelaxDeps = true;
        lockfile = true;
      });
      topLevelReturn = failsWith "patch it instead" (build {
        luarocksRelaxDeps = true;
        topLevelReturn = true;
      });
      unrelaxed = failsWith "alt-getopt ~> 0.1" (build {
        luarocksRelaxDeps = [ ];
      });
    };
}
