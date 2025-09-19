{
  lib,
  fetchFromGitHub,
  mkYaziPlugin,
}:
mkYaziPlugin {
  pname = "sshfs.yazi";
  version = "0-unstable-2025-09-15";

  src = fetchFromGitHub {
    owner = "uhs-robert";
    repo = "sshfs.yazi";
    rev = "1a466c8b1b90a8a87cb23f094cbbd19ee983c49f";
    hash = "sha256-v75BKZ3OSK+3afA8P1Vim8iWxhc84RBdyFyQL1XD864=";
  };

  meta = {
    description = "Mount and unmount remote systems so you can browse, preview, and edit single files or entire directories as if they were local";
    homepage = "https://github.com/uhs-robert/sshfs.yazi";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ khaneliman ];
  };
}
