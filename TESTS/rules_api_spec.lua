-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil
-- TESTS/rules_api_spec.lua — `docmap.core.rules_api`, the `rules/catalog` and
-- `rules/run` routes of `core/api.lua` (step P2 of the desktop Rules tab).
--
-- Two halves. The first needs no `rules.nvim`: the selection syntax, and that a
-- host without the engine answers with a reason instead of an error. The second
-- runs the real engine over the fixture project (`TESTS/fixtures/rules_engine/
-- project`, whose `.rules.json` names `../ruleset`) when a `rules.nvim` checkout
-- is reachable -- `RULES_NVIM_DIR`, `.deps/rules.nvim` or a sibling, as
-- `scripts/ci.lua` finds it -- and skips it visibly otherwise (a developer machine
-- without a checkout; under `CI` a missing checkout raises, since the `tests` job
-- checks it out). The same routes are
-- compared between Neovim and PUC Lua by the `standalone` gate of `scripts/ci.lua`.
--
-- `$RULES_VAULT` and `$RULES_TRUST` are emptied while the engine runs, and put
-- back: a developer's vault must not become the rulesets of a fixture that has
-- none, nor a trusted folder.

return function(H)
  local ok = H.ok
  ---`H.eq` compares with `==`; a list or a record needs the deep comparison.
  local function eq(got, want, msg)
    if not vim.deep_equal(got, want) then
      error(("FAIL %s: expected %s, got %s"):format(msg, vim.inspect(want), vim.inspect(got)), 2)
    end
  end
  local rules_api = require("docmap.core.rules_api")
  local api = require("docmap.core.api")

  local repo = (debug.getinfo(1, "S").source:sub(2):match("(.*)[/\\]TESTS[/\\]")) or "."
  repo = repo:gsub("\\", "/")
  local fixtures = repo .. "/TESTS/fixtures"

  -- ------------------------------------------------------------ selection
  do
    local sel = rules_api.parse_selection(" FIX , PRD-01,gate:release,, ")
    eq(sel.families, { "FIX" }, "selection: a bare prefix is a family")
    eq(sel.ids, { "PRD-01" }, "selection: a prefix with a dash is a rule id")
    eq(sel.gates, { "release" }, "selection: gate:<name> is a gate")
    local empty = rules_api.parse_selection(nil)
    eq(#empty.ids + #empty.families + #empty.gates, 0, "selection: nil selects nothing")
  end

  -- both routes are listed, so `--capabilities` advertises them
  ok(type(api.routes["rules/catalog"]) == "function", "routes: rules/catalog is a route")
  ok(type(api.routes["rules/run"]) == "function", "routes: rules/run is a route")

  -- ----------------------------------------------- an engine without rules.nvim
  do
    local saved = rules_api.engine
    ---@diagnostic disable-next-line: duplicate-set-field
    rules_api.engine = function()
      return nil
    end
    local ok_cat, cat = pcall(rules_api.catalog, { root = repo })
    local ok_run, run = pcall(rules_api.run, { root = repo }, "FIX")
    rules_api.engine = saved
    ok(ok_cat and ok_run, "no engine: neither route raises")
    eq(cat, { available = false, reason = rules_api.NO_ENGINE }, "no engine: catalog says why")
    eq(run, { available = false, reason = rules_api.NO_ENGINE }, "no engine: run says why")
  end

  -- ------------------------------------ an engine that raises (a module missing from the bundle)
  do
    local saved = rules_api.engine
    local boom = function()
      error("module 'rules.env' not found", 0)
    end
    ---@diagnostic disable-next-line: duplicate-set-field
    rules_api.engine = function()
      return { settings = { resolve = boom }, loader = {}, runner = {}, waivers = {} }
    end
    local ok_cat, cat = pcall(rules_api.catalog, { root = repo })
    local ok_run, run = pcall(rules_api.run, { root = repo }, "FIX")
    rules_api.engine = saved
    ok(ok_cat and ok_run, "engine raises: neither route raises")
    eq(cat.available, false, "engine raises: catalog is not available")
    ok(
      tostring(cat.reason):find("rules.env", 1, true) ~= nil,
      "engine raises: catalog names the error"
    )
    eq(run.available, false, "engine raises: run is not available")
    ok(tostring(run.reason):find("rules.env", 1, true) ~= nil, "engine raises: run names the error")
  end

  -- -------------------------------------------------------- the real engine
  ---Where the real-engine half finds `rules.nvim`, as `scripts/ci.lua` finds it: `RULES_NVIM_DIR`,
  ---`<repo>/.deps/rules.nvim`, then a sibling checkout. Without one it skips on a developer machine,
  ---but raises under `CI`: the `tests` job checks the engine out, so its absence is the job being
  ---wrong, and a quiet skip there would be the silent green the `standalone` gate refuses.
  ---@param root string the repo root the candidates are relative to
  ---@param env { RULES_NVIM_DIR: string?, CI: string? }
  ---@return string? dir
  local function locate_rules(root, env)
    for _, d in ipairs({
      env.RULES_NVIM_DIR or "",
      root .. "/.deps/rules.nvim",
      vim.fs.dirname(root) .. "/rules.nvim",
    }) do
      if d ~= "" and vim.fn.filereadable(d .. "/lua/rules/engine/runner.lua") == 1 then
        return d
      end
    end
    if env.CI and env.CI ~= "" then
      error("rules.nvim not found at .deps/rules.nvim; CI's tests job must check it out", 0)
    end
    return nil
  end

  do
    local empty = vim.fn.tempname()
    vim.fn.mkdir(empty .. "/repo", "p")
    local root = empty .. "/repo"
    eq(locate_rules(root, {}), nil, "locate_rules: no checkout and no CI is a skip")
    local raised, msg = pcall(locate_rules, root, { CI = "true" })
    eq(raised, false, "locate_rules: no checkout under CI raises instead of skipping")
    ok(
      tostring(msg):find(".deps/rules.nvim", 1, true) ~= nil,
      "locate_rules: the CI error names the path"
    )
    local fake = empty .. "/fake-rules"
    vim.fn.mkdir(fake .. "/lua/rules/engine", "p")
    H.write(fake .. "/lua/rules/engine/runner.lua", { "return {}" })
    eq(
      locate_rules(root, { RULES_NVIM_DIR = fake, CI = "true" }),
      fake,
      "locate_rules: RULES_NVIM_DIR wins"
    )
    vim.fn.delete(empty, "rf")
  end

  local rules_dir = locate_rules(repo, { RULES_NVIM_DIR = vim.env.RULES_NVIM_DIR, CI = vim.env.CI })
  if not rules_dir then
    -- Visible, unlike a bare return: the runner's `ok` line alone reads the same for a skipped half.
    io.stdout:write(
      "skip  rules_api_spec.lua: real-engine half (rules.nvim not found; set RULES_NVIM_DIR)\n"
    )
    return
  end

  -- What this block changes, put back however it ends.
  local saved_path = package.path
  local saved_loaded = {}
  for name, mod in pairs(package.loaded) do
    if name:match("^rules%.") or name == "rules" then
      saved_loaded[name] = mod
    end
  end
  local saved_vault, saved_trust = vim.env.RULES_VAULT, vim.env.RULES_TRUST
  local function restore()
    package.path = saved_path
    for name in pairs(package.loaded) do
      if (name:match("^rules%.") or name == "rules") and saved_loaded[name] == nil then
        package.loaded[name] = nil
      end
    end
    for name, mod in pairs(saved_loaded) do
      package.loaded[name] = mod
    end
    vim.env.RULES_VAULT, vim.env.RULES_TRUST = saved_vault, saved_trust
  end

  local ok_all, err = pcall(function()
    package.path = rules_dir .. "/lua/?.lua;" .. rules_dir .. "/lua/?/init.lua;" .. package.path
    vim.env.RULES_VAULT, vim.env.RULES_TRUST = nil, nil
    ok(rules_api.engine() ~= nil, "engine: rules.nvim loads from " .. rules_dir)

    local project = fixtures .. "/rules_engine/project"
    local ruleset = fixtures .. "/rules_engine/ruleset"

    -- catalog
    local cat = api.answer("rules/catalog", { root = project })
    eq(cat.available, true, "catalog: available for a project whose .rules.json names a ruleset")
    eq(
      cat.counts,
      { rules = 12, automated = 10, manual = 2, predicates = 5 },
      "catalog: 12 rules, 10 with a check (5 predicates), 2 manual"
    )
    eq(#cat.errors, 3, "catalog: the fixture's three broken blocks are reported, not dropped")
    local by_id = {}
    for _, rule in ipairs(cat.rules) do
      by_id[rule.id] = rule
    end
    local fix01 = by_id["FIX-01"]
    eq(fix01.check, "grep", "catalog: the check type")
    eq(fix01.has_check, true, "catalog: has_check")
    eq(fix01.family, "FIX", "catalog: the family")
    eq(fix01.section, "Mechanical checks", "catalog: the section")
    eq(fix01.source_line, 11, "catalog: the source line")
    eq(fix01.source_file, ruleset .. "/RULES.md", "catalog: the source file, with `..` folded")
    eq(fix01.agent.question, "Is every flatten call guarded?", "catalog: the agent hint")
    eq(by_id["FIX-06"].has_check, false, "catalog: a rule without a check is manual")
    eq(by_id["FIX-06"].check, nil, "catalog: and names no check type")
    eq(cat.gates, {
      { name = "release", families = { "FIX", "PRD" } },
      { name = "typo", families = { "NOPE" } },
    }, "catalog: the gates of .rules.json, a list sorted by name")
    eq(cat.rulesets[1].trusted, false, "catalog: a ruleset the host did not name is not trusted")
    eq(cat.rulesets[1].origin, "project", "catalog: it came from the project .rules.json")

    -- run, predicates not trusted
    local run =
      api.answer("rules/run", { root = project, rules_today = "2026-01-01" }, "gate:release,ZZZ")
    eq(run.available, true, "run: available")
    local status = {}
    for _, r in ipairs(run.results) do
      status[r.id] = r.status
    end
    eq(status["FIX-04"], "waived", "run: the project's .rules-waivers.json waives FIX-04")
    eq(status["FIX-01"], "fail", "run: a grep with a hit fails")
    eq(status["FIX-06"], "manual", "run: a rule without a check is manual")
    for i = 1, 5 do
      local id = ("PRD-%02d"):format(i)
      eq(status[id], "error", "run: untrusted predicate " .. id .. " is an error")
    end
    local prd01
    for _, r in ipairs(run.results) do
      if r.id == "PRD-01" then
        prd01 = r
      end
    end
    eq(prd01.findings[1].text, rules_api.NOT_TRUSTED, "run: and says the predicate was not trusted")
    eq(run.unknown, { "ZZZ" }, "run: a selected family that has no rule is named")
    eq(run.counts.waived, 1, "run: counts per status")

    -- run, predicates trusted by the host, per rule
    local trusted =
      api.answer("rules/run", { root = project, rules_trust = { ruleset } }, "PRD-01,PRD-02")
    local t_status = {}
    for _, r in ipairs(trusted.results) do
      t_status[r.id] = r.status
    end
    eq(t_status, { ["PRD-01"] = "pass", ["PRD-02"] = "fail" }, "run: a trusted predicate runs")
    local trusted_elsewhere = api.answer(
      "rules/run",
      { root = project, rules_trust = { fixtures .. "/rules_api" } },
      "PRD-01"
    )
    eq(
      trusted_elsewhere.results[1].status,
      "error",
      "run: trusting another folder trusts nothing here"
    )

    -- a project without gates: still a list, so it encodes as `[]` like a full one encodes as a list
    local nogates = api.answer("rules/catalog", { root = fixtures .. "/rules_api/nogates" })
    eq(nogates.available, true, "no gates: available")
    eq(nogates.gates, {}, "no gates: an empty list")
    ok(
      require("docmap.core.json").encode(cat):find('"gates":[{', 1, true) ~= nil,
      "gates: a project with gates encodes them as a JSON list"
    )

    -- empty states
    local bare = api.answer("rules/catalog", { root = fixtures .. "/rules_api/bare" })
    eq(bare.available, false, "no .rules.json: not available")
    ok(
      tostring(bare.reason):match("^no ruleset is configured") ~= nil,
      "no .rules.json: says nothing is configured"
    )
    local missing = api.answer("rules/catalog", { root = fixtures .. "/rules_api/missing" })
    eq(missing.available, false, "missing ruleset: not available")
    ok(
      tostring(missing.reason):find("no-such-ruleset", 1, true) ~= nil,
      "missing ruleset: names it"
    )
    local none = api.answer("rules/run", { root = project }, nil)
    eq(none.available, false, "run: nothing selected is not a whole-catalog sweep")
    local nothing = api.answer("rules/run", { root = project }, "gate:typo")
    eq(nothing.available, false, "run: a gate whose families have no rule matches nothing")
    eq(nothing.unknown, { "gate:typo/NOPE" }, "run: and names what matched nothing")
  end)
  restore()
  if not ok_all then
    error(err, 0)
  end
end
