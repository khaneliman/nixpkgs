{
  lib,
  stdenv,
  fetchFromGitHub,
  nix-update-script,
  nodejs,
  pnpm,
  wrapGAppsHook3,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "tabby-agent";
  version = "0.18.0";

  src = fetchFromGitHub {
    owner = "TabbyML";
    repo = "tabby";
    rev = "refs/tags/v${finalAttrs.version}";
    hash = "sha256-8clEBWAT+HI2eecOsmldgRcA58Ehq9bZT4ZwUMm494g=";
  };

  nativeBuildInputs = [
    nodejs
    pnpm.configHook
    wrapGAppsHook3
  ];

  buildPhase = ''
    runHook preBuild

    # turbo build
    pnpm --filter=tabby-agent build
    # pnpm build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    cp -r ./clients/tabby-agent/dist $out
    runHook postInstall
  '';

  # buildInputs = [ ];

  pnpmDeps = pnpm.fetchDeps {
    inherit (finalAttrs) pname version src;
    hash = "sha256-WBhkrgLTTR5f8ZVmUfzMbFw/6jIGoLcUspHCsNpOxx4=";
  };

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--version-regex"
      "^v([0-9.]+)$"
    ];
  };

  meta = with lib; {
    homepage = "https://github.com/TabbyML/tabby";
    changelog = "https://github.com/TabbyML/tabby/releases/tag/v${finalAttrs.version}";
    description = "Self-hosted AI coding assistant";
    mainProgram = "tabby-agent";
    license = licenses.asl20;
    maintainers = [ maintainers.khaneliman ];
  };
})
