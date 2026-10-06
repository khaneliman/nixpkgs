-- Drop version constraints from rockspec dependencies.
--
-- usage: lua luarocks-relax-deps.lua <rockspec> 1        relax every dependency except lua
--        lua luarocks-relax-deps.lua <rockspec> name...  relax the named dependencies
--
-- The rockspec is loaded with luarocks' own loader to find entries of
-- dependencies, build_dependencies and test_dependencies (including platform
-- overrides). Each relaxed entry is then reassigned by its table path in Lua
-- statements appended to the rockspec, so the rest of the file stays as
-- written; re-serializing the table would drop the nil placeholders platform
-- overrides use for positional merges.
local persist = require("luarocks.core.persist")

local file = arg[1]
local all = #arg == 2 and arg[2] == "1"
local wanted = {}
if not all then
  for i = 2, #arg do
    wanted[arg[i]:lower()] = true
  end
end

local function die(msg)
  io.stderr:write("luarocksRelaxDepsHook: ", msg, "\n")
  os.exit(1)
end

local spec, err = persist.load_into_table(file)
if not spec then
  die(err)
end

-- Returns the dependency names in rockspec, and an assignment plus a log line for
-- each entry that should be relaxed.
local function collect(rockspec)
  local seen, assignments, log = {}, {}, {}
  local function relax(list, path)
    if type(list) ~= "table" then
      return
    end
    for i, dep in pairs(list) do
      -- same name pattern as luarocks.queries.from_dep_string
      local name = type(i) == "number" and type(dep) == "string"
        and dep:match("^%s*([a-zA-Z0-9%.%-%_]*/?[a-zA-Z0-9][a-zA-Z0-9%.%-%_]*)")
      local key = name and name:lower()
      if key then
        seen[key] = true
        if (wanted[key] or (all and key ~= "lua")) and dep ~= name then
          table.insert(assignments, ("%s[%d] = %q"):format(path, i, name))
          table.insert(log, ("luarocksRelaxDepsHook: %s -> %s"):format(dep, name))
        end
      end
    end
    if type(list.platforms) == "table" then
      for platform, sub in pairs(list.platforms) do
        relax(sub, ("%s.platforms[%q]"):format(path, platform))
      end
    end
  end
  for _, key in ipairs({ "dependencies", "build_dependencies", "test_dependencies" }) do
    relax(rockspec[key], key)
  end
  return seen, assignments, log
end

local seen, assignments, log = collect(spec)

for name in pairs(wanted) do
  if not seen[name] then
    die(("%q is not a dependency in %s"):format(name, file))
  end
end

if #assignments == 0 then
  return
end

table.sort(assignments)
local fd = assert(io.open(file))
local text = fd:read("*a")
fd:close()
-- write a new file instead of appending: a knownRockspec copied from the store is read-only
local tmp = file .. ".relaxed"
fd = assert(io.open(tmp, "w"))
fd:write(text, "\n-- added by nixpkgs luarocksRelaxDeps\n", table.concat(assignments, "\n"), "\n")
fd:close()

-- the appended lines are a syntax error after a top-level `return`, and never
-- run after an earlier one such as `do return end`
local relaxed, problem = persist.load_into_table(tmp)
if relaxed then
  local _, leftover = collect(relaxed)
  problem = #leftover > 0 and "the appended assignments did not run" or nil
end
if problem then
  os.remove(tmp)
  die(("cannot relax dependencies in %s, patch it instead: %s"):format(file, problem))
end
assert(os.rename(tmp, file))
print(table.concat(log, "\n"))
