-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil
-- TESTS/rust_calls_spec.lua — Rust call edges, and the module tree they walk
--
-- The seventh backend to emit call sites. The new thing is that the backend
-- anchors a path (`crate::`, `super::`, `Self::`, `use`, `mod x;`) to an
-- absolute module path, and `core/calls.lua` resolves an absolute `::` path
-- by its longest prefix that is a module of the map. The tree under
-- `TESTS/fixtures/rscalls/` is a real crate (`cargo check` passes), and the
-- edge count was worked out by hand from it before the scan ran:
--
--   lib.rs          by_use, by_child, by_module_alias -> helper double;
--                   by_alias, by_crate_path -> helper triple;
--                   by_type -> Widget::new; local_call -> same;
--                   same -> inner::deep; inner::deep -> inner::helper_in;
--                   inner::helper_in -> same_level (super::)             10
--   helper.rs       triple -> double                                      1
--   widget/mod.rs   Widget::new -> Widget::with (Self::),
--                   Widget::new -> parts::base, Widget::size -> scaled    3
--   widget/parts.rs base -> helper double (super::super::)                1
--                                                                        --
--                                                                        15
--
-- Not edges, on purpose: `.size()` on `Widget::new()`'s result (receiver of
-- unknown type), `String::from` (outside the crate), `println!` (a macro).

return function(H)
  local eq, ok = H.eq, H.ok

  local registry = require("documentation.core.lang_registry")
  local rs = registry.get("rust")
  ok(rs ~= nil, "rust: the backend must be registered")
  eq(rs.emits_calls, true, "rust: this backend returns call sites")
  eq(rs.call_scope, nil, "rust: siblings in a directory are different modules")
  eq(rs.methods_need_receiver, true, "rust: a bare name never names a method")

  -- Parser-free: the `::` branch of the resolver on a hand-built IR, so it is
  -- gated where no Rust grammar is installed too.
  do
    local function node(id, module, functions, calls)
      return {
        id = id,
        path = id,
        source = id,
        module = module,
        language = "rust",
        functions = functions,
        requires_raw = {},
        calls_raw = calls or {},
      }
    end
    local ir = {
      order = { "src/lib.rs", "src/w/mod.rs", "src/w/x.rs" },
      nodes = {
        ["src/lib.rs"] = node("src/lib.rs", "k", { { name = "a" }, { name = "go" } }, {
          { callee = "k::w::Widget::new", from_fn = "a", line = 1 },
          { callee = "k::w::x::f", from_fn = "a", line = 2 },
          { callee = "k::w::missing", from_fn = "a", line = 3 },
          { callee = "std::mem::swap", from_fn = "a", line = 4 },
          { callee = "Local::m", from_fn = "go", line = 5 },
        }),
        ["src/w/mod.rs"] = node(
          "src/w/mod.rs",
          "k::w",
          { { name = "Widget::new", owner = "Widget" } }
        ),
        ["src/w/x.rs"] = node("src/w/x.rs", "k::w::x", { { name = "f" } }),
      },
      edges = {},
    }
    table.insert(ir.nodes["src/lib.rs"].functions, { name = "Local::m", owner = "Local" })
    local got = {}
    for _, e in ipairs(require("documentation.core.calls").build(ir, {})) do
      got[e.from_fn .. ">" .. e.to .. "#" .. e.to_fn] = true
    end
    ok(
      got["a>src/w/mod.rs#Widget::new"],
      "rust: the longest module prefix, the rest a method's declared name"
    )
    ok(got["a>src/w/x.rs#f"], "rust: ...a deeper module wins over its parent")
    ok(got["go>src/lib.rs#Local::m"], "rust: an unanchored relative path is this file's own")
    eq(vim.tbl_count(got), 3, "rust: a missing member and another crate are no edges")
  end

  local explicit = os.getenv("DOCMAP_RUST_PARSER")
  local ok_add, has_rust
  if explicit and explicit ~= "" then
    ok_add, has_rust = pcall(vim.treesitter.language.add, "rust", { path = explicit })
  else
    ok_add, has_rust = pcall(vim.treesitter.language.add, "rust")
  end
  if not (ok_add and has_rust) then
    ok(true, "rust_calls: rust parser not installed — skipping the tree")
    return
  end

  local root = (vim.fn.getcwd():gsub("\\", "/")) .. "/TESTS/fixtures/rscalls"
  ok(vim.fn.isdirectory(root) == 1, "rust_calls: the fixture crate is checked in")

  local opts = require("documentation.config").build(root)
  local ir = require("documentation.core.scan").scan(opts)

  local calls, n = {}, 0
  for _, e in ipairs(ir.edges or {}) do
    if e.kind == "call" then
      n = n + 1
      calls[e.from .. "#" .. e.from_fn .. ">" .. e.to .. "#" .. e.to_fn] = e
    end
  end
  local lib, helper, widget, parts =
    "src/lib.rs", "src/helper.rs", "src/widget", "src/widget/parts.rs"
  local function edge(from, from_fn, to, to_fn)
    return calls[from .. "#" .. from_fn .. ">" .. to .. "#" .. to_fn]
  end

  eq(n, 15, "rust_calls: exactly the fifteen edges counted by hand")

  ok(edge(lib, "by_use", helper, "double"), "rust_calls: use crate::helper::double")
  ok(edge(lib, "by_alias", helper, "triple"), "rust_calls: use ...::{triple as t}")
  ok(
    edge(lib, "by_module_alias", helper, "double"),
    "rust_calls: use ...::{self as h}; h::double()"
  )
  ok(edge(lib, "by_crate_path", helper, "triple"), "rust_calls: crate::helper::triple()")
  ok(edge(lib, "by_child", helper, "double"), "rust_calls: mod helper; helper::double()")
  ok(
    edge(lib, "by_type", widget, "Widget::new"),
    "rust_calls: an imported type's associated function"
  )
  ok(edge(lib, "local_call", lib, "same"), "rust_calls: this file's own function")
  ok(edge(lib, "same", lib, "inner::deep"), "rust_calls: into an inline module")
  ok(
    edge(lib, "inner::deep", lib, "inner::helper_in"),
    "rust_calls: a bare name inside it is its sibling"
  )
  ok(edge(lib, "inner::helper_in", lib, "same_level"), "rust_calls: super:: out of it")
  ok(edge(helper, "triple", helper, "double"), "rust_calls: a bare free function")
  ok(edge(widget, "Widget::new", widget, "Widget::with"), "rust_calls: Self::with")
  ok(edge(widget, "Widget::new", parts, "base"), "rust_calls: a child module of mod.rs")
  ok(edge(widget, "Widget::size", widget, "Widget::scaled"), "rust_calls: self.scaled()")
  ok(edge(parts, "base", helper, "double"), "rust_calls: super::super::")

  -- The owner of a trait impl's method is the type, not the trait.
  local names = {}
  for _, fn in ipairs(ir.nodes[widget].functions) do
    names[fn.name] = fn
  end
  ok(names["Widget::size2"], "rust_calls: `impl Sized2 for Widget` records Widget::size2")
  eq(names["Widget::size2"].owner_kind, "impl")
end
