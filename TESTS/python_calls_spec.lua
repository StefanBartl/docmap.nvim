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
--               `__init__.py` rather than a submodule),
--               use_class -> Thing.go (`from .helper import Thing`),
--               use_own_class -> Kit.make (`from . import Kit`)           3
--                                                                        --
--                                                                        14
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

  -- Parser-free too: a dotted callee whose head a named import bound (not a
  -- module alias). Inside the tree it names `<member>.<rest>` declared there,
  -- with no bare fallback to a module-level `go`; outside the tree it is an
  -- external call of that member path.
  do
    local ir = {
      order = { "./m.py", "./u.py" },
      nodes = {
        ["./m.py"] = {
          id = "./m.py",
          path = "./m.py",
          source = "./m.py",
          module = "m",
          language = "python",
          functions = { { name = "Cls.method", owner = "Cls" }, { name = "go" } },
          requires_raw = {},
          calls_raw = {},
        },
        ["./u.py"] = {
          id = "./u.py",
          path = "./u.py",
          source = "./u.py",
          module = "u",
          language = "python",
          functions = { { name = "caller" } },
          requires_raw = {
            { module = "m", names = { Cls = "Cls" } },
            { module = "extlib", names = { Ext = "Ext" } },
          },
          calls_raw = {
            { callee = "Cls.method", from_fn = "caller", line = 1 },
            { callee = "Cls.go", from_fn = "caller", line = 2 },
            { callee = "Ext.run", from_fn = "caller", line = 3 },
          },
        },
      },
      edges = {},
    }
    local added = require("docmap.core.calls").build(ir, {})
    eq(#added, 1, "named import: only the declared method resolves")
    eq(added[1].to, "./m.py")
    eq(added[1].to_fn, "Cls.method", "named import: `Cls.method()` reaches m's Cls.method")
    local ext = ir.nodes["./u.py"].calls_external
    eq(#ext, 1, "named import from outside the tree: one external call")
    eq(ext[1].module, "extlib")
    eq(ext[1].member, "Ext.run", "named import from outside the tree: the member path `Ext.run`")
  end

  -- Parser-free: `calls_heuristic` guesses a bare name only when the whole
  -- tree declares it once, and a method of a `methods_need_receiver` language
  -- is never a declaration of its bare name. So a bare `go()` must not guess
  -- the method `Box.go`, and the method `Widget.run` must not make the one
  -- free function `run` ambiguous.
  do
    local ir = {
      order = { "./m.py", "./n.py", "./u.py" },
      nodes = {
        ["./m.py"] = {
          id = "./m.py",
          path = "./m.py",
          source = "./m.py",
          module = "m",
          language = "python",
          functions = {
            { name = "Box.go", owner = "Box" },
            { name = "Widget.run", owner = "Widget" },
          },
          requires_raw = {},
          calls_raw = {},
        },
        ["./n.py"] = {
          id = "./n.py",
          path = "./n.py",
          source = "./n.py",
          module = "n",
          language = "python",
          functions = { { name = "run" } },
          requires_raw = {},
          calls_raw = {},
        },
        ["./u.py"] = {
          id = "./u.py",
          path = "./u.py",
          source = "./u.py",
          module = "u",
          language = "python",
          functions = { { name = "caller" } },
          requires_raw = {},
          calls_raw = {
            { callee = "go", from_fn = "caller", line = 1 },
            { callee = "run", from_fn = "caller", line = 2 },
          },
        },
      },
      edges = {},
    }
    local added = require("docmap.core.calls").build(ir, { calls_heuristic = true })
    eq(#added, 1, "heuristic: a bare call never guesses a method, only the free function")
    eq(added[1].to, "./n.py", "heuristic: a method does not make the free `run` ambiguous")
    eq(added[1].to_fn, "run")
    eq(added[1].confidence, "heuristic")
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

  eq(n, 14, "python_calls: exactly the fourteen edges counted by hand")

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
  -- A class a named import bound is a dotted callee whose head is no module:
  -- `Thing.go()` names `Thing.go` in the module the name came from, exactly
  -- as `helper.Thing.go()` does through the module binding.
  ok(
    edge(consumer, "use_class", helper, "Thing.go"),
    "python_calls: from .helper import Thing; Thing.go() reaches the method"
  )
  ok(
    edge(consumer, "use_own_class", "./pkg", "Kit.make"),
    "python_calls: from . import Kit; Kit.make() reaches the method in __init__.py"
  )
  for _, c in ipairs(ir.nodes[consumer].calls_external or {}) do
    ok(
      not c.module:find("^%.%.?/"),
      "python_calls: no relative module is ever an external call: " .. c.module
    )
  end
  for _, mod in ipairs(ir.nodes[consumer].requires_external or {}) do
    ok(not mod:find("^%.%.?/"), "python_calls: ...nor an external require: " .. mod)
  end

  -- The fallback names the package's `__init__` *file*, not its directory:
  -- a repository that is the package itself (`source = "."`, root id `.`)
  -- is reached, and a namespace package (a directory with no `__init__.py`)
  -- has no attribute to fall back to, so its missing submodule stays an
  -- external require instead of a require edge to the bare directory.
  do
    local proot = (vim.fn.getcwd():gsub("\\", "/")) .. "/TESTS/fixtures/pyroot"
    local pir = require("docmap.core.scan").scan(require("docmap.config").build(proot))
    local pcalls, prequires = {}, {}
    for _, e in ipairs(pir.edges or {}) do
      if e.kind == "call" then
        pcalls[e.from .. "#" .. e.from_fn .. ">" .. e.to .. "#" .. e.to_fn] = true
      elseif e.kind == "require" then
        prequires[e.from .. ">" .. e.to] = true
      end
    end
    ok(
      pcalls["./consumer.py#use_tool>.#tool"],
      "python_calls: from . import tool in a root package"
    )
    ok(prequires["./consumer.py>."], "python_calls: ...requires the root package node")
    ok(
      pcalls["./ns/leaf.py#leaf>.#tool"],
      "python_calls: from .. import tool up to the root package"
    )
    ok(
      not prequires["./ns/mod.py>./ns"],
      "python_calls: a namespace directory is no package to fall back to"
    )
    ok(
      vim.tbl_contains(pir.nodes["./ns/mod.py"].requires_external, "./gone"),
      "python_calls: ...so its missing submodule stays an external require"
    )
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
