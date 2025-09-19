{
  lib,
  fetchFromGitHub,
  mkYaziPlugin,
}:
mkYaziPlugin {
  pname = "bunny.yazi";
  version = "25.5.28-unstable-2025-09-18";

  src = fetchFromGitHub {
    owner = "stelcodes";
    repo = "bunny.yazi";
    rev = "7137a44324235c0f04d4b73e5fdd6845c99db278";
    hash = "sha256-xdRP8Y2ZadNFge7mVhfu2d8DoitknQmkxFV+NIsjsG4=";
  };

  meta = {
    description = "Bookmarks menu for yazi with persistent and ephemeral bookmarks, fuzzy searching, previous directory, directory from another tab";
    homepage = "https://github.com/stelcodes/bunny.yazi";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ khaneliman ];
  };
}
