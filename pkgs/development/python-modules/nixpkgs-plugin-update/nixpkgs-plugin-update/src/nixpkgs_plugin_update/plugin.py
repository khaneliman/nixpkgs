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
    """Descriptor for a plugin to be fetched.

    Immutable specification of where to fetch a plugin from and what to call it.

    Attributes:
        repo: Repository object (Repo or RepoGitHub)
        branch: Git branch to fetch from
        alias: Optional alternative name for the plugin
    """

    repo: "Repo"
    branch: str
    alias: str | None

    @property
    def name(self):
        """Get the plugin name, preferring alias over repo name."""
        return self.alias or self.repo.name

    @staticmethod
    def load_from_csv(config: FetchConfig, row: dict[str, str]) -> "PluginDesc":
        """Create PluginDesc from a CSV row.

        Args:
            config: Fetch configuration with GitHub token
            row: Dictionary with 'repo', 'branch', and 'alias' keys

        Returns:
            PluginDesc instance
        """
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
        """Create PluginDesc from a string specification.

        Supports formats:
        - owner/repo
        - owner/repo@branch
        - owner/repo as alias
        - owner/repo@branch as alias

        Args:
            config: Fetch configuration with GitHub token
            line: String specification of plugin

        Returns:
            PluginDesc instance
        """
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
    """Fetched plugin with all metadata needed for Nix derivation.

    Attributes:
        name: Plugin name (may contain dots)
        commit: Git commit hash
        has_submodules: Whether repo has git submodules
        sha256: Hash of the fetched source (any format)
        version: Version string in format "tag-unstable-YYYY-MM-DD"
        date: Commit date (used for version string)
        last_tag: Latest git tag (used for version string)
    """

    name: str
    commit: str
    has_submodules: bool
    sha256: str
    version: str
    date: datetime | None = None
    last_tag: str | None = None

    @property
    def normalized_name(self) -> str:
        """Get name normalized for Nix (dots replaced with hyphens)."""
        return self.name.replace(".", "-")

    @staticmethod
    def _strip_tag_prefix(tag: str) -> str:
        """Strip common version prefixes like 'v', 'V', 'release-' from tags.

        Args:
            tag: Git tag name

        Returns:
            Tag with prefix removed
        """
        if tag.startswith(("v", "V")):
            return tag[1:]
        if tag.startswith("release-"):
            return tag[8:]
        return tag

    @staticmethod
    def compute_version(date: datetime, last_tag: str | None) -> str:
        """Compute version string from date and tag.

        Generates version in format "tag-unstable-YYYY-MM-DD" or
        "0-unstable-YYYY-MM-DD" if no tag exists.

        Args:
            date: Commit date
            last_tag: Latest git tag or None

        Returns:
            Version string
        """
        date_str = date.strftime("%Y-%m-%d")
        tag_part = Plugin._strip_tag_prefix(last_tag) if last_tag is not None else "0"
        return f"{tag_part}-unstable-{date_str}"

    def to_sri_hash(self) -> str:
        """Convert sha256 (any format) to SRI format (sha256-base64).

        Uses nix hash convert to handle any input format (base32, hex).

        Returns:
            Hash in SRI format (sha256-base64)
        """
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
        """Serialize plugin to JSON-compatible dict for caching.

        Excludes date field which cannot be JSON serialized directly.

        Returns:
            Dictionary suitable for JSON serialization
        """
        copy = self.__dict__.copy()
        del copy["date"]
        return copy


def load_plugins_from_csv(
    config: FetchConfig,
    input_file: Path,
) -> list[PluginDesc]:
    """Load plugin descriptors from CSV file.

    Args:
        config: Fetch configuration with GitHub token
        input_file: Path to CSV file with repo, branch, alias columns

    Returns:
        List of PluginDesc objects
    """
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
