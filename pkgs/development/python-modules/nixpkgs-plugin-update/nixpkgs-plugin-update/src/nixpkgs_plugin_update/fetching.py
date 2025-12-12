# Plugin fetching functions for nixpkgs plugin updates

import logging
import sys
import traceback
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .cache import Cache
    from .repos import Repo

from .plugin import Plugin, PluginDesc

log = logging.getLogger()

# a dictionary of plugins and their new repositories
Redirects = dict[PluginDesc, "Repo"]


def prefetch_plugin(
    p: PluginDesc,
    cache: "Cache | None" = None,
) -> tuple[Plugin, "Repo | None"]:
    """Fetch plugin metadata and source.

    Fetches commit info, git tags, and prefetches source. Uses cache when available.

    Args:
        p: Plugin descriptor specifying what to fetch
        cache: Optional cache to check/update

    Returns:
        Tuple of (Plugin with all metadata, redirect_repo or None)
    """
    commit = None
    log.info(
        "Fetching last commit for plugin %s from %s@%s", p.name, p.repo.uri, p.branch
    )
    commit, date = p.repo.latest_commit()

    latest_tag = p.repo.get_latest_tag()
    if latest_tag:
        log.debug("Latest tag for %s: %s", p.name, latest_tag)
    else:
        log.debug("No tags found for %s, will use '0' prefix", p.name)

    cached_plugin = cache[commit] if cache else None
    if cached_plugin is not None:
        log.debug("Cache hit for %s!", p.name)
        cached_plugin.name = p.name
        cached_plugin.date = date
        cached_plugin.last_tag = latest_tag
        cached_plugin.version = Plugin.compute_version(date, latest_tag)
        return cached_plugin, p.repo.redirect

    has_submodules = p.repo.has_submodules()
    log.debug("prefetch %s", p.name)
    sha256 = p.repo.prefetch(commit)

    version = Plugin.compute_version(date, latest_tag)

    return (
        Plugin(
            p.name,
            commit,
            has_submodules,
            sha256,
            version,
            date=date,
            last_tag=latest_tag,
        ),
        p.repo.redirect,
    )


def print_download_error(plugin: PluginDesc, ex: Exception):
    """Print formatted exception with traceback for plugin fetch failure.

    Args:
        plugin: Plugin that failed to fetch
        ex: Exception that was raised
    """
    print(f"{plugin}: {ex}", file=sys.stderr)
    ex_traceback = ex.__traceback__
    tb_lines = [
        line.rstrip("\n")
        for line in traceback.format_exception(ex.__class__, ex, ex_traceback)
    ]
    print("\n".join(tb_lines))


def check_results(
    results: list[tuple[PluginDesc, Exception | Plugin, "Repo | None"]],
) -> tuple[list[tuple[PluginDesc, Plugin]], Redirects]:
    """Check prefetch results, separate successes from failures, and handle redirects.

    Exits with error if any plugins failed to fetch.

    Args:
        results: List of (descriptor, plugin_or_exception, redirect) tuples

    Returns:
        Tuple of (successful_plugins, redirect_map)
    """
    failures: list[tuple[PluginDesc, Exception]] = []
    plugins = []
    redirects: Redirects = {}
    for pdesc, result, redirect in results:
        if isinstance(result, Exception):
            failures.append((pdesc, result))
        else:
            new_pdesc = pdesc
            if redirect is not None:
                redirects.update({pdesc: redirect})
                new_pdesc = PluginDesc(redirect, pdesc.branch, pdesc.alias)
            plugins.append((new_pdesc, result))

    if len(failures) == 0:
        return plugins, redirects

    log.error("%d plugin(s) could not be downloaded:\n", len(failures))

    for plugin, exception in failures:
        print_download_error(plugin, exception)

    sys.exit(1)


def prefetch(
    plugin_desc: PluginDesc, cache: "Cache"
) -> tuple[PluginDesc, Exception | Plugin, "Repo | None"]:
    """Wrapper for prefetch_plugin that catches exceptions.

    Used with multiprocessing.Pool to ensure exceptions don't kill workers.

    Args:
        plugin_desc: Plugin descriptor to fetch
        cache: Cache to check/update

    Returns:
        Tuple of (descriptor, plugin_or_exception, redirect)
    """
    try:
        plugin, redirect = prefetch_plugin(plugin_desc, cache)
        cache[plugin.commit] = plugin
        return (plugin_desc, plugin, redirect)
    except Exception as e:
        return (plugin_desc, e, None)
