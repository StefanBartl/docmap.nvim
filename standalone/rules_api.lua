---@module 'standalone.rules_api'
--- Answer one `rules/*` route of `core/api.lua` for a project and print its JSON -- on **either** host.
---
---   nvim --headless -u NONE -l standalone/rules_api.lua <project> <route> [--select=...] [--trust=<folder>]...
---   lua standalone/rules_api.lua <project> <route> [--select=...] [--trust=<folder>]...
---
--- Under Neovim it uses the real `vim.*`; under plain Lua it installs `standalone.vim_shim` first. The JSON is
--- encoded by `docmap.core.json` (sorted keys), so the same input prints the same bytes on both hosts: that is what
--- `scripts/ci.lua`'s `standalone` gate compares, and it compares this script under Neovim with the real entry point
--- (`standalone/docmap.lua --api=...`) under PUC Lua, so the routes are held to the editor as the binary runs them.
---
--- The waivers of a run are judged against a fixed date (2026-01-01), not today's: a fixture with a waiver that
--- expires must not change its answer the day it expires. `standalone/docmap.lua` judges against the real date, so
--- the gate's fixture only holds waivers without an expiry.
---
--- Dependencies are found the way `standalone/rules_results.lua` finds them: `RULES_NVIM_DIR` / `LIB_NVIM_DIR`,
--- then `.deps/<name>`, then a sibling directory of this repository.

local script = debug.getinfo(1, "S").source:sub(2):gsub("\\", "/")
local self_root = (script:match("^(.*)/standalone/[^/]*$") or ".")

---Put `<dir>/lua` on `package.path` for the first candidate that has `probe`.
---@param name string
---@param probe string A path under `lua/` that proves the checkout is the right one.
local function find_dependency(name, probe)
  local env = os.getenv(name:upper():gsub("[.-]", "_") .. "_DIR")
  local candidates = {}
  if env and env ~= "" then
    candidates[#candidates + 1] = env
  end
  candidates[#candidates + 1] = self_root .. "/.deps/" .. name
  candidates[#candidates + 1] = self_root .. "/../" .. name
  for _, dir in ipairs(candidates) do
    local fd = io.open(dir .. "/lua/" .. probe, "r")
    if fd then
      fd:close()
      package.path = dir .. "/lua/?.lua;" .. dir .. "/lua/?/init.lua;" .. package.path
      return
    end
  end
  io.stderr:write(
    ("standalone/rules_api.lua: %s not found (set %s_DIR, or .deps/%s)\n"):format(
      name,
      name:upper():gsub("[.-]", "_"),
      name
    )
  )
  os.exit(2)
end

local project, route, selection
local trust = {}
for _, a in ipairs(arg) do
  local sel = a:match("^%-%-select=(.+)$")
  local tr = a:match("^%-%-trust=(.+)$")
  if sel then
    selection = sel
  elseif tr then
    trust[#trust + 1] = tr
  elseif not project then
    project = a
  elseif not route then
    route = a
  end
end
if not project or not route then
  io.stderr:write("usage: rules_api.lua <project> <route> [--select=...] [--trust=<folder>]...\n")
  os.exit(2)
end

package.path = self_root
  .. "/?.lua;"
  .. self_root
  .. "/lua/?.lua;"
  .. self_root
  .. "/lua/?/init.lua;"
  .. package.path
find_dependency("lib.nvim", "lib/lua/error/init.lua")
find_dependency("rules.nvim", "rules/engine/runner.lua")

if not rawget(_G, "vim") then
  require("standalone.vim_shim")
end

local result, err = require("docmap.core.api").answer(route, {
  root = project,
  rules_trust = trust,
  rules_today = "2026-01-01",
}, selection)
if not result then
  io.stderr:write("standalone/rules_api.lua: " .. tostring(err) .. "\n")
  os.exit(2)
end
io.stdout:write(require("docmap.core.json").encode(result) .. "\n")
