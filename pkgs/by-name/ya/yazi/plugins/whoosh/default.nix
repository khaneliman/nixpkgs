{
  lib,
  fetchFromGitHub,
  mkYaziPlugin,
}:
mkYaziPlugin {
  pname = "whoosh.yazi";
  version = "25.5.28-unstable-2025-09-14";

  src = fetchFromGitHub {
    owner = "WhoSowSee";
    repo = "whoosh.yazi";
    rev = "b71caff7d4036d8fa6ca5e2bb47743e3d85b0e5f";
    hash = "sha256-kBifoGlaPZ1lkM4m6vo+IMp476agGUXvJIdvbSKOXds=";
  };

  meta = {
    description = "Bookmark manager for Yazi with persistent/temporary bookmarks, directory history, and fuzzy search integration";
    homepage = "https://github.com/WhoSowSee/whoosh.yazi";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ khaneliman ];
  };
}
