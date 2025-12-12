import json
import os
from pathlib import Path

from .plugin import Plugin


def get_cache_path(cache_file_name: str) -> Path | None:
    xdg_cache = os.environ.get("XDG_CACHE_HOME", None)
    if xdg_cache is None:
        home = os.environ.get("HOME", None)
        if home is None:
            return None
        xdg_cache = str(Path(home, ".cache"))

    return Path(xdg_cache, cache_file_name)


class Cache:
    def __init__(self, initial_plugins: list[Plugin], cache_file_name: str) -> None:
        self.cache_file = get_cache_path(cache_file_name)

        downloads = {}
        for plugin in initial_plugins:
            downloads[plugin.commit] = plugin
        downloads.update(self.load())
        self.downloads = downloads

    def load(self) -> dict[str, Plugin]:
        if self.cache_file is None or not self.cache_file.exists():
            return {}

        downloads: dict[str, Plugin] = {}
        with open(self.cache_file, encoding="utf-8") as f:
            data = json.load(f)
            for attr in data.values():
                p = Plugin(
                    attr["name"],
                    attr["commit"],
                    attr["has_submodules"],
                    attr["sha256"],
                    last_tag=attr.get("last_tag"),  # Gracefully handle missing field
                )
                downloads[attr["commit"]] = p
        return downloads

    def store(self) -> None:
        if self.cache_file is None:
            return

        os.makedirs(self.cache_file.parent, exist_ok=True)
        with open(self.cache_file, "w+", encoding="utf-8") as f:
            data = {}
            for name, attr in self.downloads.items():
                data[name] = attr.as_json()
            json.dump(data, f, indent=4, sort_keys=True)

    def __getitem__(self, key: str) -> Plugin | None:
        return self.downloads.get(key, None)

    def __setitem__(self, key: str, value: Plugin) -> None:
        self.downloads[key] = value
