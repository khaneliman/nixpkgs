from __future__ import annotations

import http
import json
import logging
import re
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime
from functools import wraps
from pathlib import Path
from typing import TYPE_CHECKING, Any, Callable
from urllib.parse import urljoin, urlparse

from packaging.version import InvalidVersion, parse as parse_version

if TYPE_CHECKING:
    from .models import Plugin

ATOM_ENTRY = "{http://www.w3.org/2005/Atom}entry"  # " vim gets confused here
ATOM_LINK = "{http://www.w3.org/2005/Atom}link"  # "
ATOM_UPDATED = "{http://www.w3.org/2005/Atom}updated"  # "

GIT_TAGS_PREFIX = "refs/tags/"

log = logging.getLogger()


def retry(ExceptionToCheck: Any, tries: int = 4, delay: float = 3, backoff: float = 2):
    """Retry calling the decorated function using an exponential backoff.
    http://www.saltycrane.com/blog/2009/11/trying-out-retry-decorator-python/
    original from: http://wiki.python.org/moin/PythonDecoratorLibrary#Retry
    (BSD licensed)
    :param ExceptionToCheck: the exception on which to retry
    :param tries: number of times to try (not retry) before giving up
    :param delay: initial delay between retries in seconds
    :param backoff: backoff multiplier e.g. value of 2 will double the delay
        each retry
    """

    def deco_retry(f: Callable) -> Callable:
        @wraps(f)
        def f_retry(*args: Any, **kwargs: Any) -> Any:
            mtries, mdelay = tries, delay
            while mtries > 1:
                try:
                    return f(*args, **kwargs)
                except ExceptionToCheck as e:
                    print(f"{str(e)}, Retrying in {mdelay} seconds...")
                    time.sleep(mdelay)
                    mtries -= 1
                    mdelay *= backoff
            return f(*args, **kwargs)

        return f_retry  # true decorator

    return deco_retry


def make_request(url: str, token=None) -> urllib.request.Request:
    headers = {}
    if token is not None:
        headers["Authorization"] = f"token {token}"
    return urllib.request.Request(url, headers=headers)


class Repo:
    def __init__(self, uri: str, branch: str) -> None:
        self.uri = uri
        """Url to the repo"""
        self._branch = branch
        # Redirect is the new Repo to use
        self.redirect: Repo | None = None
        self.token: str | None = "dummy_token"

    @property
    def name(self):
        return self.uri.strip("/").split("/")[-1]

    @property
    def branch(self):
        return self._branch or "HEAD"

    def __str__(self) -> str:
        return f"{self.uri}"

    def __repr__(self) -> str:
        return f"Repo({self.name}, {self.uri})"

    @retry(urllib.error.URLError, tries=4, delay=3, backoff=2)
    def has_submodules(self) -> bool:
        return True

    @retry(urllib.error.URLError, tries=4, delay=3, backoff=2)
    def latest_commit(self) -> tuple[str, datetime]:
        log.debug("Latest commit")
        loaded = self._prefetch(None)
        updated = datetime.strptime(loaded["date"], "%Y-%m-%dT%H:%M:%S%z")

        return loaded["rev"], updated

    @retry(urllib.error.URLError, tries=4, delay=3, backoff=2)
    def get_latest_tag(self) -> str | None:
        try:
            # FIXME: This fetches all tags. We need to find a way to check if a tag exists in
            # an ancestor of the default branch.
            cmd = ["git", "ls-remote", "--tags", "--refs", self.uri]
            log.debug("Fetching tags with: %s", cmd)
            output = subprocess.check_output(cmd, stderr=subprocess.STDOUT, timeout=10)
            lines = output.decode("utf-8").strip().split("\n")

            if not lines or lines[0] == "":
                log.debug("No tags found for %s", self.uri)
                return None

            tags = []
            for line in lines:
                if "\t" in line:
                    tag_ref = line.split("\t")[1]
                    if tag_ref.startswith(GIT_TAGS_PREFIX):
                        tag_name = tag_ref[len(GIT_TAGS_PREFIX) :]
                        tags.append(tag_name)

            if not tags:
                return None

            valid_versions = []
            invalid_tags = []

            for tag in tags:
                try:
                    version = parse_version(tag)
                    valid_versions.append((tag, version))
                except InvalidVersion:
                    invalid_tags.append(tag)

            if valid_versions:
                latest_tag = max(valid_versions, key=lambda x: x[1])[0]
            elif invalid_tags:
                latest_tag = max(invalid_tags)
            else:
                log.debug("No tags found for %s", self.uri)
                return None

            log.debug("Found latest tag: %s", latest_tag)
            return latest_tag
        except subprocess.CalledProcessError as e:
            log.debug("Failed to fetch tags for %s: %s", self.uri, e)
            return None
        except Exception as e:
            log.warning("Unexpected error fetching tags for %s: %s", self.uri, e)
            return None

    def _prefetch(self, ref: str | None):
        cmd = ["nix-prefetch-git", "--quiet", "--fetch-submodules", self.uri]
        if ref is not None:
            cmd.append(ref)
        log.debug(cmd)
        data = subprocess.check_output(cmd)
        loaded = json.loads(data)
        return loaded

    def prefetch(self, ref: str) -> str:
        log.info("Prefetching %s", self.uri)
        loaded = self._prefetch(ref)
        return loaded["sha256"]

    def as_nix(self, plugin: Plugin) -> str:
        return f"""fetchgit {{
      url = "{self.uri}";
      rev = "{plugin.commit}";
      hash = "{plugin.to_sri_hash()}";
    }}"""


class RepoGitHub(Repo):
    def __init__(self, owner: str, repo: str, branch: str) -> None:
        self.owner = owner
        self.repo = repo
        self.token = None
        """Url to the repo"""
        super().__init__(self.url(""), branch)
        log.debug(
            "Instantiating github repo owner=%s and repo=%s", self.owner, self.repo
        )

    @property
    def name(self):
        return self.repo

    def url(self, path: str) -> str:
        res = urljoin(f"https://github.com/{self.owner}/{self.repo}/", path)
        return res

    @retry(urllib.error.URLError, tries=4, delay=3, backoff=2)
    def has_submodules(self) -> bool:
        try:
            req = make_request(self.url(f"blob/{self.branch}/.gitmodules"), self.token)
            urllib.request.urlopen(req, timeout=10).close()
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return False
            else:
                raise
        return True

    @retry(urllib.error.URLError, tries=4, delay=3, backoff=2)
    def latest_commit(self) -> tuple[str, datetime]:
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

    def _execute_graphql(self, query: str, variables: dict) -> dict:
        graphql_url = "https://api.github.com/graphql"

        payload = json.dumps({"query": query, "variables": variables}).encode("utf-8")

        req = make_request(graphql_url, self.token)
        req.add_header("Content-Type", "application/json")
        req.data = payload

        with urllib.request.urlopen(req, timeout=10) as response:
            return json.load(response)

    def _extract_commit_date(self, target: dict) -> datetime | None:
        commit_date_str = None
        if "committedDate" in target:
            commit_date_str = target["committedDate"]
        elif "target" in target and "committedDate" in target["target"]:
            commit_date_str = target["target"]["committedDate"]

        if commit_date_str:
            return datetime.fromisoformat(commit_date_str.replace("Z", "+00:00"))
        return None

    @retry(urllib.error.URLError, tries=4, delay=3, backoff=2)
    def get_latest_tag(self) -> str | None:
        try:
            if not self.token or self.token == "":
                log.info(
                    "No GitHub token available for %s/%s, using git ls-remote fallback",
                    self.owner,
                    self.repo,
                )
                return super().get_latest_tag()

            # FIXME: This fetches all tags. We need to find a way to check if a tag exists in
            # an ancestor of the default branch.
            query = """
            query GetLatestVersionInfo($owner: String!, $name: String!) {
              repository(owner: $owner, name: $name) {
                refs(refPrefix: "refs/tags/", first: 5, orderBy: {field: TAG_COMMIT_DATE, direction: DESC}) {
                  nodes {
                    name
                    target {
                      ... on Commit {
                        committedDate
                      }
                      ... on Tag {
                        target {
                          ... on Commit {
                            committedDate
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
            """

            data = self._execute_graphql(
                query, {"owner": self.owner, "name": self.repo}
            )

            if "errors" in data:
                log.warning(
                    "GraphQL errors for %s/%s: %s",
                    self.owner,
                    self.repo,
                    data["errors"],
                )
                return None

            if "data" not in data or not data["data"]:
                log.warning(
                    "No data in GraphQL response for %s/%s", self.owner, self.repo
                )
                return None

            repo = data["data"]["repository"]
            if not repo:
                log.debug(
                    "Repository %s/%s not found or inaccessible", self.owner, self.repo
                )
                return None

            valid_versions = []
            invalid_tags = []
            for ref_node in repo["refs"]["nodes"]:
                tag_name = ref_node["name"]
                commit_date = self._extract_commit_date(ref_node["target"])
                if not commit_date:
                    continue

                try:
                    version = parse_version(tag_name)
                    valid_versions.append((tag_name, version, commit_date))
                except InvalidVersion:
                    invalid_tags.append((tag_name, None, commit_date))

            def get_version(tag_tuple):
                _, version, _ = tag_tuple
                return version

            def get_date(tag_tuple):
                _, _, date = tag_tuple
                return date or datetime.min

            def get_max_versions(versions, sort_key):
                return max(versions, key=sort_key, default=(None, None, None))

            max_valid_tag, _, max_valid_date = get_max_versions(
                valid_versions, get_version
            )
            max_invalid_tag, _, max_invalid_date = get_max_versions(
                invalid_tags, get_date
            )
            if max_valid_tag and max_invalid_tag:
                return (
                    max_invalid_tag
                    if (max_invalid_date or datetime.min)
                    > (max_valid_date or datetime.min)
                    else max_valid_tag
                )
            elif max_valid_tag:
                return max_valid_tag
            elif max_invalid_tag:
                return max_invalid_tag
            else:
                return None

        except Exception as e:
            log.warning(
                "Error fetching version info for %s/%s: %s",
                self.owner,
                self.repo,
                e,
                exc_info=True,
            )
            return None

    def _check_for_redirect(self, url: str, req: http.client.HTTPResponse):
        response_url = req.geturl()
        if url != response_url:
            new_owner, new_name = (
                urllib.parse.urlsplit(response_url).path.strip("/").split("/")[:2]
            )

            new_repo = RepoGitHub(owner=new_owner, repo=new_name, branch=self.branch)
            self.redirect = new_repo

    def prefetch(self, commit: str) -> str:
        if self.has_submodules():
            sha256 = super().prefetch(commit)
        else:
            sha256 = self.prefetch_github(commit)
        return sha256

    def prefetch_github(self, ref: str) -> str:
        cmd = ["nix-prefetch-url", "--unpack", self.url(f"archive/{ref}.tar.gz")]
        log.debug("Running %s", cmd)
        data = subprocess.check_output(cmd)
        return data.strip().decode("utf-8")

    def as_nix(self, plugin: Plugin) -> str:
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
    """Instantiate a Repo with the correct specialization depending on server (gitub spec)"""
    # dumb check to see if it's of the form owner/repo (=> github) or https://...
    res = urlparse(uri)
    if res.netloc in ["github.com", ""]:
        owner, repo = res.path.strip("/").split("/")
        return RepoGitHub(owner, repo, branch)
    else:
        return Repo(uri.strip(), branch)
