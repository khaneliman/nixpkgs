{
  lib,
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "zsh-navigation-tools";
  version = "2.2.7";

  src = fetchFromGitHub {
    owner = "psprint";
    repo = "zsh-navigation-tools";
    rev = "v${finalAttrs.version}";
    sha256 = "0c4kb19aprb868xnlyq8h1nd2d32r0zkrqblsrzvg7m9gx8vqps8";
  };

  dontBuild = true;

  installPhase = ''
    plugindir=$out/share/zsh/plugins/zsh-navigation-tools

    mkdir -p $plugindir
    cp zsh-navigation-tools.plugin.zsh $plugindir/
    cp n-* $plugindir/
    cp znt-* $plugindir/
    mkdir -p $plugindir/.config/znt
    cp .config/znt/n-* $plugindir/.config/znt
    mkdir -p $out/share/zsh/site-functions
    ln -s $plugindir/n-* $plugindir/znt-* $out/share/zsh/site-functions/
    ln -s $plugindir/.config $out/share/zsh/site-functions/.config
    ln -s $plugindir/zsh-navigation-tools.plugin.zsh $out/share/zsh/site-functions/
  '';

  meta = {
    description = "Curses-based tools for ZSH";
    homepage = "https://github.com/psprint/zsh-navigation-tools";
    license = lib.licenses.gpl3;
    maintainers = with lib.maintainers; [ pSub ];
    platforms = with lib.platforms; unix;
  };
})
