---@module 'standalone.rules_agent_smoke'
--- Run the pure part of `rules.nvim`'s agent pipeline -- the planner, the request writer, the check of a model's
--- answer, the glob matcher and the verdict store's reading and ageing -- on **either** host and print what
--- came out, one line each.
---
---   nvim --headless -u NONE -l standalone/rules_agent_smoke.lua <project>
---   lua standalone/rules_agent_smoke.lua <project>
---
--- Under Neovim it uses the real `vim.*`; under plain Lua it installs `standalone.vim_shim` first. The output is the
--- same for the same input, so a caller runs both and compares: that is how the shim is shown to answer what those
--- modules ask (`scripts/ci.lua`'s `standalone` gate does it, as for `standalone/rules_results.lua`).
---
--- Not covered, on purpose: `verdicts.encode` and `verdicts.accept` and the answer cache (they write, through `lib.nvim.json.canonical` and `lib.nvim.fs.write.atomic`,
--- which the shim has no `uv` for) and `:Rules agent` itself (the editor's glue). Both are in `rules.nvim`'s own specs.
---
--- Dependencies are found the way `standalone/rules_results.lua` finds them: `RULES_NVIM_DIR` / `LIB_NVIM_DIR`, then
--- `.deps/<name>`, then a sibling directory of this repository.

local script = debug.getinfo(1, "S").source:sub(2):gsub("\\", "/")
local self_root = (script:match("^(.*)/standalone/[^/]*$") or ".")

---@param name string
---@param probe string
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
    ("standalone/rules_agent_smoke.lua: %s not found (set the _DIR variable, or .deps/%s)\n"):format(
      name,
      name
    )
  )
  os.exit(2)
end

local project = arg[1]
if not project then
  io.stderr:write("usage: rules_agent_smoke.lua <project>\n")
  os.exit(2)
end
project = project:gsub("\\", "/"):gsub("/+$", "")

package.path = self_root .. "/?.lua;" .. package.path
find_dependency("lib.nvim", "lib/lua/error/init.lua")
find_dependency("rules.nvim", "rules/engine/agent/plan.lua")

if not rawget(_G, "vim") then
  require("standalone.vim_shim")
end

local glob = require("rules.engine.glob")
local plan_lib = require("rules.engine.agent.plan")
local request = require("rules.engine.agent.request")
local validate = require("rules.engine.agent.validate")
local verdicts = require("rules.engine.verdicts")

local lines = {}
---@param ... any
local function out(...)
  local parts = {}
  for i = 1, select("#", ...) do
    parts[#parts + 1] = tostring((select(i, ...)))
  end
  lines[#lines + 1] = (table.concat(parts, "\t"):gsub("[\r\n]", " "))
end

-- glob
for _, case in ipairs({
  { "lua/**/*.lua", "lua/a.lua" },
  { "lua/*.lua", "lua/x/a.lua" },
  { "./lua//a.lua", "lua/a.lua" },
  { "**/*.PEM", "keys/s.pem" },
}) do
  out("GLOB", case[1], case[2], glob.matches(case[1], case[2]))
end

-- plan
local function rule(id, extra)
  local r = { id = id, severity = "recommended", title = id .. " title", text = "Text of " .. id }
  for k, v in pairs(extra or {}) do
    r[k] = v
  end
  return r
end
local plan = plan_lib.plan(
  {
    rule("DEP-02"),
    rule("DEP-01"),
    rule("ERR-01"),
    rule("DEP-03", { check = { type = "file_exists", path = "lua/a.lua" } }),
  },
  project,
  { agent = { scopes = { DEP = { include = { "**" } } }, batch_size = 8, deny = { "secrets" } } }
)
out(
  "PLAN",
  "batches=" .. #plan.batches,
  "skipped=" .. #plan.skipped,
  "denied=" .. table.concat(plan.denied, ",")
)
for _, batch in ipairs(plan.batches) do
  local ids = {}
  for _, entry in ipairs(batch.rules) do
    ids[#ids + 1] = entry.rule.id .. ":" .. entry.source
  end
  out("BATCH", batch.id, table.concat(batch.files, ","), table.concat(ids, ","))
end
for _, skipped in ipairs(plan.skipped) do
  out("SKIP", skipped.rule.id, skipped.status, skipped.reason)
end

-- request
local req = assert(request.build(plan.batches[1], project))
out(
  "REQUEST",
  "sent=" .. table.concat(req.sent, ","),
  "unreadable=" .. table.concat(req.unreadable, ",")
)
out("REQUEST", "numbered=" .. tostring(req.prompt:find("2: local b = require", 1, true) ~= nil))

-- validate
local function answer(entry)
  return '{"results":[' .. entry .. "]}"
end
local sent = req.sent
local cases = {
  answer(
    '{"rule":"DEP-01","verdict":"violation","checked":["lua/a.lua"],"findings":[{"file":"lua/a.lua","line":2,"quote":"require(\\"x\\")","why":"hidden"}]}'
  ),
  answer(
    '{"rule":"DEP-01","verdict":"violation","checked":["lua/a.lua"],"findings":[{"file":"lua/a.lua","line":2,"quote":"not there at all"}]}'
  ),
  answer('{"rule":"DEP-01","verdict":"compliant","checked":["lua/b.lua"]}'),
  answer('{"rule":"OTHER-01","verdict":"compliant","checked":["lua/b.lua"]}'),
  "Looks fine!",
  "```json\n" .. answer('{"rule":"DEP-01","verdict":"unclear","reason":"needs more"}') .. "\n```",
  '{"results":[{"rule":"DEP-01","verdict":"violation","checked":null,"findings":null}]}',
}
for index, text in ipairs(cases) do
  local result = validate.validate({ id = "DEP-01" }, text, project, { sent = sent })
  out(
    "VALIDATE",
    index,
    result.status,
    "findings=" .. #result.findings,
    "dropped=" .. #result.dropped,
    "unchecked=" .. table.concat(result.unchecked, ","),
    result.reason or "-"
  )
end

-- verdicts: reading, encoding, ageing (no write)
local doc = '{"DEP-01":{"verdict":"compliant","date":"2026-10-10","by":"S","evidence":[{"file":"lua/a.lua","line":2}],'
  .. '"note":"checked","from_proposal":{"status":"compliant","model":"m"}},'
  .. '"GONE-01":{"verdict":"violation","date":"2026-10-12","by":"S","evidence":[]}}'
local entries, err = verdicts.parse(doc, "doc")
out("VERDICTS", "parsed=" .. tostring(entries ~= nil), err or "-")
if entries then
  local stale = verdicts.stale(
    entries,
    { files = { ["lua/a.lua"] = "2026-10-11" }, rules = { ["GONE-01"] = "2026-10-20" } }
  )
  for _, item in ipairs(stale) do
    out("STALE", item.id, table.concat(item.reasons, ";"))
  end
  out("ORPHANED", table.concat(verdicts.orphaned(entries, { { id = "DEP-01" } }), ","))
end
local _, bad =
  verdicts.parse('{"DEP-01":{"verdict":"unclear","date":"2026-10-10","by":"S"}}', "doc")
out("VERDICTS", "refused=" .. tostring(bad))

io.stdout:write(table.concat(lines, "\n"), "\n")
