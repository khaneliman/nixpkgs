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
        to_update=getattr(args, "update_only", None),
    )

    start_time = time.time()
    redirects, updated_plugins = update()
    duration = time.time() - start_time
    print(f"The plugin update took {duration:.2f}s.")
    editor.rewrite_input(fetch_config, args.input_file, editor.deprecated, redirects)

    autocommit = not args.no_commit

    if autocommit:
        try:
            repo = git.Repo(os.getcwd())

            if len(updated_plugins) == 0:
                updated = datetime.now(tz=UTC).strftime("%Y-%m-%d")
                message = f"{editor.attr_path}: update on {updated}"
            elif len(updated_plugins) == 1:
                name, old_ver, new_ver = updated_plugins[0]
                message = f"{editor.attr_path}.{name}: {old_ver} -> {new_ver}"
            elif len(updated_plugins) <= 5:
                names = ",".join(p[0] for p in updated_plugins)
                message = f"{editor.attr_path}.{{{names}}}: update"
            else:
                count = len(updated_plugins)
                message = f"{editor.attr_path}: update {count} plugins"

            print(args.outfile)
            commit(repo, message, [args.outfile])
        except git.InvalidGitRepositoryError:
            print("Not in a git repository, skipping commit.")


# Public API - minimal exports for external scripts
__all__ = [
    "Editor",
    "Plugin",
    "PluginDesc",
    "FetchConfig",
    "Repo",
    "RepoGitHub",
    "make_repo",
    "run_nix_expr",
    "load_plugins_from_csv",
    "prefetch_plugin",
    "update_plugins",
]
