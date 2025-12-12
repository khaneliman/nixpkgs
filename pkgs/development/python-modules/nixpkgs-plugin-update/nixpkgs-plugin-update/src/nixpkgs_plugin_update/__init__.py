# python library used to update plugins:
# - pkgs/applications/editors/vim/plugins/utils/update.py
# - pkgs/applications/editors/kakoune/plugins/update.py
# - pkgs/by-name/lu/luarocks-packages-updater/updater.py

import logging
import os
import time
from datetime import UTC, datetime

import git

# Public API - only import what external scripts need
from .editor import Editor
from .fetching import prefetch_plugin
from .operations import commit
from .plugin import Plugin, PluginDesc, load_plugins_from_csv
from .repos import Repo, RepoGitHub, make_repo
from .utils import FetchConfig, run_nix_expr

log = logging.getLogger()


def update_plugins(editor: Editor, args):
    """The main entry function of this module.
    All input arguments are grouped in the `Editor`."""

    log.info("Start updating plugins")
    if args.proc > 1 and args.github_token is None:
        log.warning(
            "You have enabled parallel updates but haven't set a github token.\n"
            "You may be hit with `HTTP Error 429: too many requests` as a consequence."
            "Either set --proc=1 or --github-token=YOUR_TOKEN. "
        )

    fetch_config = FetchConfig(args.proc, args.github_token)
    update = editor.get_update(
        input_file=args.input_file,
        output_file=args.outfile,
        config=fetch_config,
        to_update=getattr(  # if script was called without arguments
            args, "update_only", None
        ),
    )

    start_time = time.time()
    redirects = update()
    duration = time.time() - start_time
    print(f"The plugin update took {duration:.2f}s.")
    editor.rewrite_input(fetch_config, args.input_file, editor.deprecated, redirects)

    autocommit = not args.no_commit

    if autocommit:
        try:
            repo = git.Repo(os.getcwd())
            updated = datetime.now(tz=UTC).strftime("%Y-%m-%d")
            print(args.outfile)
            commit(repo, f"{editor.attr_path}: update on {updated}", [args.outfile])
        except git.InvalidGitRepositoryError:
            print("Not in a git repository, skipping commit.")


# Public API - minimal exports for external scripts
__all__ = [
    # Core classes
    "Editor",
    "Plugin",
    "PluginDesc",
    "FetchConfig",
    # Repository types (accessed via PluginDesc.repo)
    "Repo",
    "RepoGitHub",
    "make_repo",
    # Utilities
    "run_nix_expr",
    "load_plugins_from_csv",
    "prefetch_plugin",
    # Main entry point
    "update_plugins",
]
