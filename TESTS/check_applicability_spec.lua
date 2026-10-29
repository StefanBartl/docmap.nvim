-- TESTS/check_applicability_spec.lua — checks declare the convention they
-- need and report "not applicable" for a language without it.

-- luacheck: ignore 122
-- (the end-to-end part swaps io.stdout/io.stderr to read the CLI report, and restores them.)
return function(H)
  local ok = H.ok
  local check = require("docmap.core.check")

  local function node(id, source, language, fns)
    return {
      id = id,
      kind = "module",
      name = id,
      path = id,
      source = source,
      language = language,
      module = nil,
      summary = "x",
      body = "",
      types = {},
      children = {},
      functions = fns or {},
    }
  end

  local ir = {
    order = { "a", "b", "c" },
    nodes = {
      a = node("a", "lua/a.lua", "lua"),
      b = node("b", "src/b.ts", "typescript", { { name = "f" } }),
      c = node("c", "src/c.ts", "typescript"),
    },
  }

  ok(check.NEEDS["missing-module-tag"] == "module_tag", "missing-module-tag declares module_tag")
  ok(check.NEEDS["undocumented-param"] == "param_docs", "undocumented-param declares param_docs")
  ok(check.applies("missing-module-tag", ir.nodes.a), "module tag applies to Lua")
  ok(not check.applies("missing-module-tag", ir.nodes.b), "module tag does not apply to TS")
  ok(check.applies("dead-function", ir.nodes.b), "an undeclared check always applies")

  local na = check.not_applicable(ir)
  ok(#na == 1, "only the module-tag check skipped something (TS documents params)")
  ok(na[1].check == "missing-module-tag" and na[1].count == 2, "counts the two TS nodes")
  ok(na[1].languages[1] == "typescript", "names the language")

  ok(
    #check.not_applicable({ order = { "a" }, nodes = { a = ir.nodes.a } }) == 0,
    "Lua skips nothing"
  )

  -- A Zig node with a function: neither a module tag nor per-parameter docs.
  local zig_ir = {
    order = { "z", "zn" },
    nodes = {
      z = node("z", "src/z.zig", "zig", { { name = "f" } }),
      zn = node("zn", "src/zn.zig", "zig"),
    },
  }
  ok(not check.applies("undocumented-param", zig_ir.nodes.z), "param docs do not apply to Zig")
  ok(check.applies("undocumented-param", ir.nodes.b), "param docs apply to TypeScript")
  ok(check.applies("undocumented-param", { language = nil }), "unknown language keeps the check")

  local zna = check.not_applicable(zig_ir)
  ok(#zna == 2, "Zig skips both checks")
  local by = {}
  for _, e in ipairs(zna) do
    by[e.check] = e
  end
  ok(by["missing-module-tag"].count == 2, "both Zig nodes lack a module tag")
  ok(
    by["undocumented-param"].count == 1,
    "only the node with a function counts for param docs (zn has none)"
  )

  -- A check the policy switched off never ran, so it skipped nothing.
  local off = check.not_applicable(zig_ir, { checks = { ["missing-module-tag"] = false } })
  ok(#off == 1 and off[1].check == "undocumented-param", "a disabled check is not reported")
  ok(#check.not_applicable(zig_ir, {
    checks = { ["missing-module-tag"] = false, ["undocumented-param"] = false },
  }) == 0, "both disabled, nothing reported")
  ok(
    #check.not_applicable(zig_ir, { checks = { ["missing-module-tag"] = "warn" } }) == 2,
    "a re-graded check still ran"
  )

  -- Doc coverage reads the same declaration.
  local dc = require("docmap.core.doccoverage")
  ok(not dc.language_documents_params("zig"), "doccoverage agrees: Zig has no param docs")
  ok(dc.language_documents_params("typescript"), "doccoverage agrees: TS has param docs")

  -- One sentence for both surfaces.
  local sentence = require("docmap.core.findings").format_not_applicable(by["missing-module-tag"])
  ok(
    sentence == "Not applicable: missing-module-tag on 2 node(s); no module_tag in zig",
    "shared sentence: " .. sentence
  )

  -- End to end: the CLI report and the page carry the skip, and honour the policy.
  local config = require("docmap.config")
  local cli = require("docmap.core.cli")
  local function run_project(checks)
    local root = (vim.fn.tempname():gsub("\\", "/"))
    H.write(root .. "/src/a.zig", { "/// Does a.", "pub fn a(x: i32) void {}" })
    local built = config.build(root, {
      source = "src",
      lua_root = "lua",
      out_dir = "docs/map",
      checks = checks,
    })
    local real_out, real_err = io.stdout, io.stderr
    local out = {}
    local sink = {
      write = function(self, ...)
        for _, part in ipairs({ ... }) do
          out[#out + 1] = tostring(part)
        end
        return self
      end,
    }
    io.stdout, io.stderr = sink, sink
    local ran, err = pcall(cli.run, built, {})
    io.stdout, io.stderr = real_out, real_err
    ok(ran, "cli.run did not raise: " .. tostring(err))
    local page = H.slurp(root .. "/docs/map/index.html") or ""
    vim.fn.delete(root, "rf")
    return table.concat(out), page
  end

  local report, page = run_project(nil)
  ok(
    report:find("Not applicable: missing-module-tag on 1 node(s)", 1, true),
    "CLI reports the skip"
  )
  ok(report:find("Not applicable: undocumented-param on 1 node(s)", 1, true), "CLI reports params")
  ok(
    page:find('<p class="na">Not applicable: missing-module-tag', 1, true),
    "page reports the skip"
  )

  local report2, page2 = run_project({ ["missing-module-tag"] = false })
  ok(not report2:find("missing-module-tag on", 1, true), "CLI hides a policy-disabled check")
  ok(report2:find("undocumented-param on 1", 1, true), "CLI still reports the other")
  ok(not page2:find('class="na">Not applicable: missing-module-tag', 1, true), "page hides it too")
end
