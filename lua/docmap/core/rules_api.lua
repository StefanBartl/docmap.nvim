---@module 'docmap.core.rules_api'
--- The `rules/*` routes of `core/api.lua`: `rules.nvim`'s engine answering for one project, as plain tables.
---
--- Step P2 of the Rules tab of `docmap-desktop` (`RULES_AGENT_CONCEPT.md`, D4-B): the desktop app has no Neovim, so
--- the engine it bundles answers these through `--api=rules/catalog` and `--api=rules/run`, and `editor/serve.lua`
--- answers the same routes from inside the editor. One definition of the answers, two transports.
---
--- **What is read, and from where.** The rulesets and gates come from `rules.settings.resolve({ project = root })`:
--- the project's own `.rules.json` first, then the vault (`$RULES_VAULT`), exactly as `rules.nvim` resolves them for
--- `:Rules check` -- a second reader here would be a second, drifting definition of that file. Waivers come from the
--- project's `.rules-waivers.json` (`rules.engine.waivers`), a file that exists and cannot be used is an answer with
--- a reason, never "no waivers".
---
--- **Trust is the host's, per rule.** A `lua_predicate` is code from a ruleset, and the app takes any folder as a
--- project. So a predicate runs only when its rule file lies (by real path) under a folder the host named in
--- `opts.rules_trust` (`--trust=<folder>` on the command line; the desktop trust store decides what to pass). That is
--- stricter than `rules.settings` on purpose: there a vault named by `$RULES_VAULT` is trusted because the user set the
--- variable, but a child process of an app inherits an environment nobody looked at for this run. Everything else
--- a ruleset says (grep, file_exists, json_key_absent) runs regardless: those read files, they do not execute them.
--- An untrusted predicate reports `error` with `NOT_TRUSTED`, visibly, never silently absent (D5).
---
--- **Absence is an answer** (the rule `core/api.lua` states): `rules.nvim` not part of this engine, a `.rules.json`
--- that cannot be used, no ruleset configured, a selection that names nothing -- each is
--- `{ available = false, reason = ... }`.

local M = {}

---What a predicate the host did not trust reports, as the finding's text.
M.NOT_TRUSTED = "predicate not trusted: the host has not trusted this ruleset (--trust=<folder>)"

---What a route answers when `rules.nvim` cannot be loaded at all.
M.NO_ENGINE = "rules.nvim is not part of this engine"

---The statuses `rules.engine.runner` reports, in the order counts are listed.
M.STATUSES = { "pass", "fail", "error", "manual", "waived" }

---`rules.nvim`'s modules, or nil when it is not reachable from this host.
---@return table|nil engine `{ settings, loader, runner, waivers }`
function M.engine()
  local probe = require("docmap.core.soft_require").probe
  local settings = probe("rules.settings")
  local loader = probe("rules.engine.loader")
  local runner = probe("rules.engine.runner")
  local waivers = probe("rules.engine.waivers")
  if not (settings and loader and runner and waivers) then
    return nil
  end
  return { settings = settings, loader = loader, runner = runner, waivers = waivers }
end

---`/`-separated, no trailing slash, `.` and `..` segments folded: a ruleset a `.rules.json` names as `../ruleset`
---reaches the loader as `<project>/../ruleset`, and a path the app shows (and opens) should not read like that.
---Lexical only, no link is resolved; a leading `..` that has nothing to fold stays.
---@param path string
---@return string
local function slashed(path)
  local s = tostring(path):gsub("\\", "/")
  local head, rest = s:match("^(//[^/]+/[^/]+)(.*)$")
  if not head then
    head, rest = s:match("^(%a:/)(.*)$")
  end
  if not head then
    head, rest = s:match("^(/)(.*)$")
  end
  if not head then
    head, rest = "", s
  end
  local parts = {}
  for seg in rest:gmatch("[^/]+") do
    if seg == ".." and #parts > 0 and parts[#parts] ~= ".." then
      parts[#parts] = nil
    elseif seg ~= "." and not (seg == ".." and head ~= "") then
      parts[#parts + 1] = seg
    end
  end
  local out = head .. table.concat(parts, "/")
  if head:match("^//") and #parts > 0 then
    out = head .. "/" .. table.concat(parts, "/")
  end
  if out == "" then
    return "."
  end
  return out
end

---Whether a file or folder lies under a folder the host trusts. Built on `rules.settings.trust_check`, so it compares
---real paths the way `rules.nvim` does (a link out of a trusted folder is not trusted).
---@param engine table
---@param trust string[]|nil
---@return fun(path: string): boolean
local function host_trust(engine, trust)
  local entries = {}
  for _, path in ipairs(trust or {}) do
    if type(path) == "string" and path ~= "" then
      entries[#entries + 1] = { path = path, trusted = true }
    end
  end
  if #entries == 0 then
    return function()
      return false
    end
  end
  return engine.settings.trust_check({ entries = entries })
end

---The settings and the rules of the project, or the reason there are none to show.
---@param engine table
---@param opts table
---@return table|nil loaded `{ res, rules, errors, root }`
---@return string|nil reason
local function load(engine, opts)
  -- absolute: the findings are made relative to it, and the checks build their paths from it
  local root = slashed(vim.fn.fnamemodify(opts.root or ".", ":p"))
  local settings = engine.settings
  local res = settings.resolve({ project = root })
  local problem = settings.error_text(res, true)
  if problem then
    return nil, problem
  end
  if #res.rulesets == 0 then
    return nil,
      "no ruleset is configured: name one in the project's .rules.json (rulesets), or set a vault"
  end
  local rules, errors = engine.loader.load(res.rulesets)
  if #rules == 0 and #errors > 0 then
    return nil, table.concat(errors, "\n")
  end
  return { res = res, rules = rules, errors = errors, root = root }, nil
end

---@param engine table
---@param res table `Rules.Settings`
---@return string[]
local function warnings_of(engine, res)
  local out = {}
  for _, note in ipairs(res.warnings or {}) do
    out[#out + 1] = engine.settings.format(note, true)
  end
  return out
end

---A finding's file relative to the project, `/`-separated; the project itself is `.`.
---@param root string
---@param file any
---@return string
local function relative(root, file)
  local p = slashed(file or "")
  if p == root then
    return "."
  end
  local prefix = root .. "/"
  if p:sub(1, #prefix) == prefix then
    return p:sub(#prefix + 1)
  end
  return p
end

---The gates of the settings as a list sorted by name, `{ { name, families } }`: a map would encode as `[]` when
---empty and as an object otherwise (`core/json` cannot tell an empty map from an empty list), and a typed consumer
---(the desktop app) would fail on the first project without gates.
---@param gates table<string, string[]>|nil
---@return { name: string, families: string[] }[]
local function gate_list(gates)
  local out = {}
  for name, families in pairs(gates or {}) do
    if type(families) == "table" then
      out[#out + 1] = { name = name, families = families }
    end
  end
  table.sort(out, function(a, b)
    return a.name < b.name
  end)
  return out
end

---Run a route's body, turning an error raised inside `rules.nvim` (a module missing from the bundle, a bug in the
---engine) into an answer with its reason: the app shows it, where a traceback on stderr would only fail the call.
---@param body fun(...): table
---@return fun(...): table
local function guarded(body)
  return function(...)
    local ok, result = pcall(body, ...)
    if ok then
      return result
    end
    return { available = false, reason = "the rules engine failed: " .. tostring(result) }
  end
end

---`/api/rules/catalog` -- every rule of the configured rulesets, sorted by id, with what the Rules tab lists and
---groups by: file, section, family, whether there is a mechanical check and of which type, and the agent hint.
---`gates` is a list sorted by name, `{ { name, families } }`.
---@param opts table A resolved `Docmap.Opts`; `opts.rules_trust` the folders whose predicates may run.
---@return table
local function catalog(opts)
  local engine = M.engine()
  if not engine then
    return { available = false, reason = M.NO_ENGINE }
  end
  local loaded, reason = load(engine, opts)
  if not loaded then
    return { available = false, reason = reason }
  end
  local trusted = host_trust(engine, opts.rules_trust)

  local rules, counts = {}, { rules = 0, automated = 0, manual = 0, predicates = 0 }
  for _, rule in ipairs(loaded.rules) do
    local check = type(rule.check) == "table" and rule.check.type or nil
    local agent
    if type(rule.agent) == "table" then
      agent = {
        question = rule.agent.question,
        include = rule.agent.include,
        max_files = rule.agent.max_files,
      }
    end
    rules[#rules + 1] = {
      id = rule.id,
      severity = rule.severity,
      family = engine.runner.family_of(rule.id),
      title = rule.title,
      section = rule.section,
      text = rule.text or "",
      source_file = slashed(rule.source_file),
      source_line = rule.source_line,
      has_check = check ~= nil,
      check = check,
      agent = agent,
    }
    counts.rules = counts.rules + 1
    if check then
      counts.automated = counts.automated + 1
    else
      counts.manual = counts.manual + 1
    end
    if check == "lua_predicate" then
      counts.predicates = counts.predicates + 1
    end
  end
  table.sort(rules, function(a, b)
    return a.id < b.id
  end)

  local rulesets = {}
  for _, entry in ipairs(loaded.res.entries or {}) do
    rulesets[#rulesets + 1] = {
      name = entry.name,
      path = slashed(entry.path),
      origin = entry.origin,
      trusted = trusted(entry.path),
    }
  end

  return {
    available = true,
    rulesets = rulesets,
    gates = gate_list(loaded.res.gates),
    rules = rules,
    counts = counts,
    errors = loaded.errors,
    warnings = warnings_of(engine, loaded.res),
  }
end

---Read a selection: comma-separated rule ids (`DEP-01`), family prefixes (`DEP`) and gates (`gate:release`).
---@param param string|nil
---@return { ids: string[], families: string[], gates: string[] }
function M.parse_selection(param)
  local out = { ids = {}, families = {}, gates = {} }
  for item in tostring(param or ""):gmatch("[^,]+") do
    local trimmed = item:match("^%s*(.-)%s*$")
    local gate = trimmed:match("^gate:(.+)$")
    if gate then
      out.gates[#out.gates + 1] = gate
    elseif trimmed:match("^%a+%-") then
      out.ids[#out.ids + 1] = trimmed
    elseif trimmed ~= "" then
      out.families[#out.families + 1] = trimmed
    end
  end
  return out
end

---`/api/rules/run`, `param` the selection (`M.parse_selection`) -- the mechanical run of the selected rules over the
---project: one result per rule, `pass | fail | error | manual | waived`, with its findings.
---
---Never "every rule": a selection that names nothing is an answer with a reason, as `rules.engine.runner` refuses a
---whole-catalog sweep by design. A caller that wants everything names every family, which it can read off the
---catalog.
---@param opts table A resolved `Docmap.Opts`; `opts.rules_trust` the folders whose predicates may run,
---`opts.rules_today` the date waivers are judged against (`YYYY-MM-DD`, default today: for tests).
---@param param string|nil
---@return table
local function run(opts, param)
  local engine = M.engine()
  if not engine then
    return { available = false, reason = M.NO_ENGINE }
  end
  local selection = M.parse_selection(param)
  if #selection.ids + #selection.families + #selection.gates == 0 then
    return {
      available = false,
      reason = "nothing selected: name rule ids, families or gate:<name>, comma-separated",
    }
  end
  local loaded, reason = load(engine, opts)
  if not loaded then
    return { available = false, reason = reason }
  end
  local waiver_entries, waiver_err = engine.waivers.load_entries(loaded.root)
  if waiver_err then
    return { available = false, reason = waiver_err }
  end

  -- which rules are selected, and which items of the selection matched nothing
  local present_family, present_id = {}, {}
  for _, rule in ipairs(loaded.rules) do
    present_family[engine.runner.family_of(rule.id)] = true
    present_id[rule.id] = true
  end
  local unknown = {}
  local want_family, want_id = {}, {}
  for _, id in ipairs(selection.ids) do
    if present_id[id] then
      want_id[id] = true
    else
      unknown[#unknown + 1] = id
    end
  end
  local function add_family(family, label)
    if present_family[family] then
      want_family[family] = true
    else
      unknown[#unknown + 1] = label or family
    end
  end
  for _, family in ipairs(selection.families) do
    add_family(family)
  end
  for _, name in ipairs(selection.gates) do
    local families = loaded.res.gates[name]
    if type(families) ~= "table" then
      unknown[#unknown + 1] = "gate:" .. name
    else
      for _, family in ipairs(families) do
        add_family(family, ("gate:%s/%s"):format(name, family))
      end
    end
  end

  local selected, families, seen_family = {}, {}, {}
  for _, rule in ipairs(loaded.rules) do
    local family = engine.runner.family_of(rule.id)
    if want_family[family] or want_id[rule.id] then
      selected[#selected + 1] = rule
      if not seen_family[family] then
        seen_family[family] = true
        families[#families + 1] = family
      end
    end
  end
  if #selected == 0 then
    return {
      available = false,
      unknown = unknown,
      reason = "the selection matches no rule of the configured rulesets",
    }
  end
  table.sort(families)

  local trusted = host_trust(engine, opts.rules_trust)
  local run_opts = {
    today = opts.rules_today,
    lua_predicates = function(rule)
      if trusted(rule.source_file) then
        return true
      end
      return false, M.NOT_TRUSTED
    end,
  }

  local results = {}
  local counts = {}
  for _, status in ipairs(M.STATUSES) do
    counts[status] = 0
  end
  for _, family in ipairs(families) do
    for _, res in
      ipairs(engine.runner.check_family(selected, family, loaded.root, waiver_entries, run_opts))
    do
      local findings = {}
      for _, f in ipairs(res.findings or {}) do
        findings[#findings + 1] = {
          file = relative(loaded.root, f.file),
          line = f.line,
          text = f.text,
        }
      end
      local entry = {
        id = res.rule.id,
        family = family,
        severity = res.rule.severity,
        title = res.rule.title,
        status = res.status,
        findings = findings,
      }
      if res.status == "waived" then
        entry.waiver = {
          reason = res.waiver_reason,
          expires = res.waiver_expires,
          paths = res.waiver_paths,
        }
      end
      if res.partial_waiver then
        entry.partial_waiver = res.partial_waiver
      end
      if res.expired_waiver then
        entry.expired_waiver = res.expired_waiver
      end
      results[#results + 1] = entry
      counts[res.status] = (counts[res.status] or 0) + 1
    end
  end
  table.sort(results, function(a, b)
    return a.id < b.id
  end)

  return {
    available = true,
    families = families,
    unknown = unknown,
    results = results,
    counts = counts,
    errors = loaded.errors,
    warnings = warnings_of(engine, loaded.res),
  }
end

-- Exported guarded: whatever `rules.nvim` raises comes back as `{ available = false, reason }`.

---`/api/rules/catalog` (see `catalog` above).
---@type fun(opts: table): table
M.catalog = guarded(catalog)

---`/api/rules/run` (see `run` above).
---@type fun(opts: table, param: string|nil): table
M.run = guarded(run)

return M
