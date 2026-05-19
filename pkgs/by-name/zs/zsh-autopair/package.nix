{
  stdenv,
  lib,
  fetchFromGitHub,
}:

stdenv.mkDerivation rec {
  pname = "zsh-autopair";
  version = "1.0-unstable-2024-07-14";

  src = fetchFromGitHub {
    owner = "hlissner";
    repo = "zsh-autopair";
    rev = "449a7c3d095bc8f3d78cf37b9549f8bb4c383f3d";
    hash = "sha256-3zvOgIi+q7+sTXrT+r/4v98qjeiEL4Wh64rxBYnwJvQ=";
  };

  installPhase = ''
    plugindir=$out/share/zsh/plugins/${pname}

    install -D autopair.zsh $plugindir/autopair.zsh
    install -D autopair.plugin.zsh $plugindir/autopair.plugin.zsh
    install -D zsh-autopair.plugin.zsh $plugindir/zsh-autopair.plugin.zsh

    # Keep the previous nixpkgs path for users sourcing it directly.
    ln -s $plugindir $out/share/zsh/${pname}
  '';

  meta = {
    homepage = "https://github.com/hlissner/zsh-autopair";
    description = "Plugin that auto-closes, deletes and skips over matching delimiters in zsh intelligently";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [
      _0qq
      DataHearth
    ];
    platforms = lib.platforms.all;
  };
}
