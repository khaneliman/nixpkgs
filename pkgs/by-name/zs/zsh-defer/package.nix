{
  lib,
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation {
  pname = "zsh-defer";
  version = "0-unstable-2022-06-13";

  src = fetchFromGitHub {
    owner = "romkatv";
    repo = "zsh-defer";
    rev = "57a6650ff262f577278275ddf11139673e01e471";
    sha256 = "sha256-/rcIS2AbTyGw2HjsLPkHtt50c2CrtAFDnLuV5wsHcLc=";
  };

  strictDeps = true;
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    plugindir=$out/share/zsh/plugins/zsh-defer

    install -D zsh-defer.plugin.zsh $plugindir/zsh-defer.plugin.zsh
    install -D zsh-defer $plugindir/zsh-defer
    install -D zsh-defer $out/share/zsh/site-functions/zsh-defer
    substituteInPlace $out/share/zsh/site-functions/zsh-defer \
      --replace-fail 'source ''${functions_source[zsh-defer]:A:h}/zsh-defer.plugin.zsh' \
      "source $plugindir/zsh-defer.plugin.zsh"

    # Keep the previous nixpkgs path for users sourcing it directly.
    ln -s $plugindir $out/share/zsh-defer
  '';

  meta = {
    description = "Deferred execution of zsh commands";
    homepage = "https://github.com/romkatv/zsh-defer";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.unix;
    maintainers = [ lib.maintainers.vinnymeller ];
  };
}
