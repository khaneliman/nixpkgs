# python library used to update plugins:
# - pkgs/applications/editors/vim/plugins/utils/update.py
# - pkgs/applications/editors/kakoune/plugins/update.py
# - pkgs/by-name/lu/luarocks-packages-updater/updater.py

import logging

# Public API - only import what external scripts need
from .editor import Editor
from .fetching import prefetch_plugin
from .operations import commit
from .plugin import Plugin, PluginDesc, load_plugins_from_csv
from .repos import Repo, RepoGitHub, make_repo
from .utils import FetchConfig, run_nix_expr

log = logging.getLogger()
