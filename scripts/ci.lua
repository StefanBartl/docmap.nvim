-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil
-- scripts/ci.lua — the `standalone` gate, as Lua rather than as shell.
--
--   nvim --headless -l scripts/ci.lua standalone
--
-- The pipeline of this repository (stylua, luacheck, suite, map, standalone) is the `ci` section of
-- `.testing.lua` and runs with `testing ci` (testing.nvim, docs/CI.md); `scripts/ci.sh` is a shim for it, and
-- `.github/workflows/ci.yml` calls the shim, so the CI jobs keep their independent red/green marks and their
-- parallelism while each command exists once. This file holds the one gate that has no preset: it needs a PUC Lua
-- with `lfs` and `dkjson`, skips (and counts the skip) without one, and checks the standalone build.
--
-- Why Lua and not shell: the plugin is cross-platform by construction — no `io.popen`, no `os.execute`,
-- `vim.system`/`vim.uv`/`vim.fs` throughout. Neovim is already a hard requirement here; using it as the script host
-- means a Windows contributor runs the same check without installing Git Bash.

local root = vim.fn.getcwd():gsub("\\", "/"):gsub("/+$", "")

-- ANSI only when the output is going somewhere that renders it. A CI log
-- capturing stdout is fine with escapes; a Windows console pipe is not always.
local color = vim.env.NO_COLOR == nil
local function paint(code, s)
  return color and ("\27[" .. code .. "m" .. s .. "\27[0m") or s
end

local function say(s)
  io.stdout:write(s, "\n")
end

local function step(name)
  say("\n" .. paint("1", "== " .. name))
end

---Gates that ran but decided they could not.
---
---**The summary used to say "All 5 gates passed" when one of them had
---shrugged**, which is the whole defect this list exists for: on a machine
---without PUC Lua the `standalone` gate prints *skipped* and green still
---read as five-for-five. Three real defects reached a release behind that
---sentence, so the count is now honest about what actually ran.
---@type string[]
local skipped = {}

---Record a gate that could not run, and say why.
---
---Not a failure: a machine with Neovim and nothing else is the common local
---case, and failing there would make `scripts/ci.sh` unusable for exactly
---the people it exists to serve — which is how a gate gets switched off.
---What changes is that the skip is now *counted*, and that the reason is
---specific enough to act on.
---@param name string
---@param why string
local function skip(name, why)
  skipped[#skipped + 1] = name
  say("  " .. paint("33", "skipped: " .. why))
end

local function fail(msg)
  io.stderr:write(paint("31", msg) .. "\n")
  vim.cmd("cq 1")
end

---Run a command, streaming nothing but reporting everything.
---
---`vim.system(...):wait()` rather than `os.execute`: no shell, so no quoting
---rules that differ between cmd.exe and sh, which is the whole point of this
---file existing.
---@param cmd string[]
---@param label string
local function run(cmd, label)
  local proc = vim.system(cmd, { cwd = root, text = true }):wait()
  if proc.stdout and proc.stdout ~= "" then
    io.stdout:write(proc.stdout)
  end
  if proc.stderr and proc.stderr ~= "" then
    io.stderr:write(proc.stderr)
  end
  if proc.code ~= 0 then
    fail(("%s failed (exit %d)."):format(label, proc.code))
  end
end

local GATES = {}

---A PUC Lua that can actually run the standalone build, or nil.
---
---`lua5.4` before `lua` because Debian-family images ship both and the bare
---name is often 5.1; this gate wants the *other* Lua from the one Neovim
---embeds, which is the entire point of it existing.
---
---**Being on `$PATH` is not the question; being able to `require` the two
---rocks the build needs is.** A machine can easily have more than one PUC
---Lua — this was found on one with 5.1 first on `$PATH` and `lfs`/`dkjson`
---installed for 5.4 — and picking by name alone hands the gate an
---interpreter that dies at its first `require`. That failure reads as a
---broken build rather than a missing dependency, and it makes the gate red
---before anyone has touched anything, which `GATES.standalone`'s own
---comment gives as the reason such a gate gets switched off.
---
---So each candidate is probed rather than assumed, and a machine with no
---usable interpreter takes the stated skip below instead of failing.
---@return string? exe The first interpreter that loaded both rocks.
---@return string[]? found Every PUC Lua on PATH, returned only when none of
---them worked -- "none installed" and "one installed that cannot load the
---rocks" are different problems, and the caller reports which it is.
local function puc_lua()
  -- Which interpreters exist at all, kept apart from which of them work.
  -- "no PUC Lua here" and "a PUC Lua that cannot load the rocks" are
  -- different problems with different fixes, and one message for both sends
  -- half its readers looking for the wrong thing. Reported by the caller.
  local found = {}
  for _, exe in ipairs({ "lua5.4", "lua5.3", "lua" }) do
    if vim.fn.executable(exe) == 1 then
      found[#found + 1] = exe
      local probe = vim.system({ exe, "-e", "require('lfs') require('dkjson')" }):wait()
      if probe.code == 0 then
        return exe
      end
    end
  end
  return nil, found
end

---Which of the two rocks `exe` cannot load, in order.
---
---Probed one at a time rather than reusing the combined check above: the
---point of this is the *name*, and `require('lfs') require('dkjson')`
---failing tells you only that one of them did.
---@param exe string
---@return string[]
local function missing_rocks(exe)
  local out = {}
  for _, rock in ipairs({ "lfs", "dkjson" }) do
    local probe = vim.system({ exe, "-e", ("require('%s')"):format(rock) }):wait()
    if probe.code ~= 0 then
      out[#out + 1] = rock
    end
  end
  return out
end

--- The standalone build, run under a Lua that is **not** LuaJIT.
---
--- This gate exists because of a defect the other four could not see. The
--- artifact is byte-compared by `map --check` and by a pre-commit hook, and
--- two places rendered numbers host-dependently: LuaJIT writes an integral
--- float as `100`, PUC Lua 5.3+ as `100.0`. Every gate above runs inside
--- Neovim, so all four were green on a tree whose map a second Lua would have
--- called stale. Fixed in `core/json.lua` and `core/quicks.lua`; this is what
--- keeps it fixed.
---
--- Deliberately the **parser-less** build, needing only `lfs` and `dkjson`
--- rather than a `lua-tree-sitter` rock and a compiled grammar. The full
--- parity comparison (byte-identical to a Neovim run) needs both and is a
--- local gate instead. Its
--- published rock has two packaging defects, and a gate that is red before
--- anyone touches anything gets switched off the same day, which is exactly
--- the advice `docs/reuse.md` gives about extra checks.
---
--- Writes to a temporary directory, never `docs/map`: a gate that rewrites
--- the artifact it is checking is not a gate.
function GATES.standalone()
  step("standalone (non-LuaJIT host)")
  local lua, found = puc_lua()
  if not lua then
    -- Two different situations, and until now they shared one sentence.
    if #found == 0 then
      skip("standalone", "no PUC Lua on PATH — this gate is about the *other* Lua, not Neovim's")
    else
      -- Somebody has a PUC Lua. That is a machine one `luarocks install`
      -- away from running this gate, so the message names the rock instead
      -- of leaving them to work it out.
      local exe = found[1]
      local rocks = missing_rocks(exe)
      skip(
        "standalone",
        ("%s is on PATH but cannot require %s — `luarocks install %s`"):format(
          exe,
          table.concat(rocks, " or "),
          table.concat(rocks, " ")
        )
      )
    end
    return
  end

  -- Repo-relative, because `opts.out_dir` is repo-relative everywhere else
  -- (`docs/map` is the default) and an absolute path would be joined onto the
  -- root rather than replacing it. `.deps/` is already gitignored and already
  -- where the headless runners put throwaway checkouts, so nothing here can
  -- reach the working tree or the scanned corpus.
  local out_rel = ".deps/standalone-map"
  local out_abs = root .. "/" .. out_rel
  vim.fn.delete(out_abs, "rf")
  run({
    lua,
    "standalone/docmap.lua",
    root,
    "--source=lua/docmap",
    "--out-dir=" .. out_rel,
  }, "standalone/docmap.lua")

  local path = out_abs .. "/module_map.json"
  local fd = io.open(path, "rb")
  if not fd then
    fail("standalone build wrote no module_map.json to " .. out_rel)
    return
  end
  local body = fd:read("*a")
  fd:close()

  -- The two shapes the bug produced, asserted directly rather than by
  -- comparing against a reference file: a reference would have to be
  -- regenerated with every real change, and would then stop being evidence.
  -- `%f[%D]` so a genuine fraction like `45.05` is not mistaken for one.
  local bad_value = body:match('"value":%-?%d+%.0%f[%D]')
  local bad_detail = body:match('"detail":"[^"]-%d%.0%f[%D][^"]-"')
  if bad_value or bad_detail then
    fail(
      "standalone artifact renders numbers host-dependently — the defect "
        .. "core/json.lua and core/quicks.lua exist to prevent:\n    "
        .. tostring(bad_value or bad_detail)
    )
    return
  end

  say("  ok: no host-dependent number formatting in the standalone artifact")

  -- ------------------------------------------------------------------
  -- Links, on the interpreter and the `lfs` this build actually ships.
  --
  -- `TESTS/shim_links_spec.lua` compares the shim with the editor on the
  -- host's own file system, but through an `lfs` adapted onto `vim.uv`. What
  -- only this gate has is the real rock -- and on Windows the real
  -- `cmd.exe` -- under the real PUC Lua: the interpreter `docmap-desktop`
  -- runs. Two checks, the two things a repository can do with a link:
  --   * make `docs/map` one, and the engine must refuse to write and leave
  --     the folder it points at exactly as it was;
  --   * put one in the source tree that leaves the project, and the engine
  --     must not read what is behind it, and must say it did not.
  local links_dir = root .. "/.deps/standalone-links"
  vim.fn.delete(links_dir, "rf")
  vim.fn.mkdir(links_dir .. "/repo/lua/t", "p")
  vim.fn.mkdir(links_dir .. "/repo/docs", "p")
  vim.fn.mkdir(links_dir .. "/outside/map", "p")
  vim.fn.mkdir(links_dir .. "/outside/lua", "p")
  vim.fn.writefile(
    { "---@module 't'", "--- T-SUMMARY.", "local M = {}", "return M" },
    links_dir .. "/repo/lua/t/init.lua"
  )
  vim.fn.writefile({ "VICTIM" }, links_dir .. "/outside/map/index.html")
  vim.fn.writefile({ "VICTIM" }, links_dir .. "/outside/map/module_map.json")
  vim.fn.writefile({ "VICTIM" }, links_dir .. "/outside/map/overview.md")
  vim.fn.writefile(
    { "---@module 'leaked'", "--- OUTSIDE-SUMMARY.", "local M = {}", "return M" },
    links_dir .. "/outside/lua/init.lua"
  )

  ---A directory link: a junction on Windows (needs no privilege), a symlink
  ---elsewhere.
  ---@param target string
  ---@param link string
  ---@return boolean
  local function make_dir_link(target, link)
    if vim.fn.has("win32") == 1 then
      local made = vim
        .system({
          "cmd",
          "/C",
          "mklink",
          "/J",
          (link:gsub("/", "\\")),
          (target:gsub("/", "\\")),
        }, { text = true })
        :wait()
      return made.code == 0
    end
    return vim.uv.fs_symlink(target, link, { dir = true }) == true
  end

  if not make_dir_link(links_dir .. "/outside/map", links_dir .. "/repo/docs/map") then
    fail("standalone links check: could not make a directory link in " .. links_dir)
    return
  end
  local refused = vim
    .system({ lua, "standalone/docmap.lua", links_dir .. "/repo", "--source=lua/t" }, {
      cwd = root,
      text = true,
    })
    :wait()
  if refused.code == 0 then
    fail("standalone build wrote the map through docs/map, a link out of the project")
    return
  end
  if not (refused.stderr or ""):find("refusing to write the map", 1, true) then
    fail(
      "standalone build failed on a linked docs/map, but not with the refusal:\n    "
        .. (refused.stderr or ""):sub(1, 600)
    )
    return
  end
  -- The refusal is one line and exit 2, as `--check`'s are; it used to escape
  -- as a Lua error, printed with a stack traceback, exit 1.
  if refused.code ~= 2 or (refused.stderr or ""):find("traceback", 1, true) then
    fail(
      ("standalone build refused a linked docs/map with exit %d, not as one line with exit 2:\n    %s"):format(
        refused.code,
        (refused.stderr or ""):sub(1, 600)
      )
    )
    return
  end
  for _, name in ipairs({ "index.html", "module_map.json", "overview.md" }) do
    local victim = table.concat(vim.fn.readfile(links_dir .. "/outside/map/" .. name), "\n")
    if victim ~= "VICTIM" then
      fail("standalone build overwrote outside/map/" .. name .. " through a link")
      return
    end
  end
  say("  ok: a linked docs/map is refused, and what it points at is untouched")

  vim.fn.delete(links_dir .. "/repo/docs/map")
  if not make_dir_link(links_dir .. "/outside/lua", links_dir .. "/repo/lua/t/leaving") then
    fail("standalone links check: could not make a directory link in the source tree")
    return
  end
  local walked = vim
    .system({
      lua,
      "standalone/docmap.lua",
      links_dir .. "/repo",
      "--source=lua/t",
      "--out-dir=out",
    }, { cwd = root, text = true })
    :wait()
  if walked.code ~= 0 then
    fail(
      "standalone build failed on a source tree with a link out of the project:\n    "
        .. (walked.stderr or ""):sub(1, 600)
    )
    return
  end
  local walked_map = table.concat(vim.fn.readfile(links_dir .. "/repo/out/module_map.json"), "\n")
  if walked_map:find("OUTSIDE-SUMMARY", 1, true) or walked_map:find("leaked", 1, true) then
    fail("standalone build read a folder behind a link that leaves the project")
    return
  end
  if not (walked.stderr or ""):find("not followed", 1, true) then
    fail(
      "standalone build did not say it left a link alone:\n    "
        .. (walked.stderr or ""):sub(1, 600)
    )
    return
  end
  say("  ok: a link out of the source tree is not read, and the run says so")
  vim.fn.delete(links_dir, "rf")

  -- ------------------------------------------------------------------
  -- The behavioural differential, replayed on the other interpreter.
  --
  -- `TESTS/shim_behavior_spec.lua` already compared most of this corpus
  -- against the real `vim.*` in the always-green `tests` gate — deliberately,
  -- because this gate skips on most machines. What it could not answer is
  -- what needs the two rocks and the other Lua: `vim.json.decode` is still
  -- dkjson's, `lfs` is real here and adapted there, and PUC 5.4 is not
  -- LuaJIT.
  --
  -- The expectations are written from the `vim` of *this* Neovim, seconds
  -- before the replay, rather than read from a committed golden file: a
  -- golden would drift with the next Neovim release and would then be
  -- evidence of nothing.
  --
  -- Both steps are wrapped: a corpus that cannot be loaded, and a case naming
  -- something this Neovim does not have, are both *this gate's* red — with a
  -- sentence saying which. Unwrapped they surface as a Lua traceback out of a
  -- file nobody was editing, which reads like the build is broken.
  local loaded, cases = pcall(dofile, root .. "/TESTS/fixtures/shim_behavior_cases.lua")
  if not loaded then
    fail("cannot load the shim behaviour corpus: " .. tostring(cases))
    return
  end
  vim.fn.mkdir(root .. "/.deps", "p")
  local expectations = root .. "/.deps/shim-expectations.txt"
  local ok_write, written =
    pcall(cases.write_expectations, vim, root .. "/TESTS/fixtures/shim_fs", expectations)
  if not ok_write then
    fail("shim behaviour corpus is broken: " .. tostring(written))
    return
  end
  say(("  ok: wrote %d expectations from this Neovim"):format(written))
  run({ lua, "standalone/selfcheck_behavior.lua", root, expectations }, "standalone shim behaviour")

  -- ------------------------------------------------------------------
  -- The rules.nvim engine on both hosts.
  --
  -- The differential above proves each shim function against the editor. It
  -- cannot prove the *engine* on top of them: every function can be right and
  -- the engine still answer differently, because of an ordering, a separator,
  -- a value one of them returns where the other returns nothing. So the same
  -- script runs the same ruleset over the same project once in this Neovim and
  -- once under PUC Lua with the shim, and the two outputs must be identical.
  --
  -- Identical is necessary and not sufficient — two hosts can fail the same
  -- way — so each is also held to what the fixture *means*, written by hand in
  -- `expected_*.txt`: which rule passes, which fails, which is judgement, and
  -- (second run, predicates off) that every predicate reports `error` rather
  -- than quietly vanishing.
  local rules_dir
  local rules_candidates = {}
  if vim.env.RULES_NVIM_DIR and vim.env.RULES_NVIM_DIR ~= "" then
    rules_candidates[#rules_candidates + 1] = vim.env.RULES_NVIM_DIR
  end
  rules_candidates[#rules_candidates + 1] = root .. "/.deps/rules.nvim"
  rules_candidates[#rules_candidates + 1] = vim.fs.dirname(root) .. "/rules.nvim"
  for _, d in ipairs(rules_candidates) do
    if vim.fn.filereadable(d .. "/lua/rules/engine/runner.lua") == 1 then
      rules_dir = d
      break
    end
  end
  if not rules_dir then
    -- On a developer's machine a missing sibling checkout is the normal state
    -- and skipping is honest. In CI the checkout is a step of the job, so its
    -- absence is the job being wrong, and a skip there would be the silent
    -- green this whole gate exists to prevent. (rules.nvim is public, so the
    -- job checks it out with the default token; no opt-out remains.)
    if vim.env.CI then
      fail("rules.nvim was not checked out to .deps/rules.nvim, and CI must not skip this step.")
    else
      skip(
        "rules engine and rules agent pipeline under the shim",
        "rules.nvim not found — set RULES_NVIM_DIR, clone it to .deps/rules.nvim, or put it beside this repo"
      )
    end
    return
  end

  local fixture_dir = root .. "/TESTS/fixtures/rules_engine"
  ---@param host string[]
  ---@param extra string[]
  ---@return string stdout
  local function engine_output(host, extra)
    local cmd = vim.list_extend(vim.deepcopy(host), {
      "standalone/rules_results.lua",
      fixture_dir .. "/ruleset",
      fixture_dir .. "/project",
    })
    vim.list_extend(cmd, extra)
    local proc = vim.system(cmd, { cwd = root, text = true }):wait()
    if proc.code ~= 0 then
      fail(
        ("rules engine run failed (exit %d): %s\n%s"):format(
          proc.code,
          table.concat(cmd, " "),
          proc.stderr or ""
        )
      )
    end
    local out = (proc.stdout or ""):gsub("\r\n", "\n")
    return out
  end

  ---The part of each line the fixture's author wrote an expectation for.
  ---@param out string
  ---@return string
  local function meaning(out)
    local lines = {}
    for line in out:gmatch("[^\n]+") do
      local id, status = line:match("^([^\t]+)\t([^\t]+)")
      lines[#lines + 1] = id == "PARSE" and line or (id .. "\t" .. status)
    end
    return table.concat(lines, "\n") .. "\n"
  end

  for _, mode in ipairs({
    { label = "predicates trusted", extra = {}, expected = "expected_trusted.txt" },
    {
      label = "predicates off",
      extra = { "--no-predicates" },
      expected = "expected_untrusted.txt",
    },
  }) do
    local in_nvim =
      engine_output({ vim.v.progpath, "-n", "--headless", "-u", "NONE", "-l" }, mode.extra)
    local under_shim = engine_output({ lua }, mode.extra)
    if in_nvim ~= under_shim then
      local a, b =
        vim.split(in_nvim, "\n", { plain = true }), vim.split(under_shim, "\n", { plain = true })
      local shown = {}
      for i = 1, math.max(#a, #b) do
        if a[i] ~= b[i] then
          shown[#shown + 1] = ("    neovim: %s\n    shim:   %s"):format(
            a[i] or "<none>",
            b[i] or "<none>"
          )
          if #shown == 5 then
            break
          end
        end
      end
      fail(
        ("rules engine differs between Neovim and the shim (%s):\n%s"):format(
          mode.label,
          table.concat(shown, "\n")
        )
      )
      return
    end
    local want = table.concat(vim.fn.readfile(fixture_dir .. "/" .. mode.expected), "\n") .. "\n"
    if meaning(in_nvim) ~= want then
      fail(
        ("rules engine does not say what %s says it should (%s):\n--- got\n%s--- want\n%s"):format(
          mode.expected,
          mode.label,
          meaning(in_nvim),
          want
        )
      )
      return
    end
    say(("  ok: rules engine, %s: identical on both hosts and as expected"):format(mode.label))
  end

  -- ------------------------------------------------------------------
  -- The `rules/*` routes of `core/api.lua` (`core/rules_api.lua`), the entry point the desktop app's Rules tab uses:
  -- the real binary's entry (`standalone/docmap.lua --api=...`) under PUC Lua against `standalone/rules_api.lua`
  -- under this Neovim, over the fixture project and its `.rules.json`. The answers must be the same, except for the
  -- wording of a Lua runtime error inside a parse error (LuaJIT and PUC phrase it differently): parse errors are
  -- compared by count. Then each answer is held to what the fixture means, as above.
  --
  -- `RULES_VAULT`/`RULES_TRUST` are emptied for both: a developer's vault must not become the rulesets of a fixture
  -- that has none (`bare`), nor a trusted folder.
  local rules_env = { RULES_VAULT = "", RULES_TRUST = "", RULES_NVIM_DIR = rules_dir }
  local api_project = fixture_dir .. "/project"
  local api_ruleset = fixture_dir .. "/ruleset"
  local api_fixtures = root .. "/TESTS/fixtures/rules_api"
  ---@param cmd string[]
  ---@return table|nil
  local function api_answer(cmd)
    local proc = vim.system(cmd, { cwd = root, text = true, env = rules_env }):wait()
    if proc.code ~= 0 then
      fail(
        ("rules route failed (exit %d): %s\n%s"):format(
          proc.code,
          table.concat(cmd, " "),
          proc.stderr or ""
        )
      )
      return nil
    end
    local ok, decoded = pcall(vim.json.decode, proc.stdout or "")
    if not ok then
      fail("rules route printed no JSON: " .. table.concat(cmd, " ") .. "\n" .. (proc.stdout or ""))
      return nil
    end
    if type(decoded.errors) == "table" then
      decoded.errors = #decoded.errors
    end
    return decoded
  end
  ---@param result table
  ---@return table<string, string>
  local function statuses(result)
    local out = {}
    for _, r in ipairs(result.results or {}) do
      out[r.id] = r.status
    end
    return out
  end
  local NOT_TRUSTED =
    "predicate not trusted: the host has not trusted this ruleset (--trust=<folder>)"
  local api_cases = {
    {
      label = "catalog",
      project = api_project,
      args = { "rules/catalog" },
      check = function(r)
        local fix01
        for _, rule in ipairs(r.rules or {}) do
          if rule.id == "FIX-01" then
            fix01 = rule
          end
        end
        return r.available == true
          and vim.deep_equal(r.counts, { rules = 12, automated = 10, manual = 2, predicates = 5 })
          and r.errors == 3
          and fix01 ~= nil
          and fix01.check == "grep"
          and fix01.section == "Mechanical checks"
          and fix01.source_line == 11
          and fix01.source_file:match("/rules_engine/ruleset/RULES%.md$") ~= nil
          and fix01.agent.question == "Is every flatten call guarded?"
          and vim.deep_equal(r.gates[1], { name = "release", families = { "FIX", "PRD" } })
      end,
    },
    {
      label = "run, predicates not trusted",
      project = api_project,
      args = { "rules/run", "--select=gate:release,FIX-06,ZZZ" },
      check = function(r)
        local untrusted = 0
        for _, res in ipairs(r.results or {}) do
          if res.status == "error" and res.findings[1] and res.findings[1].text == NOT_TRUSTED then
            untrusted = untrusted + 1
          end
        end
        return r.available == true
          and vim.deep_equal(statuses(r), {
            ["FIX-01"] = "fail",
            ["FIX-02"] = "pass",
            ["FIX-03"] = "pass",
            ["FIX-04"] = "waived",
            ["FIX-05"] = "fail",
            ["FIX-06"] = "manual",
            ["PRD-01"] = "error",
            ["PRD-02"] = "error",
            ["PRD-03"] = "error",
            ["PRD-04"] = "error",
            ["PRD-05"] = "error",
          })
          and untrusted == 5
          and vim.deep_equal(r.unknown, { "ZZZ" })
      end,
    },
    {
      label = "run, predicates trusted by the host",
      project = api_project,
      args = { "rules/run", "--select=PRD", "--trust=" .. api_ruleset },
      check = function(r)
        return r.available == true
          and vim.deep_equal(statuses(r), {
            ["PRD-01"] = "pass",
            ["PRD-02"] = "fail",
            ["PRD-03"] = "pass",
            ["PRD-04"] = "pass",
            ["PRD-05"] = "pass",
          })
      end,
    },
    {
      label = "a project without gates",
      project = api_fixtures .. "/nogates",
      args = { "rules/catalog" },
      check = function(r)
        return r.available == true and vim.deep_equal(r.gates, {})
      end,
    },
    {
      label = "a project without .rules.json",
      project = api_fixtures .. "/bare",
      args = { "rules/catalog" },
      check = function(r)
        return r.available == false and tostring(r.reason):match("^no ruleset is configured") ~= nil
      end,
    },
    {
      label = "a .rules.json naming a missing ruleset",
      project = api_fixtures .. "/missing",
      args = { "rules/run", "--select=FIX" },
      check = function(r)
        return r.available == false and tostring(r.reason):find("no-such-ruleset", 1, true) ~= nil
      end,
    },
  }
  for _, case in ipairs(api_cases) do
    local route, extra = case.args[1], vim.list_slice(case.args, 2)
    local in_nvim = api_answer(vim.list_extend({
      vim.v.progpath,
      "-n",
      "--headless",
      "-u",
      "NONE",
      "-l",
      "standalone/rules_api.lua",
      case.project,
      route,
    }, extra))
    local in_binary = api_answer(
      vim.list_extend({ lua, "standalone/docmap.lua", case.project, "--api=" .. route }, extra)
    )
    if not in_nvim or not in_binary then
      return
    end
    if not vim.deep_equal(in_nvim, in_binary) then
      fail(
        ("rules route differs between Neovim and the standalone build (%s):\n--- neovim\n%s\n--- standalone\n%s"):format(
          case.label,
          vim.inspect(in_nvim),
          vim.inspect(in_binary)
        )
      )
      return
    end
    if not case.check(in_nvim) then
      fail(
        ("rules route does not say what the fixture means (%s):\n%s"):format(
          case.label,
          vim.inspect(in_nvim)
        )
      )
      return
    end
    say(("  ok: rules route, %s: identical on both hosts and as expected"):format(case.label))
  end

  -- ------------------------------------------------------------------
  -- The agent pipeline of rules.nvim (planner, request, check of an answer,
  -- verdict reading) on both hosts, over a small fixture project: the same
  -- script once here and once under PUC Lua with the shim, the outputs
  -- identical. It found `unpack` (PUC has only `table.unpack`), a JSON null
  -- that is a table under the shim and a userdata in the editor, and a file
  -- read that needs libuv; none of it shows up in either host alone.
  local agent_project = root .. "/TESTS/fixtures/rules_agent/project"
  ---@param host string[]
  ---@return string stdout
  local function agent_output(host)
    local cmd =
      vim.list_extend(vim.deepcopy(host), { "standalone/rules_agent_smoke.lua", agent_project })
    local proc = vim.system(cmd, { cwd = root, text = true }):wait()
    if proc.code ~= 0 then
      fail(
        ("rules agent run failed (exit %d): %s\n%s"):format(
          proc.code,
          table.concat(cmd, " "),
          proc.stderr or ""
        )
      )
    end
    local out = (proc.stdout or ""):gsub("\r\n", "\n")
    return out
  end
  local agent_nvim = agent_output({ vim.v.progpath, "-n", "--headless", "-u", "NONE", "-l" })
  local agent_shim = agent_output({ lua })
  if agent_nvim ~= agent_shim then
    local a_lines, b_lines =
      vim.split(agent_nvim, "\n", { plain = true }), vim.split(agent_shim, "\n", { plain = true })
    local shown = {}
    for i = 1, math.max(#a_lines, #b_lines) do
      if a_lines[i] ~= b_lines[i] then
        shown[#shown + 1] = ("    neovim: %s\n    shim:   %s"):format(
          a_lines[i] or "<none>",
          b_lines[i] or "<none>"
        )
        if #shown == 5 then
          break
        end
      end
    end
    fail("rules agent pipeline differs between Neovim and the shim:\n" .. table.concat(shown, "\n"))
    return
  end
  -- Identical is necessary and not sufficient: two hosts can break the same way. The fixture's author wrote down
  -- what the pipeline must say (`expected.txt`: which files are denied, which answers hold, which do not).
  local want = table.concat(
    vim.fn.readfile(root .. "/TESTS/fixtures/rules_agent/expected.txt"),
    "\n"
  ) .. "\n"
  if agent_nvim ~= want then
    fail(
      ("rules agent pipeline does not say what expected.txt says it should:\n--- got\n%s--- want\n%s"):format(
        agent_nvim,
        want
      )
    )
    return
  end
  say("  ok: rules agent pipeline: identical on both hosts and as expected")
end

-- The order is not cosmetic. A formatting failure is the cheapest one to find
-- and the least interesting; a stale map is the most likely to be a real
-- finding rather than a slip. Failing fast on the cheap one first means the
-- expensive checks only ever run on code that is already tidy.
local ORDER = { "standalone" }

---The exit code that says "a gate skipped itself" (`skip_exit` of the step in `.testing.lua`): `testing ci` then marks
---the step `skipped` and the run partial, so a run in which a gate checked nothing is never a green proof.
local SKIP_EXIT = 77

local stage = (_G.arg or {})[1] or "all"

if stage == "all" then
  for _, name in ipairs(ORDER) do
    GATES[name]()
  end
  -- Counted from ORDER rather than written out, so adding a sixth gate
  -- cannot leave this line quietly claiming four. It already had: the
  -- `standalone` gate made it five without this line noticing.
  --
  -- **And a gate that skipped is not a gate that passed.** This line used to
  -- say "All 5 gates passed" while one of them had printed *skipped* forty
  -- lines earlier — which is how three real defects reached a release with
  -- every local run green. The number is now what ran.
  if #skipped == 0 then
    say("\n" .. paint("32", ("All %d gates passed."):format(#ORDER)))
  else
    say(
      "\n"
        .. paint("32", ("%d gates passed"):format(#ORDER - #skipped))
        .. ", "
        .. paint("33", ("%d skipped: %s"):format(#skipped, table.concat(skipped, ", ")))
        .. "."
    )
    say(paint("33", "  A skipped gate checked nothing. Green here is not green in CI."))
  end
elseif GATES[stage] then
  GATES[stage]()
else
  fail(
    ("Unknown stage '%s' (expected: %s, or nothing for all)."):format(
      stage,
      table.concat(ORDER, ", ")
    )
  )
end

-- the last line says what was skipped (`testing ci` shows it as the reason), the exit code says that it was
if #skipped > 0 then
  say(("skipped: %s"):format(table.concat(skipped, ", ")))
  vim.cmd("cq " .. SKIP_EXIT)
end
