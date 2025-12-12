# Utility functions and helpers for nixpkgs plugin updates

import json
import logging
import os
import subprocess
import time
import urllib.request
from dataclasses import dataclass
from functools import wraps
from tempfile import NamedTemporaryFile
from typing import Any, Callable

ATOM_ENTRY = "{http://www.w3.org/2005/Atom}entry"  # " vim gets confused here
ATOM_LINK = "{http://www.w3.org/2005/Atom}link"  # "
ATOM_UPDATED = "{http://www.w3.org/2005/Atom}updated"  # "

LOG_LEVELS = {
    logging.getLevelName(level): level
    for level in [logging.DEBUG, logging.INFO, logging.WARN, logging.ERROR]
}

log = logging.getLogger()


@dataclass
class FetchConfig:
    proc: int
    github_token: str


def retry(
    exception_to_check: Any, tries: int = 4, delay: float = 3, backoff: float = 2
):
    """Retry calling the decorated function using an exponential backoff.
    http://www.saltycrane.com/blog/2009/11/trying-out-retry-decorator-python/
    original from: http://wiki.python.org/moin/PythonDecoratorLibrary#Retry
    (BSD licensed)
    :param exception_to_check: the exception on which to retry
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
                except exception_to_check as e:
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


class CleanEnvironment:
    def __init__(self, nixpkgs: str):
        self.local_pkgs = nixpkgs

    def __enter__(self) -> str:
        """
        local_pkgs = str(Path(__file__).parent.parent.parent)
        """
        self.old_environ = os.environ.copy()
        self.empty_config = NamedTemporaryFile()
        self.empty_config.write(b"{}")
        self.empty_config.flush()
        return f"localpkgs={self.local_pkgs}"

    def __exit__(self, exc_type: Any, exc_value: Any, traceback: Any) -> None:
        os.environ.update(self.old_environ)
        self.empty_config.close()


def run_nix_expr(expr, nixpkgs: str, **args):
    """
    :param expr nix expression to fetch current plugins
    :param nixpkgs Path towards a nixpkgs checkout
    """
    with CleanEnvironment(nixpkgs) as nix_path:
        cmd = [
            "nix",
            "eval",
            "--extra-experimental-features",
            "nix-command",
            "--impure",
            "--json",
            "--expr",
            expr,
            "--nix-path",
            nix_path,
        ]
        log.debug("Running command: %s", " ".join(cmd))
        out = subprocess.check_output(cmd, **args)
        data = json.loads(out)
        return data
