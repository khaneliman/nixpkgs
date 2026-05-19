{
  stdenv,
  lib,
  fetchFromGitHub,
}:

stdenv.mkDerivation rec {
  pname = "zsh-system-clipboard";
  version = "0.8.0";

  src = fetchFromGitHub {
    owner = "kutsan";
    repo = "zsh-system-clipboard";
    rev = "v${version}";
    hash = "sha256-VWTEJGudlQlNwLOUfpo0fvh0MyA2DqV+aieNPx/WzSI=";
  };

  strictDeps = true;
  installPhase = ''
    plugindir=$out/share/zsh/plugins/${pname}

    install -D zsh-system-clipboard.zsh $plugindir/zsh-system-clipboard.zsh
    ln -s zsh-system-clipboard.zsh $plugindir/zsh-system-clipboard.plugin.zsh

    # Keep the previous nixpkgs path for users sourcing it directly.
    ln -s $plugindir $out/share/zsh/${pname}
  '';

  meta = {
    homepage = "https://github.com/kutsan/zsh-system-clipboard";
    description = "Plugin that adds key bindings support for ZLE (Zsh Line Editor) clipboard operations for vi emulation keymaps";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [
      _0qq
      satoqz
    ];
    platforms = lib.platforms.all;
  };
}
