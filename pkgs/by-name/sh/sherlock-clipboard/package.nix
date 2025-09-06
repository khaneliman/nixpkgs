{
  lib,
  fetchFromGitHub,
  rustPlatform,
  nix-update-script,
}:

rustPlatform.buildRustPackage {
  pname = "sherlock-clipboard";
  version = "0.1.0-unstable-2025-08-09";

  src = fetchFromGitHub {
    owner = "Skxxtz";
    repo = "sherlock-clipboard";
    rev = "234f9bbfe84ed20ff938bbdafc0c5481a68968e5";
    hash = "sha256-wrjlA/XUxgrn6gICB0ualZg3oX5YEd8HGchBq9/mnz0=";
  };

  cargoHash = "sha256-D2/L7vQkjEgawde9cZH45s0FSLluihqYSSwW5eLNMxM=";

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--version=branch" ];
  };

  meta = {
    description = "Custom plugin for Sherlock adding clipboard history support";
    homepage = "https://github.com/Skxxtz/sherlock-clipboard";
    license = lib.licenses.gpl3Plus;
    mainProgram = "sherlock-clp";
    maintainers = with lib.maintainers; [ khaneliman ];
  };
}
