{
  stdenv,
  lib,
  fetchFromGitHub,
  installShellFiles,
}:
stdenv.mkDerivation rec {
  pname = "zsh-abbr";
  version = "6.5.2";

  src = fetchFromGitHub {
    owner = "olets";
    repo = "zsh-abbr";
    tag = "v${version}";
    hash = "sha256-T5dnlPXsGdFjdASAAYrV9Kc38Y+q0iM2StgNj4efVj4=";
    fetchSubmodules = true;
  };

  strictDeps = true;
  nativeBuildInputs = [ installShellFiles ];

  installPhase = ''
    runHook preInstall

    plugindir=$out/share/zsh/plugins/zsh-abbr

    install *.zsh -Dt $plugindir/
    install completions/* -Dt $plugindir/completions/

    install zsh-job-queue/*.zsh -Dt $plugindir/zsh-job-queue/
    install zsh-job-queue/completions/* -Dt $plugindir/zsh-job-queue/completions/

    # Keep the previous nixpkgs path for users sourcing it directly.
    ln -s $plugindir $out/share/zsh/zsh-abbr

    # Required for `man` to find the manpage of abbr, since it looks via PATH
    installManPage man/man1/*

    runHook postInstall
  '';

  meta = {
    homepage = "https://github.com/olets/zsh-abbr";
    description = "Zsh manager for auto-expanding abbreviations, inspired by fish shell";
    license = with lib.licenses; [
      cc-by-nc-sa-40
      hl3
    ];
    maintainers = with lib.maintainers; [ icy-thought ];
    platforms = lib.platforms.all;
  };
}
