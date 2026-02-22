from __future__ import annotations

import json
import logging
import os
import subprocess
from tempfile import NamedTemporaryFile
from typing import Any

log = logging.getLogger()


class CleanEnvironment(object):
    def __init__(self, nixpkgs):
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


def convert_sha256_to_sri(sha256: str) -> str:
    cmd = [
        "nix",
        "hash",
        "convert",
        "--hash-algo",
        "sha256",
        "--to",
        "sri",
        sha256,
    ]
    result = subprocess.check_output(cmd, stderr=subprocess.DEVNULL)
    return result.decode("utf-8").strip()
