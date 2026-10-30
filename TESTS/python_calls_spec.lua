-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil
-- TESTS/python_calls_spec.lua — Python call edges, and the scope rules they need
--
-- The sixth backend to emit call sites. What is new is not the query but two
-- resolver facts: a method is reachable only through a receiver
-- (`methods_need_receiver`), and a relative import binds names and modules
-- (`RawRequire.names` / `alias`). Both are statements about several files,
-- so the tree under `TESTS/fixtures/pycalls/` is real Python, and the edge
-- count below was worked out by hand from it before the scan ran:
--
--   helper.py   Thing.go -> Thing.step (self.), Thing.step -> double     2
--   widget.py   use -> double, via_alias -> triple, via_module -> double,
--               static_call -> Thing.go (helper.Thing.go),
--               local_call -> same, Box.go -> Box.size (self.),
--               Box.by_class -> Box.size (Box.)                           7
--   sub/deep.py deep -> double, deep -> triple                            2
--   consumer.py use_tool -> tool (`from . import tool`, a def of
--               `__init__.py` rather than a submodule)                    1
--                                                                        --
--                                                                        12
--
-- Not edges, on purpose: `go()` in `not_a_method` (a bare name never reaches
-- `Box.go`), `self.attr.go()`, `super().go()` and `os.path.join` (outside).

return function(H)
  local eq, ok = H.eq, H.ok

  local registry = require("docmap.core.lang_registry")
  local py = registry.get("python")
  ok(py ~= nil, "python: the backend must be registered")
  eq(py.emits_calls, true, "python: this backend returns call sites")
  eq(
    py.call_scope,
    nil,
    "python: the module is the file, an unqualified call never reaches a sibling"
  )
  eq(py.methods_need_receiver, true, "python: a bare name never names a method")

  -- Parser-free: the resolver rule on a hand-built IR, so it is gated where
  -- no Python grammar is installed too.
  do
    local ir = {
      order = { "./m.py" },
      nodes = {
        ["./m.py"] = {
          id = "./m.py",
          path = "./m.py",
          source = "./m.py",
          language = "python",
          functions = {
            { name = "Box.go", owner = "Box" },
            { name = "caller" },
            { name = "other" },
            { name = "callback" },
          },
          requires_raw = {},
          calls_raw = {
            { callee = "go", from_fn = "caller", line = 1 },
            { callee = "Box.go", from_fn = "other", line = 2 },
            -- `self.callback()` on an attribute holding a function, rewritten
            -- to `Box.callback`: no such method, and the module-level
            -- `callback` is not it either.
            { callee = "Box.callback", from_fn = "Box.go", line = 3 },
            { callee = "Box.attr.callback", from_fn = "Box.go", line = 4 },
          },
        },
      },
      edges = {},
    }
    local added = require("docmap.core.calls").build(ir, {})
    eq(#added, 1, "python: only the qualified call resolves")
    eq(added[1].from_fn, "other")
    eq(added[1].to_fn, "Box.go", "python: `Box.go()` reaches the method by its declared name")
  end

  local explicit = os.getenv("DOCMAP_PYTHON_PARSER")
  local ok_add, has_python
  if explicit and explicit ~= "" then
    ok_add, has_python = pcall(vim.treesitter.language.add, "python", { path = explicit })
  else
    ok_add, has_python = pcall(vim.treesitter.language.add, "python")
  end
  if not (ok_add and has_python) then
    ok(true, "python_calls: python parser not installed — skipping the tree")
    return
  end

  local root = (vim.fn.getcwd():gsub("\\", "/")) .. "/TESTS/fixtures/pycalls"
  ok(vim.fn.isdirectory(root) == 1, "python_calls: the fixture tree is checked in")

  local opts = require("docmap.config").build(root)
  local ir = require("docmap.core.scan").scan(opts)

  local calls, n = {}, 0
  local requires = {}
  for _, e in ipairs(ir.edges or {}) do
    if e.kind == "call" then
      n = n + 1
      calls[e.from .. "#" .. e.from_fn .. ">" .. e.to .. "#" .. e.to_fn] = e
    elseif e.kind == "require" then
      requires[e.from .. ">" .. e.to] = true
    end
  end

  local helper, widget, deep = "./pkg/helper.py", "./pkg/widget.py", "./pkg/sub/deep.py"
  local function edge(from, from_fn, to, to_fn)
    return calls[from .. "#" .. from_fn .. ">" .. to .. "#" .. to_fn]
  end

  eq(n, 12, "python_calls: exactly the twelve edges counted by hand")

  -- `self.` and `cls.` are the enclosing class: rewritten, not guessed.
  ok(edge(helper, "Thing.go", helper, "Thing.step"), "python_calls: self.step() is Thing.step")
  ok(edge(widget, "Box.go", widget, "Box.size"), "python_calls: ...in another class too")
  ok(edge(widget, "Box.by_class", widget, "Box.size"), "python_calls: Box.size() by the class name")
  ok(
    edge(helper, "Thing.step", helper, "double"),
    "python_calls: a bare name is a module-level def"
  )
  ok(edge(widget, "local_call", widget, "same"), "python_calls: ...of this file")

  -- What imports bind.
  ok(edge(widget, "use", helper, "double"), "python_calls: from .helper import double")
  ok(edge(widget, "via_alias", helper, "triple"), "python_calls: from .helper import triple as t")
  ok(
    edge(widget, "via_module", helper, "double"),
    "python_calls: from . import helper; helper.double()"
  )
  ok(edge(widget, "static_call", helper, "Thing.go"), "python_calls: helper.Thing.go()")
  ok(edge(deep, "deep", helper, "double"), "python_calls: from ..helper import double")
  ok(edge(deep, "deep", helper, "triple"), "python_calls: from .. import helper as h; h.triple()")

  -- `from . import tool` where `./tool.py` does not exist: Python finds
  -- `tool` in the package's `__init__.py`, and so must the resolver.
  local consumer = "./pkg/consumer.py"
  ok(
    edge(consumer, "use_tool", "./pkg", "tool"),
    "python_calls: from . import tool binds the package's own def when ./tool is no file"
  )
  ok(requires[consumer .. ">./pkg"], "python_calls: ...and requires the package node, once")
  for _, c in ipairs(ir.nodes[consumer].calls_external or {}) do
    ok(
      not c.module:find("^%.%.?/"),
      "python_calls: no relative module is ever an external call: " .. c.module
    )
  end
  for _, mod in ipairs(ir.nodes[consumer].requires_external or {}) do
    ok(not mod:find("^%.%.?/"), "python_calls: ...nor an external require: " .. mod)
  end

  -- The negatives the scope rules exist for.
  for key in pairs(calls) do
    ok(not key:find("#not_a_method>", 1, true), "python_calls: a bare go() never reaches Box.go")
    ok(not key:find("#Box.chain>", 1, true), "python_calls: self.attr.go() has an unknown receiver")
    ok(not key:find("#Box.inherited>", 1, true), "python_calls: super().go() needs the hierarchy")
  end

  local external
  for _, c in ipairs(ir.nodes[widget].calls_external or {}) do
    if c.module == "os" then
      external = c
    end
  end
  ok(external, "python_calls: `import os` makes os.path.join an external call")
  eq(external.member, "path.join")

  -- Relative imports resolve in a root layout (`./` ids) and from a
  -- package's own `__init__.py` (relative to the package, not above it).
  ok(requires[widget .. ">" .. helper], "python_calls: from . import helper is a require edge")
  ok(requires["./pkg>" .. helper], "python_calls: ...from __init__.py too")
  ok(requires["./pkg>./pkg/sub"], "python_calls: from . import sub names the subpackage")

  -- `unused-require`: the deliberately unused `import json` is found, the
  -- re-export `from . import sub` in `__init__.py` is not.
  local unused = {}
  for _, f in ipairs(require("docmap.core.check").run(ir, opts)) do
    if f.check == "unused-require" then
      unused[#unused + 1] = f
    end
  end
  eq(#unused, 1, "python_calls: one unused import, and no re-export reported")
  eq(unused[1].params.alias, "json")
end
