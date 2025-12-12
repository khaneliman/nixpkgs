# Plugin and PluginDesc classes for nixpkgs plugin updates

import csv
import logging
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .repos import Repo

from .utils import FetchConfig

log = logging.getLogger()


@dataclass(frozen=True)
class PluginDesc:
    repo: "Repo"
    branch: str
    alias: str | None

    @property
    def name(self):
        return self.alias or self.repo.name

    @staticmethod
    def load_from_csv(config: FetchConfig, row: dict[str, str]) -> "PluginDesc":
        from .repos import make_repo

        log.debug("Loading row %s", row)
        branch = row["branch"]
        repo = make_repo(row["repo"], branch.strip())
        repo.token = config.github_token
        return PluginDesc(
            repo,
            branch.strip(),
            row["alias"] if row["alias"] else None,
        )

    @staticmethod
    def load_from_string(config: FetchConfig, line: str) -> "PluginDesc":
        from .repos import make_repo

        branch = "HEAD"
        alias = None
        uri = line
        if " as " in uri:
            uri, alias = uri.split(" as ")
            alias = alias.strip()
        if "@" in uri:
            uri, branch = uri.split("@")
        repo = make_repo(uri.strip(), branch.strip())
        repo.token = config.github_token
        return PluginDesc(repo, branch.strip(), alias)


@dataclass
class Plugin:
    name: str
    commit: str
    has_submodules: bool
    sha256: str
    version: str
    date: datetime | None = None
    last_tag: str | None = None

    @property
    def normalized_name(self) -> str:
        return self.name.replace(".", "-")

    @staticmethod
    def _strip_tag_prefix(tag: str) -> str:
        """Strip common version prefixes like 'v', 'V', 'release-' from tags"""
        if tag.startswith(("v", "V")):
            return tag[1:]
        if tag.startswith("release-"):
            return tag[8:]
        return tag

    @staticmethod
    def compute_version(date: datetime, last_tag: str | None) -> str:
        """Compute version string from date and tag"""
        date_str = date.strftime("%Y-%m-%d")
        tag_part = Plugin._strip_tag_prefix(last_tag) if last_tag is not None else "0"
        return f"{tag_part}-unstable-{date_str}"

    def to_sri_hash(self) -> str:
        """Convert sha256 (any format) to SRI format (sha256-base64)"""
        import subprocess

        if self.sha256.startswith("sha256-"):
            return self.sha256

        cmd = [
            "nix",
            "hash",
            "convert",
            "--hash-algo",
            "sha256",
            "--to",
            "sri",
            self.sha256,
        ]
        result = subprocess.check_output(cmd, stderr=subprocess.DEVNULL)
        return result.decode("utf-8").strip()

    def as_json(self) -> dict[str, str]:
        copy = self.__dict__.copy()
        del copy["date"]
        return copy


def load_plugins_from_csv(
    config: FetchConfig,
    input_file: Path,
) -> list[PluginDesc]:
    log.debug("Load plugins from csv %s", input_file)
    plugins = []
    with open(input_file, newline="", encoding="utf-8") as csvfile:
        log.debug("Writing into %s", input_file)
        reader = csv.DictReader(
            csvfile,
        )
        for line in reader:
            plugin = PluginDesc.load_from_csv(config, line)
            plugins.append(plugin)

    return plugins
