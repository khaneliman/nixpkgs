from __future__ import annotations

import re
import subprocess
from dataclasses import dataclass
from datetime import datetime
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from . import Repo

VERSION_DATE_PATTERN = re.compile(r"(\d{4}-\d{2}-\d{2})$")
VERSION_TAG_PATTERN = re.compile(r"^(.+?)-unstable-")


@dataclass
class FetchConfig:
    proc: int
    github_token: str


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
    date: datetime | None = None
    last_tag: str | None = None

    @property
    def normalized_name(self) -> str:
        return self.name.replace(".", "-")

    def to_sri_hash(self) -> str:
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

    @property
    def version(self) -> str:
        assert self.date is not None
        date_str = self.date.strftime("%Y-%m-%d")

        tag_part = "0"
        if self.last_tag:
            tag = (
                self.last_tag[1:]
                if self.last_tag.startswith(("v", "V"))
                else self.last_tag
            )
            if tag and tag[0].isdigit():
                tag_part = tag

        return f"{tag_part}-unstable-{date_str}"

    @staticmethod
    def parse_version_string(version_str: str) -> tuple[datetime, str | None]:
        date_match = VERSION_DATE_PATTERN.search(version_str)
        if not date_match:
            raise ValueError(f"Cannot parse date from version: {version_str}")
        date = datetime.fromisoformat(date_match.group(1))

        tag_match = VERSION_TAG_PATTERN.search(version_str)
        last_tag = (
            tag_match.group(1) if tag_match and tag_match.group(1) != "0" else None
        )

        return date, last_tag

    def as_json(self) -> dict[str, str]:
        copy = self.__dict__.copy()
        del copy["date"]
        return copy
