# python library used to update plugins:
# - pkgs/applications/editors/vim/plugins/update.py
# - pkgs/applications/editors/kakoune/plugins/update.py
# - pkgs/development/lua-modules/updater/updater.py

from __future__ import annotations

import logging

from .cli import (
    LOG_LEVELS,
    Cache,
    Editor,
    check_results,
    commit,
    get_cache_path,
    load_plugins_from_csv,
    prefetch,
    prefetch_plugin,
    print_download_error,
    rewrite_input,
    update_plugins,
)
from .models import FetchConfig, Plugin, PluginDesc
from .nix import CleanEnvironment, run_nix_expr
from .repos import Repo, RepoGitHub, make_repo

log = logging.getLogger()

# a dictionary of plugins and their new repositories
Redirects = dict["PluginDesc", "Repo"]

__all__ = [
    "Cache",
    "CleanEnvironment",
    "Editor",
    "FetchConfig",
    "LOG_LEVELS",
    "Plugin",
    "PluginDesc",
    "Redirects",
    "Repo",
    "RepoGitHub",
    "check_results",
    "commit",
    "get_cache_path",
    "load_plugins_from_csv",
    "log",
    "make_repo",
    "prefetch",
    "prefetch_plugin",
    "print_download_error",
    "rewrite_input",
    "run_nix_expr",
    "update_plugins",
]
