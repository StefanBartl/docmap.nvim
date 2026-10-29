-- TESTS/check_applicability_spec.lua — checks declare the convention they
-- need and report "not applicable" for a language without it.

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
end
