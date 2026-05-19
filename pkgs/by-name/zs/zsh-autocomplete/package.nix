{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation rec {
  pname = "zsh-autocomplete";
  version = "25.03.19";

  src = fetchFromGitHub {
    owner = "marlonrichert";
    repo = "zsh-autocomplete";
    rev = version;
    sha256 = "sha256-eb5a5WMQi8arZRZDt4aX1IV+ik6Iee3OxNMCiMnjIx4=";
  };

  strictDeps = true;
  installPhase = ''
    plugindir=$out/share/zsh/plugins/zsh-autocomplete

    install -D zsh-autocomplete.plugin.zsh $plugindir/zsh-autocomplete.plugin.zsh
    cp -R Completions $plugindir/Completions
    cp -R Functions $plugindir/Functions

    # Keep the previous nixpkgs path for users sourcing it directly.
    ln -s $plugindir $out/share/zsh-autocomplete
  '';

  meta = {
    description = "Real-time type-ahead completion for Zsh. Asynchronous find-as-you-type autocompletion";
    homepage = "https://github.com/marlonrichert/zsh-autocomplete/";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    maintainers = [ lib.maintainers.leona ];
  };
}
