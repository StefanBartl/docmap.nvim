-- TESTS/diff_surface_spec.lua — core/diff.lua `surface`: which changes to the
-- published surface can break a caller, and the `--breaking=<ref>` CLI gate
-- built on it.
--
-- The classification is pure, so most of this runs on hand-built maps. The
-- gate is run for real against a throw-away git repository, because the exit
-- code and the git retrieval are the parts a map cannot show.

-- luacheck: ignore 122
-- (`capture` below swaps `io.stdout`/`io.stderr` to read what `cli.run` says,
-- and puts them back.)
return function(H)
  local eq, ok = H.eq, H.ok
  local diff = require("documentation.core.diff")

  ---@param fns table[] functions of the single node "n"
  local function ir(fns)
    return {
      nodes = { n = { id = "n", path = "n", functions = fns } },
      order = { "n" },
      edges = {},
      meta = {},
    }
  end

  local function fn(name, extra)
    return vim.tbl_extend(
      "force",
      { name = name, internal = false, params = {}, returns = {} },
      extra or {}
    )
  end

  local function kinds(list)
    local out = {}
    for _, c in ipairs(list) do
      out[#out + 1] = c.kind
    end
    table.sort(out)
    return table.concat(out, ",")
  end

  -- -------------------------------------------------------------------
  -- Removal and visibility
  -- -------------------------------------------------------------------
  do
    local s = diff.surface(ir({ fn("M.a"), fn("M.b") }), ir({ fn("M.a") }))
    eq(kinds(s.breaking), "removed", "a removed published function is breaking")
    eq(s.breaking[1].key, "n#M.b", "...and names the function")

    s = diff.surface(ir({ fn("M.a", { internal = true }) }), ir({}))
    eq(#s.breaking, 0, "removing an @internal function is not breaking")

    s = diff.surface(ir({ fn("M.a") }), ir({ fn("M.a", { internal = true }) }))
    eq(kinds(s.breaking), "internalised", "a function that became @internal left the surface")

    s = diff.surface(ir({ fn("M.a") }), ir({ fn("M.a"), fn("M.new") }))
    eq(#s.breaking, 0, "an addition is not breaking")
    eq(kinds(s.additive), "added", "...it is additive")

    -- An older map has no `internal` field: the shape of the name decides,
    -- and the guess is counted so the output can say so.
    local old = ir({
      { name = "M.a", params = {}, returns = {} },
      { name = "helper", params = {}, returns = {} },
    })
    s = diff.surface(old, ir({}))
    eq(kinds(s.breaking), "removed", "no field: the qualified name is surface, the bare one is not")
    eq(s.breaking[1].key, "n#M.a", "...the qualified one")
    eq(s.guessed_visibility, 1, "...and the guess is counted")
  end

  -- -------------------------------------------------------------------
  -- Parameters
  -- -------------------------------------------------------------------
  do
    local function one(old_params, new_params)
      return diff.surface(
        ir({ fn("M.f", { params = old_params }) }),
        ir({ fn("M.f", { params = new_params }) })
      )
    end
    local function p(name, type_, optional)
      return { name = name, type = type_, optional = optional or false, desc = "" }
    end

    local s = one({ p("a", "string"), p("b", "number") }, { p("a", "string") })
    eq(kinds(s.breaking), "params", "a parameter removed is breaking")

    s = one({ p("a", "string") }, { p("a", "string"), p("b", "number") })
    eq(kinds(s.breaking), "params", "a required parameter added is breaking")

    s = one({ p("a", "string") }, { p("a", "string"), p("b", "number", true) })
    eq(#s.breaking, 0, "an optional parameter appended is compatible")
    eq(kinds(s.additive), "params", "...and additive")

    s = one({ p("a", "string", true) }, { p("a", "string") })
    eq(kinds(s.breaking), "narrowed", "optional -> required is breaking")

    s = one({ p("a", "string|nil") }, { p("a", "string") })
    eq(kinds(s.breaking), "narrowed", "`T|nil` -> `T` rejects a caller that passed nil")

    s = one({ p("a", "string?") }, { p("a", "string") })
    eq(kinds(s.breaking), "narrowed", "`T?` -> `T` rejects a caller that passed nil")

    s = one({ p("a", "string") }, { p("a", "string|nil") })
    eq(#s.breaking, 0, "accepting nil where it was not accepted is not breaking")

    s = one({ p("a", "string|number") }, { p("a", "string") })
    eq(kinds(s.breaking), "narrowed", "a union member dropped from a parameter is breaking")

    s = one({ p("a", "string") }, { p("a", "string|number") })
    eq(#s.breaking, 0, "a union member added to a parameter is not breaking")
    eq(kinds(s.additive), "widened", "...it is additive")

    s = one({ p("a", "string") }, { p("renamed", "string") })
    eq(
      #s.breaking + #s.additive + #s.unclassified,
      0,
      "renaming a parameter changes nothing a caller sees"
    )

    s = one({ p("a", "table<string, integer|nil>") }, { p("a", "table<string, integer|nil>") })
    eq(#s.breaking + #s.additive, 0, "a `|` inside brackets is not a union member")

    s = one({ p("a", "any") }, { p("a", "string") })
    eq(#s.breaking, 0, "a change from `any` is not called breaking")
    eq(kinds(s.unclassified), "type", "...it is listed as unclassified")
  end

  -- -------------------------------------------------------------------
  -- Returns
  -- -------------------------------------------------------------------
  do
    local function one(old_returns, new_returns)
      return diff.surface(
        ir({ fn("M.f", { returns = old_returns }) }),
        ir({ fn("M.f", { returns = new_returns }) })
      )
    end
    local function r(type_)
      return { type = type_, desc = "" }
    end

    local s = one({ r("string"), r("number") }, { r("string") })
    eq(kinds(s.breaking), "returns", "fewer return values is breaking")

    s = one({ r("string") }, { r("string|nil") })
    eq(kinds(s.breaking), "returns", "a new possible return value is breaking")

    s = one({ r("string") }, { r("string?") })
    eq(kinds(s.breaking), "returns", "`?` adds `nil` to what a caller may meet")

    s = one({ r("string|nil") }, { r("string") })
    eq(#s.breaking, 0, "a return type that lost a possibility is not breaking")
    eq(kinds(s.additive), "returns", "...it is additive")

    s = one({ r("string") }, { r("string"), r("number") })
    eq(#s.breaking, 0, "an added return value is not breaking")
  end

  -- -------------------------------------------------------------------
  -- Rendering
  -- -------------------------------------------------------------------
  do
    local before, after = ir({ fn("M.gone") }), ir({})
    local lines = diff.render_surface(diff.surface(before, after), before, after)
    ok(lines[1]:find("Breaking changes (1)", 1, true), "render: the section is titled and counted")
    ok(
      lines[2]:find("M.gone", 1, true) and lines[2]:find("removed", 1, true),
      "render: the line names the function"
    )
    eq(
      #diff.render_surface(diff.surface(after, after), after, after),
      0,
      "render: nothing changed -> no lines"
    )
  end

  -- -------------------------------------------------------------------
  -- The gate: `--breaking=<ref>` on a real repository
  -- -------------------------------------------------------------------
  local git_ok = vim.fn.executable("git") == 1
  if not git_ok then
    return
  end

  local cli = require("documentation.core.cli")
  local docmap = require("documentation")

  local function capture(f)
    local real_out, real_err = io.stdout, io.stderr
    local out, err = {}, {}
    local function sink(into)
      return {
        write = function(self, ...)
          for _, part in ipairs({ ... }) do
            into[#into + 1] = tostring(part)
          end
          return self
        end,
      }
    end
    io.stdout, io.stderr = sink(out), sink(err)
    local ran, result = pcall(f)
    io.stdout, io.stderr = real_out, real_err
    if not ran then
      error(result, 0)
    end
    return result, table.concat(out), table.concat(err)
  end

  local root = (vim.fn.tempname() .. "_surface"):gsub("\\", "/")
  local function git(...)
    local proc = vim
      .system({ "git", "-c", "user.email=t@t", "-c", "user.name=t", ... }, { cwd = root, text = true })
      :wait()
    eq(proc.code, 0, "git " .. table.concat({ ... }, " ") .. ": " .. (proc.stderr or ""))
  end
  local function opts()
    return { root = root, source = "lua/t", lua_root = "lua", out_dir = "docs/map" }
  end

  H.write(root .. "/lua/t/init.lua", {
    "---@module 't'",
    "local M = {}",
    "",
    "---Keeps.",
    "---@param a string",
    "---@return string",
    "function M.keep(a)",
    "  return a",
    "end",
    "",
    "---Goes.",
    "function M.gone()",
    "end",
    "",
    "return M",
  })
  git("init", "-q")
  docmap.generate(opts())
  git("add", "-A")
  git("commit", "-q", "-m", "base")

  -- Nothing changed: the gate passes.
  local code, out = capture(function()
    return cli.run(opts(), { "--breaking=HEAD" })
  end)
  eq(code, 0, "gate: an unchanged tree passes")
  ok(out:find("No breaking change", 1, true), "gate: ...and says so")

  -- A published function removed: the gate fails.
  H.write(root .. "/lua/t/init.lua", {
    "---@module 't'",
    "local M = {}",
    "",
    "---Keeps.",
    "---@param a string",
    "---@return string",
    "function M.keep(a)",
    "  return a",
    "end",
    "",
    "return M",
  })
  local err
  code, out, err = capture(function()
    return cli.run(opts(), { "--breaking=HEAD" })
  end)
  eq(code, 1, "gate: a removed published function fails with exit 1")
  ok(out:find("M.gone", 1, true), "gate: ...and names it")
  ok(err:find("1 breaking change", 1, true), "gate: ...and counts it on stderr")

  -- No verdict is exit 2, never 1: an unknown ref is not a breaking change.
  code, out, err = capture(function()
    return cli.run(opts(), { "--breaking=no-such-ref" })
  end)
  eq(code, 2, "gate: an unknown ref is a refusal, exit 2")
  eq(out, "", "gate: ...with nothing on stdout")
  ok(err:find("refusing to compare", 1, true), "gate: ...said as one line")

  -- A ref that is an option is refused before git sees it: `--output=` would
  -- make `git show` write a file.
  local victim = root .. "/victim.txt"
  code, out, err = capture(function()
    return cli.run(opts(), { "--breaking=--output=" .. victim })
  end)
  eq(code, 2, "gate: a ref that starts with `-` is a refusal")
  eq(out, "", "gate: ...with nothing on stdout")
  ok(err:find("is not a revision", 1, true), "gate: ...and says why")
  eq(vim.uv.fs_stat(victim), nil, "gate: ...and git never ran with it")

  vim.fn.delete(root, "rf")
end
