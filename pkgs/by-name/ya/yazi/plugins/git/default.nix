{
  lib,
  fetchFromGitHub,
  mkYaziPlugin,
}:
mkYaziPlugin {
  pname = "git.yazi";
  version = "25.5.31-unstable-2025-12-23";

  src = fetchFromGitHub {
    owner = "yazi-rs";
    repo = "plugins";
    rev = "05234ed15876ea80e1f4f05695e8e90c1fd5ab60";
    hash = "sha256-UJ2ICrp9LQBuuR/NpZvKsvFd/C1TRtTjK4ESNA6xh7k=";
  };

  meta = {
    description = "Show the status of Git file changes as linemode in the file list";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ khaneliman ];
  };
}
