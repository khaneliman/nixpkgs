# Hooks for building lua packages.
{
  lib,
  lua,
  makeSetupHook,
}:

let
  callPackage = lua.pkgs.callPackage;
in
{
  /**
    Accepts "bustedFlags" as an array.
    You can customize the call by setting "bustedFlags" and prevent the test from running by setting "dontBustedCheck"
  */
  bustedCheckHook = callPackage (
    { busted }:
    makeSetupHook {
      name = "busted-check-hook";
      propagatedBuildInputs = [
        busted
      ];
      meta.license = lib.licenses.mit;
    } ./busted-check-hook.sh
  ) { };

  luarocksCheckHook = callPackage (
    { luarocks }:
    makeSetupHook {
      name = "luarocks-check-hook";
      propagatedBuildInputs = [ luarocks ];
      meta.license = lib.licenses.mit;
    } ./luarocks-check-hook.sh
  ) { };

  /**
    Drops version constraints from rockspec dependencies.
    Set "luarocksRelaxDeps" to a list of dependency names, or to true to relax every dependency except lua.
    buildLuarocksPackage adds this hook when "luarocksRelaxDeps" is set.
  */
  luarocksRelaxDepsHook = makeSetupHook {
    name = "luarocks-relax-deps-hook";
    substitutions = {
      inherit (lua.luaOnBuild) interpreter;
      # reuse luarocks' own rockspec loader
      luarocksPath = "${lua.luaOnBuild.pkgs.luarocks_bootstrap}/share/lua/${lua.luaOnBuild.luaversion}/?.lua";
      script = ./luarocks-relax-deps.lua;
    };
    meta.license = lib.licenses.mit;
  } ./luarocks-relax-deps-hook.sh;

  # luarocks installs data in a non-overridable location. Until a proper luarocks patch,
  # we move the files around ourselves
  luarocksMoveDataFolder = makeSetupHook {
    name = "luarocks-move-rock";
    meta.license = lib.licenses.mit;
  } ./luarocks-move-data.sh;
}
