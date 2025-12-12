# Helper operations for plugin management

import csv
import json
import logging
from dataclasses import asdict
from datetime import datetime
from pathlib import Path

import git

from .fetching import Redirects, prefetch_plugin
from .plugin import PluginDesc, load_plugins_from_csv
from .utils import FetchConfig

log = logging.getLogger()


def rewrite_input(
    config: FetchConfig,
    input_file: Path,
    deprecated: Path,
    redirects: Redirects | None = None,
    append: list[PluginDesc] | None = None,
):
    log.info("Rewriting input file %s", input_file)

    if redirects is None:
        redirects = {}
    if append is None:
        append = []

    plugins = load_plugins_from_csv(config, input_file)

    plugins.extend(append)

    if redirects:
        log.debug("Dealing with deprecated plugins listed in %s", deprecated)

        cur_date_iso = datetime.now().strftime("%Y-%m-%d")
        with open(deprecated, "r", encoding="utf-8") as f:
            deprecations = json.load(f)
        # TODO parallelize this step
        for pdesc, new_repo in redirects.items():
            log.info("Resolving deprecated plugin %s -> %s", pdesc.name, new_repo.name)
            new_pdesc = PluginDesc(new_repo, pdesc.branch, pdesc.alias)

            old_plugin, _ = prefetch_plugin(pdesc)
            new_plugin, _ = prefetch_plugin(new_pdesc)

            if old_plugin.normalized_name != new_plugin.normalized_name:
                deprecations[old_plugin.normalized_name] = {
                    "new": new_plugin.normalized_name,
                    "date": cur_date_iso,
                }

            for i, plugin in enumerate(plugins):
                if plugin.name == pdesc.name:
                    plugins.pop(i)
                    break
            plugins.append(new_pdesc)

        with open(deprecated, "w", encoding="utf-8") as f:
            json.dump(deprecations, f, indent=4, sort_keys=True)
            f.write("\n")

    with open(input_file, "w", encoding="utf-8") as f:
        log.debug("Writing into %s", input_file)
        fieldnames = ["repo", "branch", "alias"]
        writer = csv.DictWriter(f, fieldnames, dialect="unix", quoting=csv.QUOTE_NONE)
        writer.writeheader()
        for plugin in sorted(plugins, key=lambda x: x.name):
            writer.writerow(asdict(plugin))


def commit(repo: git.Repo, message: str, files: list[Path]) -> None:
    repo.index.add([str(f.resolve()) for f in files])

    if repo.index.diff("HEAD"):
        print(f'committing to nixpkgs "{message}"')
        repo.index.commit(message)
    else:
        print("no changes in working tree to commit")
