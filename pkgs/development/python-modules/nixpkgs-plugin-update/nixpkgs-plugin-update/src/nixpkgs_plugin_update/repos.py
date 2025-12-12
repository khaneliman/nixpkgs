# Repository classes for fetching plugin information

import http.client
import json
import logging
import re
import subprocess
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime
from pathlib import Path
from typing import TYPE_CHECKING
from urllib.parse import urljoin, urlparse

if TYPE_CHECKING:
    from .plugin import Plugin

from .utils import ATOM_ENTRY, ATOM_LINK, ATOM_UPDATED, make_request, retry

log = logging.getLogger()


class Repo:
    """Generic git repository for plugin fetching.

    Handles arbitrary git repositories using nix-prefetch-git and git ls-remote.

    Attributes:
        uri: URL to the repository
        redirect: Set when repository redirects to new location
        token: GitHub API token (unused for generic repos)
    """

    def __init__(self, uri: str, branch: str) -> None:
        """Initialize repository.

        Args:
            uri: Git repository URL
            branch: Branch to fetch from
        """
        self.uri = uri
        self._branch = branch
        self.redirect: "Repo | None" = None
        self.token: str | None = "dummy_token"

    @property
    def name(self):
        """Extract repository name from URI."""
        return self.uri.strip("/").split("/")[-1]

    @property
    def branch(self):
        """Get branch name, defaulting to HEAD."""
        return self._branch or "HEAD"

    def __str__(self) -> str:
        return f"{self.uri}"

    def __repr__(self) -> str:
        return f"Repo({self.name}, {self.uri})"

    @retry(urllib.error.URLError, tries=4, delay=3, backoff=2)
    def has_submodules(self) -> bool:
        """Check if repository has git submodules.

        Generic implementation always returns True for safety.

        Returns:
            True (conservative default)
        """
        return True

    @retry(urllib.error.URLError, tries=4, delay=3, backoff=2)
    def latest_commit(self) -> tuple[str, datetime]:
        """Fetch latest commit hash and date for the branch.

        Returns:
            Tuple of (commit_hash, commit_date)
        """
        log.debug("Latest commit")
        loaded = self._prefetch(None)
        updated = datetime.strptime(loaded["date"], "%Y-%m-%dT%H:%M:%S%z")

        return loaded["rev"], updated

    @retry(urllib.error.URLError, tries=4, delay=3, backoff=2)
    def get_latest_tag(self) -> str | None:
        """Fetch the most recent tag from the repository.

        Uses git ls-remote --tags with version sorting.

        Returns:
            Most recent tag name, or None if no tags exist
        """
        try:
            cmd = [
                "git",
                "ls-remote",
                "--tags",
                "--refs",
                "--sort=-version:refname",
                self.uri,
            ]
            log.debug("Fetching tags with: %s", cmd)
            output = subprocess.check_output(cmd, stderr=subprocess.STDOUT, timeout=10)
            lines = output.decode("utf-8").strip().split("\n")

            if not lines or lines[0] == "":
                log.debug("No tags found for %s", self.uri)
                return None

            first_line = lines[0].strip()
            if "\t" in first_line:
                tag_ref = first_line.split("\t")[1]
                if tag_ref.startswith("refs/tags/"):
                    tag_name = tag_ref[10:]
                    log.debug("Found latest tag: %s", tag_name)
                    return tag_name

            return None
        except subprocess.CalledProcessError as e:
            log.debug("Failed to fetch tags for %s: %s", self.uri, e)
            return None
        except (subprocess.TimeoutExpired, OSError) as e:
            log.warning("Error fetching tags for %s: %s", self.uri, e)
            return None

    def _prefetch(self, ref: str | None):
        """Run nix-prefetch-git to fetch repository.

        Args:
            ref: Git ref to fetch, or None for latest

        Returns:
            Parsed JSON output from nix-prefetch-git
        """
        cmd = ["nix-prefetch-git", "--quiet", "--fetch-submodules", self.uri]
        if ref is not None:
            cmd.append(ref)
        log.debug(cmd)
        data = subprocess.check_output(cmd)
        loaded = json.loads(data)
        return loaded

    def prefetch(self, ref: str) -> str:
        """Prefetch repository and return hash.

        Args:
            ref: Git ref to fetch

        Returns:
            SHA256 hash of fetched source
        """
        log.info("Prefetching %s", self.uri)
        loaded = self._prefetch(ref)
        return loaded["sha256"]

    def as_nix(self, plugin: "Plugin") -> str:
        """Generate Nix expression for fetching this plugin.

        Args:
            plugin: Plugin with commit and hash information

        Returns:
            Nix fetchgit expression
        """
        return f"""fetchgit {{
      url = "{self.uri}";
      rev = "{plugin.commit}";
      hash = "{plugin.to_sri_hash()}";
    }}"""


class RepoGitHub(Repo):
    """GitHub-specific repository implementation.

    Uses GitHub API for efficient tag fetching and checks for submodules.
    Falls back to nix-prefetch-url for repos without submodules (faster).

    Attributes:
        owner: GitHub repository owner
        repo: GitHub repository name
        token: GitHub API token for higher rate limits
    """

    def __init__(self, owner: str, repo: str, branch: str) -> None:
        """Initialize GitHub repository.

        Args:
            owner: GitHub username or organization
            repo: Repository name
            branch: Branch to fetch from
        """
        self.owner = owner
        self.repo = repo
        self.token = None
        super().__init__(self.url(""), branch)
        log.debug(
            "Instantiating github repo owner=%s and repo=%s", self.owner, self.repo
        )

    @property
    def name(self):
        """Get repository name."""
        return self.repo

    def url(self, path: str) -> str:
        """Construct GitHub URL for given path.

        Args:
            path: Path to append to repository URL

        Returns:
            Full GitHub URL
        """
        res = urljoin(f"https://github.com/{self.owner}/{self.repo}/", path)
        return res

    @retry(urllib.error.URLError, tries=4, delay=3, backoff=2)
    def has_submodules(self) -> bool:
        """Check if repository has .gitmodules file on GitHub.

        Returns:
            True if .gitmodules exists, False otherwise
        """
        try:
            req = make_request(self.url(f"blob/{self.branch}/.gitmodules"), self.token)
            with urllib.request.urlopen(req, timeout=10):
                pass
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return False
            raise
        return True

    @retry(urllib.error.URLError, tries=4, delay=3, backoff=2)
    def latest_commit(self) -> tuple[str, datetime]:
        """Fetch latest commit from GitHub Atom feed.

        Checks for repository redirects and updates self.redirect if found.

        Returns:
            Tuple of (commit_hash, commit_date)
        """
        commit_url = self.url(f"commits/{self.branch}.atom")
        log.debug("Sending request to %s", commit_url)
        commit_req = make_request(commit_url, self.token)
        with urllib.request.urlopen(commit_req, timeout=10) as req:
            self._check_for_redirect(commit_url, req)
            xml = req.read()

            # Filter out illegal XML characters
            illegal_xml_regex = re.compile(b"[\x00-\x08\x0b-\x0c\x0e-\x1f\x7f]")
            xml = illegal_xml_regex.sub(b"", xml)

            root = ET.fromstring(xml)
            latest_entry = root.find(ATOM_ENTRY)
            assert latest_entry is not None, f"No commits found in repository {self}"
            commit_link = latest_entry.find(ATOM_LINK)
            assert commit_link is not None, f"No link tag found feed entry {xml!r}"
            url = urlparse(commit_link.get("href"))
            updated_tag = latest_entry.find(ATOM_UPDATED)
            assert updated_tag is not None and updated_tag.text is not None, (
                f"No updated tag found feed entry {xml!r}"
            )
            updated = datetime.strptime(updated_tag.text, "%Y-%m-%dT%H:%M:%SZ")
            return Path(str(url.path)).name, updated

    @retry(urllib.error.URLError, tries=4, delay=3, backoff=2)
    def get_latest_tag(self) -> str | None:
        """Fetch the most recent tag using GitHub API.

        More efficient than git ls-remote for GitHub repos.

        Returns:
            Most recent tag name, or None if no tags exist or on error
        """
        try:
            tags_url = (
                f"https://api.github.com/repos/{self.owner}/{self.repo}/tags?per_page=1"
            )
            log.debug("Fetching tags from GitHub API: %s", tags_url)

            req = make_request(tags_url, self.token)
            with urllib.request.urlopen(req, timeout=10) as response:
                data = json.load(response)

                if not data or len(data) == 0:
                    log.debug("No tags found for %s/%s", self.owner, self.repo)
                    return None

                tag_name = data[0]["name"]
                log.debug("Found latest tag: %s", tag_name)
                return tag_name

        except urllib.error.HTTPError as e:
            if e.code == 404:
                log.debug(
                    "No tags endpoint or repo not found: %s/%s", self.owner, self.repo
                )
                return None
            log.warning(
                "HTTP error fetching tags for %s/%s: %s", self.owner, self.repo, e
            )
            return None
        except (urllib.error.URLError, json.JSONDecodeError, KeyError) as e:
            log.warning("Error fetching tags for %s/%s: %s", self.owner, self.repo, e)
            return None

    def _check_for_redirect(self, url: str, req: http.client.HTTPResponse):
        """Check if request was redirected and update self.redirect if so.

        Args:
            url: Original request URL
            req: HTTP response object
        """
        response_url = req.geturl()
        if url != response_url:
            new_owner, new_name = (
                urllib.parse.urlsplit(response_url).path.strip("/").split("/")[:2]
            )

            new_repo = RepoGitHub(owner=new_owner, repo=new_name, branch=self.branch)
            self.redirect = new_repo

    def prefetch(self, ref: str) -> str:
        """Prefetch repository, choosing optimal method.

        Uses nix-prefetch-git for repos with submodules, or faster
        nix-prefetch-url for repos without submodules.

        Args:
            ref: Git ref to fetch

        Returns:
            SHA256 hash of fetched source
        """
        if self.has_submodules():
            sha256 = super().prefetch(ref)
        else:
            sha256 = self.prefetch_github(ref)
        return sha256

    def prefetch_github(self, ref: str) -> str:
        """Prefetch GitHub tarball (faster for repos without submodules).

        Args:
            ref: Git ref to fetch

        Returns:
            SHA256 hash of fetched tarball
        """
        cmd = ["nix-prefetch-url", "--unpack", self.url(f"archive/{ref}.tar.gz")]
        log.debug("Running %s", cmd)
        data = subprocess.check_output(cmd)
        return data.strip().decode("utf-8")

    def as_nix(self, plugin: "Plugin") -> str:
        """Generate Nix expression for fetching this GitHub plugin.

        Args:
            plugin: Plugin with commit and hash information

        Returns:
            Nix fetchFromGitHub expression
        """
        if plugin.has_submodules:
            submodule_attr = "\n      fetchSubmodules = true;"
        else:
            submodule_attr = ""

        return f"""fetchFromGitHub {{
      owner = "{self.owner}";
      repo = "{self.repo}";
      rev = "{plugin.commit}";
      hash = "{plugin.to_sri_hash()}";{submodule_attr}
    }}"""


def make_repo(uri: str, branch) -> Repo:
    """Create appropriate Repo subclass based on URI.

    Detects GitHub repositories and creates RepoGitHub for efficiency,
    otherwise creates generic Repo.

    Args:
        uri: Repository URI (github.com URL or owner/repo shorthand)
        branch: Git branch name

    Returns:
        Repo or RepoGitHub instance
    """
    res = urlparse(uri)
    if res.netloc in ["github.com", ""]:
        owner, repo = res.path.strip("/").split("/")
        return RepoGitHub(owner, repo, branch)
    return Repo(uri.strip(), branch)
