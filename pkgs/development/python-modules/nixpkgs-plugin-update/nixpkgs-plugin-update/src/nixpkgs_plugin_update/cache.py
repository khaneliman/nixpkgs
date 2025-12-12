import json
import os
from pathlib import Path

from .plugin import Plugin


def get_cache_path(cache_file_name: str) -> Path | None:
    """Get the full path to a cache file in XDG_CACHE_HOME.

    Args:
        cache_file_name: Name of the cache file

    Returns:
        Path to cache file in XDG_CACHE_HOME or ~/.cache, or None if HOME is not set
    """
    xdg_cache = os.environ.get("XDG_CACHE_HOME", None)
    if xdg_cache is None:
        home = os.environ.get("HOME", None)
        if home is None:
            return None
        xdg_cache = str(Path(home, ".cache"))

    return Path(xdg_cache, cache_file_name)


class Cache:
    """Cache for plugin metadata to avoid redundant fetches.

    Stores plugin information indexed by commit hash. Persists to disk
    in XDG_CACHE_HOME as JSON for reuse across runs.
    """

    def __init__(self, initial_plugins: list[Plugin], cache_file_name: str) -> None:
        """Initialize cache with current plugins and load from disk.

        Args:
            initial_plugins: Current plugins to seed the cache
            cache_file_name: Name of cache file in XDG_CACHE_HOME
        """
        self.cache_file = get_cache_path(cache_file_name)

        downloads = {}
        for plugin in initial_plugins:
            downloads[plugin.commit] = plugin
        downloads.update(self.load())
        self.downloads = downloads

    def load(self) -> dict[str, Plugin]:
        """Load cached plugins from disk.

        Handles backward compatibility with old cache formats that may be
        missing version or last_tag fields.

        Returns:
            Dictionary mapping commit hash to Plugin objects
        """
        if self.cache_file is None or not self.cache_file.exists():
            return {}

        downloads: dict[str, Plugin] = {}
        with open(self.cache_file, encoding="utf-8") as f:
            data = json.load(f)
            for attr in data.values():
                if "version" in attr:
                    version = attr["version"]
                else:
                    version = "0-unstable-1970-01-01"
                    if "last_tag" in attr and attr["last_tag"]:
                        version = f"{attr['last_tag']}-unstable-1970-01-01"

                p = Plugin(
                    attr["name"],
                    attr["commit"],
                    attr["has_submodules"],
                    attr["sha256"],
                    version,
                    last_tag=attr.get("last_tag"),
                )
                downloads[attr["commit"]] = p
        return downloads

    def store(self) -> None:
        """Persist cache to disk as JSON.

        Creates parent directories if needed. Does nothing if cache_file is None.
        """
        if self.cache_file is None:
            return

        os.makedirs(self.cache_file.parent, exist_ok=True)
        with open(self.cache_file, "w+", encoding="utf-8") as f:
            data = {}
            for name, attr in self.downloads.items():
                data[name] = attr.as_json()
            json.dump(data, f, indent=4, sort_keys=True)

    def __getitem__(self, key: str) -> Plugin | None:
        """Get plugin by commit hash.

        Args:
            key: Git commit hash

        Returns:
            Cached Plugin or None if not found
        """
        return self.downloads.get(key, None)

    def __setitem__(self, key: str, value: Plugin) -> None:
        """Store plugin in cache by commit hash.

        Args:
            key: Git commit hash
            value: Plugin to cache
        """
        self.downloads[key] = value
