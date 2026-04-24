{
  rustowl,
  vimUtils,
}:

vimUtils.buildVimPlugin {
  inherit (rustowl) src version;
  pname = "rustowl";
  runtimeDeps = [ rustowl ];

  meta = {
    description = "Neovim integration for RustOwl";
    homepage = "https://github.com/cordx56/rustowl";
    inherit (rustowl.meta) changelog license maintainers;
  };
}
