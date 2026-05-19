{
  lib,
  stdenv,
  fetchFromGitHub,
}:

# To make use of this derivation, use the `programs.zsh.enableSyntaxHighlighting` option

stdenv.mkDerivation (finalAttrs: {
  version = "0.8.0";
  pname = "zsh-syntax-highlighting";

  src = fetchFromGitHub {
    owner = "zsh-users";
    repo = "zsh-syntax-highlighting";
    rev = finalAttrs.version;
    hash = "sha256-iJdWopZwHpSyYl5/FQXEW7gl/SrKaYDEtTH9cGP7iPo=";
  };

  strictDeps = true;

  installFlags = [ "PREFIX=$(out)" ];

  postInstall = ''
    plugindir=$out/share/zsh/plugins/zsh-syntax-highlighting

    mkdir -p $out/share/zsh/plugins
    mv $out/share/zsh-syntax-highlighting $plugindir

    # Keep the previous nixpkgs path used by NixOS/Home Manager modules.
    ln -s $plugindir $out/share/zsh-syntax-highlighting
  '';

  meta = {
    description = "Fish shell like syntax highlighting for Zsh";
    homepage = "https://github.com/zsh-users/zsh-syntax-highlighting";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.unix;
    maintainers = with lib.maintainers; [
      gepbird
      loskutov
    ];
  };
})
