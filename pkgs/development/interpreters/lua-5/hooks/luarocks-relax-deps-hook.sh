# shellcheck shell=bash
# Setup hook that drops version constraints from rockspec dependencies before
# `luarocks make` checks them.
#
# Set "luarocksRelaxDeps" to a list of dependency names, or to true to relax
# every dependency except lua itself.

luarocksRelaxDepsHook() {
    if [[ -z "${luarocksRelaxDeps[*]-}" ]]; then
        return
    fi
    echo "Executing luarocksRelaxDepsHook"

    # luarocks make reads only the lockfile's pins while one exists in the working directory
    if [[ -e luarocks.lock ]]; then
        echo "luarocksRelaxDepsHook: luarocks.lock overrides the rockspec constraints; remove it in preConfigure" >&2
        exit 1
    fi

    # rockspecFilename is set by buildLuarocksPackage's configurePhase
    # shellcheck disable=SC2154
    LUA_PATH="@luarocksPath@" @interpreter@ @script@ "$rockspecFilename" "${luarocksRelaxDeps[@]}"
}

postConfigureHooks+=(luarocksRelaxDepsHook)
