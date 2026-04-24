{
  lib,
  fetchFromGitHub,
  rustPlatform,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "rustowl";
  version = "1.0.0-rc.1";

  src = fetchFromGitHub {
    owner = "cordx56";
    repo = "rustowl";
    tag = "v${finalAttrs.version}";
    hash = "sha256-CXuwbg39sboKxuJTNpq3KVqjTTOQp1Af4XWZLjorHdM=";
  };

  cargoHash = "sha256-yH+R/lHCFS8qFUSSrgnzvahhbymutb30Gq1jvHG1Aq4=";

  env = {
    RUSTC_BOOTSTRAP = 1;
  };

  meta = {
    description = "Visualize ownership and lifetimes in Rust";
    homepage = "https://github.com/cordx56/rustowl";
    changelog = "https://github.com/cordx56/rustowl/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mpl20;
    maintainers = with lib.maintainers; [ khaneliman ];
    mainProgram = "rustowl";
  };
})
