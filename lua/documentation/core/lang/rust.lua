---@module 'documentation.core.lang.rust'
--- Rust, registered as a language backend — the thirteenth, and the one that
--- meets Phase 0's last open question head-on.
---
--- **`mod x { … }` is the "one file, many modules" case**, and it is answered
--- here the way C++ and Python answered their own owning-scope problems:
--- **by qualifying the name**, not by changing the IR. A function inside an
--- inline module is recorded as `x::helper`, an inherent method as
--- `Widget::new`, a trait method as `Doer::go`. That is honest, it costs
--- nothing, and it is what a reader searching for the name would type.
---
--- It is not the *full* answer, and the difference is worth stating: the IR
--- still has one node per file, so an inline module is not a node and cannot
--- have its own summary, its own coverage, or its own edges. The Phase 0 item
--- asking for `Documentation.Node` to allow several modules per file stays
--- open. What is closed is the practical half — nothing is missing from the
--- map, and nothing is mis-attributed.
---
--- **Visibility has four values and only one of them is published.** `pub` is
--- the crate's public surface; `pub(crate)`, `pub(super)` and `pub(in path)`
--- are *restricted* — visible somewhere, but not from outside — and no
--- modifier at all is private. Collapsing the restricted forms into
--- "internal" is the same judgement Java and C# made about `protected`: from
--- outside, they answer alike. Rust is the language where that distinction is
--- written most explicitly, which is why it is worth naming rather than
--- glossing.
---
--- **`param_docs = false`, the fourth language to declare it**, and this one
--- was predicted: Part 1 of `MULTILANG.md` costed rustdoc years ago as "prose
--- Markdown, no tag vocabulary" and concluded `param-name-mismatch` would
--- have nothing to compare against. It does not. `# Arguments` sections exist
--- by habit in some projects and are absent from most, and reading a Markdown
--- heading as a parameter contract would invent a convention the language
--- does not have.
---
--- **`//!` documents the file and `///` the declaration below it** — exactly
--- the split Zig established, and the second language to give this tool both
--- halves as part of the language rather than as a comment convention layered
--- on top.
---
--- **The module path is derived from the file path**, so `use crate::a::b`
--- resolves to a real node. See `module_path_of` for how, and for the two
--- shapes that defeat it.
---
--- ## What a scope is, for the call graph
---
--- Asked before the query was written. **The scope is the crate's module
--- tree, not the file and not the directory**: a module is declared by its
--- parent (`mod x;`), and a path names a function by walking that tree —
--- `crate::a::f`, `super::f`, `self::x::f`, a child `x::f`, or a name a `use`
--- bound into *this* module (a `use` in `mod inner { … }` binds in `inner`
--- only). Go's `call_scope = "package"` does not fit: siblings in one
--- directory are different modules and see nothing of each other unqualified.
---
--- So the extractor does the walking, because only this file knows its own
--- module path, its `use` bindings, its `mod` declarations and its inline
--- modules: every callee it can anchor is rewritten to an **absolute path**
--- (`crate_name::helper::double`, `crate_name::widget::Widget::new`), and
--- `core/calls.lua` resolves an absolute path by its longest prefix that is a
--- module of the map, the rest being the function's declared name there.
---
---   - `self.go()` in an `impl Widget` method is `Widget::go`, and `Self::new()`
---     is `Widget::new` — the owner every method already records.
---   - A bare `go()` never reaches a method (`methods_need_receiver`): Rust
---     needs `self.`, `Self::` or the type.
---   - A bare name inside `mod inner { … }` is that inline module's function
---     first, then a name a `use` in that module bound.
---
--- Not resolved, on purpose: calls on a receiver of unknown type
--- (`w.size()`, `Widget::new().size()`), trait dispatch, `<T as Tr>::m()`, any
--- path into another crate (`std::`, a dependency), and calls inside a macro
--- invocation (`assert_eq!(f(x), 1)`), whose arguments are a token tree, not
--- an expression the grammar parses.

local M = {}

M.name = "rust"

M.grammar = "rust"

---@type string[]
M.extensions = { "rs" }

---A Rust file's module path is its position under `src/`, never a tag inside
---it. Nothing tag-shaped can be missing.
M.module_tag = false

---`mod.rs` makes a directory a module — the fourth
---directory-owns-a-module convention here, after Lua's `init.lua`, Python's
---`__init__.py` and JavaScript's `index.js`. (The 2018 edition prefers
---`foo.rs` beside `foo/`, and both are still written; the file is what this
---field is for, and the sibling form needs nothing.)
M.module_file = "mod.rs"

---@type string[]
M.line_comments = { "//" }

---@type { [1]: string, [2]: string }[]
M.block_comments = { { "/*", "*/" } }

---**rustdoc has no tag vocabulary**, so there is no per-parameter form to
---check. `# Arguments` is a Markdown heading some projects write and most do
---not; reading it as a contract would invent a convention the language does
---not have. Fourth language to declare this, and the only one where the
---costing document predicted it years before the backend existed.
M.param_docs = false

---@param filename string
---@return boolean
function M.is_source(filename)
  return filename:match("%.rs$") ~= nil
end

---Where this backend's sources live under `root`, or `nil`.
---
---`src/` and almost nothing else: Cargo requires it. A workspace puts each
---member crate in its own directory, each with its own `src/`, which is why
---the members are checked one level down before giving up.
---@param root string
---@return string?
function M.detect_source(root)
  local safe_fs = require("documentation.core.safe_fs")

  local function holds_rs(dir)
    for _, entry in ipairs(safe_fs.entries(root, dir)) do
      local name, kind = entry.name, entry.type
      if kind ~= "directory" and M.is_source(name) then
        return true
      end
    end
    return false
  end

  if holds_rs(root .. "/src") then
    return "src"
  end
  -- A Cargo workspace: no `src/` at the root, one per member. The root is
  -- the honest answer there — the map should hold every member, and naming
  -- one of them would silently drop the rest.
  for _, entry in ipairs(safe_fs.entries(root, root)) do
    local name, kind = entry.name, entry.type
    if
      kind == "directory"
      and name:sub(1, 1) ~= "."
      and holds_rs(root .. "/" .. name .. "/src")
    then
      return "."
    end
  end
  if holds_rs(root) then
    return "."
  end
  return nil
end

---@param path string
---@return string?
local function read(path)
  local fd = io.open(path, "rb")
  if not fd then
    return nil
  end
  local src = fd:read("*a")
  fd:close()
  return src
end

---@param src string
---@return TSNode?
local function parse(src)
  local ok, parser = pcall(vim.treesitter.get_string_parser, src, M.grammar)
  if not ok or not parser then
    return nil
  end
  local ok_parse, trees = pcall(function()
    return parser:parse()
  end)
  if not ok_parse or not trees or not trees[1] then
    return nil
  end
  return trees[1]:root()
end

---@param node TSNode
---@param src string
---@return string
local function text_of(node, src)
  local _, _, sbyte = node:start()
  local _, _, ebyte = node:end_()
  return src:sub(sbyte + 1, ebyte)
end

---@param node TSNode
---@param kind string
---@return TSNode?
local function child_of(node, kind)
  for child in node:iter_children() do
    if child:type() == kind then
      return child
    end
  end
  return nil
end

---This file's module path, as `use` would write it.
---
---**Derived from the file's position under `src/`, because that is where
---Rust puts it too.** `src/lib.rs` and `src/main.rs` are the crate root;
---`src/foo.rs` and `src/foo/mod.rs` are both `crate::foo`; `src/foo/bar.rs`
---is `crate::foo::bar`. Deriving it is what lets `use crate::foo::bar::Thing`
---resolve to a node instead of landing in `requires_external` — which is the
---difference between a Rust map with a dependency graph and one without.
---
---**Two shapes defeat it, and neither is silent about it.** A crate that
---does not use `src/` at all gets `nil` and falls back to path identity, the
---same as Zig. And `#[path = "…"]` relocates a module explicitly; this reads
---the filesystem rather than the attribute, so a relocated module resolves
---under where it *lives* rather than where it is *named*. Both are rare and
---both fail toward "no edge" rather than toward a wrong one.
---@param path string
---@return string? module The dotted module path, crate-qualified.
---@return string? crate The crate this file belongs to.
local function module_path_of(path)
  local normalised = path:gsub("\\", "/")
  local before, after = normalised:match("^(.*)/src/(.+)$")
  if not after then
    after = normalised:match("^src/(.+)$")
    before = ""
    if not after then
      return nil, nil
    end
  end

  -- **The crate name, not `crate`, and a workspace is why.** A Cargo
  -- workspace gives every member its own `crate::` root, so `crate::builder`
  -- in one member and `crate::builder` in another are different modules with
  -- the same name — and a module index keyed on that string would resolve
  -- one member's import to the other member's file. Measured on
  -- `clap-rs/clap`, which has three members and a `builder` in more than
  -- one.
  --
  -- The directory holding `src/` is the crate, which is Cargo's own layout
  -- rule. A single-crate repository gets its root directory's name, which is
  -- what another crate would call it anyway.
  local crate = before:match("([^/]+)$") or "crate"

  after = after:gsub("%.rs$", "")
  if after == "lib" or after == "main" then
    return crate, crate
  end
  after = after:gsub("/mod$", "")
  return crate .. "::" .. after:gsub("/", "::"), crate
end

---Every doc comment in the file, split into the two kinds Rust distinguishes.
---
---`///` documents the item *below* it and is keyed by the row a run ends on;
---`//!` documents the file (or the enclosing inline module) and is collected
---in order. The same split Zig established, and Rust marks it in the grammar
---rather than in the text: the parser hands back an
---`inner_doc_comment_marker` or an `outer_doc_comment_marker`, so this needs
---no pattern on the comment body at all.
---@param root TSNode
---@param src string
---@return table<integer, string[]> outer
---@return string[] inner
local function doc_comments(root, src)
  local outer, inner = {}, {}
  local function walk(node)
    local kind = node:type()
    if kind == "line_comment" or kind == "block_comment" then
      local body_node = child_of(node, "doc_comment")
      if body_node then
        local body = text_of(body_node, src):gsub("^%s", ""):gsub("%s+$", "")
        if child_of(node, "inner_doc_comment_marker") then
          inner[#inner + 1] = body
        elseif child_of(node, "outer_doc_comment_marker") then
          local srow = node:start()
          local previous = outer[srow - 1]
          if previous then
            outer[srow - 1] = nil
            previous[#previous + 1] = body
            outer[srow] = previous
          else
            outer[srow] = { body }
          end
        end
      end
      return
    end
    for child in node:iter_children() do
      walk(child)
    end
  end
  walk(root)
  return outer, inner
end

---The `///` block directly above `row`, joined.
---
---Attributes sit between a doc comment and the item it documents —
---`#[derive(Debug)]`, `#[cfg(test)]`, `#[inline]` — so the row above an item
---is frequently an attribute rather than the comment. `attribute_item` rows
---are skipped rather than treated as a wall, which is the same allowance
---Python makes for `# type: ignore`.
---@param outer table<integer, string[]>
---@param row integer 0-based row of the documented item.
---@param attr_rows table<integer, boolean>
---@return string
local function doc_above(outer, row, attr_rows)
  local r = row - 1
  while attr_rows[r] do
    r = r - 1
  end
  local lines = outer[r]
  if not lines then
    return ""
  end
  return table.concat(lines, "\n")
end

---Whether an item is outside the crate's published surface.
---
---**Four values, one of which is published.** `pub` is the public surface.
---`pub(crate)`, `pub(super)` and `pub(in path)` are *restricted* — visible
---somewhere and not from outside — and no modifier is private. The
---restricted forms collapse into internal for the reason Java's `protected`
---and C#'s `internal` do: from outside, they answer alike.
---**A trait's members carry no modifier of their own**, and `inherited`
---is how the caller says so. A `fn` inside a `trait` is as visible as the
---trait is — writing `pub` there is a compile error — so reading the absent
---modifier as "private" reports every method of every public trait as
---internal.
---
---That is the third time this tool has met the same construct and the third
---language it has had to be told about: C#'s interface, Go's interface, and
---now Rust's trait. Each spells it differently and each means the same
---thing — *this declaration exists in order to be published* — which is
---worth noticing as a pattern rather than fixing three times by accident.
---@param node TSNode
---@param src string
---@param inherited boolean? Visibility of the enclosing trait, when there is one.
---@return boolean
local function is_internal(node, src, inherited)
  local vis = child_of(node, "visibility_modifier")
  if not vis then
    if inherited ~= nil then
      return inherited
    end
    return true
  end
  -- `pub` alone is the whole modifier; anything longer is `pub(...)`.
  return text_of(vis, src):gsub("%s+", "") ~= "pub"
end

---@param node TSNode? `parameters`
---@param src string
---@return string[]
local function param_names(node, src)
  local out = {}
  if not node then
    return out
  end
  for child in node:iter_children() do
    local kind = child:type()
    if kind == "parameter" then
      local id = child_of(child, "identifier")
      if id then
        out[#out + 1] = text_of(id, src)
      else
        -- A pattern rather than a name: `fn f((a, b): (u8, u8))`. Recorded
        -- as written so the arity stays true.
        out[#out + 1] = (text_of(child, src):gsub("%s+", " "))
      end
    elseif kind == "self_parameter" then
      -- `&self` is bound by the method call, exactly as Python's `self` is,
      -- and is dropped for the same reason: it is not part of the signature
      -- a caller writes.
      local _ = child
    end
  end
  return out
end

---@param path string
---@return Documentation.Header
function M.parse_header(path)
  local empty = { module = nil, summary = "", body = "", tags = {} }
  local src = read(path)
  if not src then
    return empty
  end
  local root = parse(src)
  if not root then
    return empty
  end
  local module = module_path_of(path)
  local _, inner = doc_comments(root, src)
  if #inner == 0 then
    -- A module with no `//!` block still has an identity worth recording.
    return { module = module, summary = "", body = "", tags = {} }
  end
  while inner[#inner] == "" do
    table.remove(inner)
  end
  local prose = table.concat(inner, "\n")
  return {
    module = module,
    summary = require("documentation.core.scan").split_summary(prose),
    body = prose,
    tags = {},
  }
end

---This backend returns call sites. See `Documentation.LangBackend.emits_calls`.
M.emits_calls = true

---A method or associated function needs `self.`, `Self::` or its type; a
---bare name never reaches one. See `Documentation.LangBackend.methods_need_receiver`.
M.methods_need_receiver = true

---@param path string
---@return Documentation.FunctionInfo[], Documentation.RawCall[], Documentation.RawRequire[], Documentation.SymbolInfo[], table[], Documentation.EndpointSpec[], integer, Documentation.BindingSpec[]
function M.scan_file(path)
  local src = read(path)
  if not src then
    return {}, {}, {}, {}, {}, {}, 0, {}
  end
  local _, newlines = src:gsub("\n", "")
  local lines = #src == 0 and 0 or (newlines + (src:sub(-1) == "\n" and 0 or 1))

  local root = parse(src)
  if not root then
    return {}, {}, {}, {}, {}, {}, lines, {}
  end

  local outer = doc_comments(root, src)
  local split = require("documentation.core.scan").split_summary
  local self_module, self_crate = module_path_of(path)
  local fns, requires, symbols = {}, {}, {}

  -- What the call extractor needs to anchor a path, per scope key (`""` for
  -- the file, the inline module path otherwise): the `use` declarations
  -- (bound after the walk), the modules declared (`mod x;` and `mod x {}`),
  -- the types this file declares or implements at file level, and the names
  -- each `use` bound.
  local uses = {} ---@type { node: TSNode, scope: string? }[]
  local mods = {} ---@type table<string, table<string, boolean>>
  local local_types = {} ---@type table<string, boolean>
  local bindings = {} ---@type table<string, table<string, string>>

  ---The module path of `scope` (an inline module path or nil), as segments.
  ---@param scope string?
  ---@return string[]
  local function module_segments(scope)
    local out = vim.split(self_module, "::", { plain = true })
    if scope then
      vim.list_extend(out, vim.split(scope, "::", { plain = true }))
    end
    return out
  end

  ---A path as written, made absolute: `crate::`, `super::`, `self::`, a name
  ---a `use` bound, a declared module or a file-level type as its first
  ---segment. `nil` when the first segment is none of those (another crate, a
  ---prelude type, a local variable) or when this file has no module path to
  ---anchor to. `Self::` is not anchored here: see `extract_calls`.
  ---@param text string
  ---@param scope string? Inline module the path is written in.
  ---@return string?
  local function anchor(text, scope)
    if not self_module then
      return nil
    end
    -- `Vec::<u8>::new` names `Vec::new`; anything else that is not a plain
    -- path (`<T as Tr>::m`, a call result) is not one this can anchor.
    text = text:gsub("::%b<>", "")
    if text:find("[^%w_:]") then
      return nil
    end
    local segs = vim.split(text, "::", { plain = true })
    local key = scope or ""
    local first = segs[1]
    local base, i
    if first == "crate" then
      base, i = { self_crate }, 2
    elseif first == "self" then
      base, i = module_segments(scope), 2
    elseif first == "super" then
      base, i = module_segments(scope), 1
      while segs[i] == "super" do
        -- Above the crate root is not a module; `self_crate` is one segment.
        if #base <= 1 then
          return nil
        end
        table.remove(base)
        i = i + 1
      end
    elseif bindings[key] and bindings[key][first] then
      base, i = { bindings[key][first] }, 2
    elseif (mods[key] and mods[key][first]) or (not scope and local_types[first]) then
      base, i = module_segments(scope), 1
    else
      return nil
    end
    for j = i, #segs do
      base[#base + 1] = segs[j]
    end
    return table.concat(base, "::")
  end

  ---Record what one `use` tree binds in `scope`: `a::b::c` binds `c`,
  ---`a::b as d` binds `d`, `a::{self, c as e}` binds `a` and `e`; `*` binds
  ---nothing this can name. The bound value is the anchored path, or the
  ---path as written when it leaves the crate (`std::mem::swap`).
  ---@param node TSNode
  ---@param prefix string? The path of the enclosing `a::{…}` list.
  ---@param scope string?
  local function bind(node, prefix, scope)
    local key = scope or ""
    local function record(name, full)
      bindings[key] = bindings[key] or {}
      bindings[key][name] = anchor(full, scope) or full
    end
    local function join(text)
      return prefix and (prefix .. "::" .. text) or text
    end
    local kind = node:type()
    if kind == "identifier" or kind == "scoped_identifier" then
      local full = join(text_of(node, src))
      record(full:match("([^:]+)$"), full)
    elseif kind == "self" then
      if prefix then
        record(prefix:match("([^:]+)$"), prefix)
      end
    elseif kind == "use_as_clause" then
      local p, alias = node:field("path")[1], node:field("alias")[1]
      if p and alias then
        local full = p:type() == "self" and prefix or join(text_of(p, src))
        if full then
          record(text_of(alias, src), full)
        end
      end
    elseif kind == "scoped_use_list" or kind == "use_list" then
      local p = node:field("path")[1]
      local sub = p and join(text_of(p, src)) or prefix
      local list = kind == "use_list" and node or node:field("list")[1]
      if list then
        -- The `{`, `,` and `}` tokens are children too, and fall through
        -- every branch above; no `named()` check, which the standalone
        -- shim's node does not have.
        for child in list:iter_children() do
          bind(child, sub, scope)
        end
      end
    end
  end

  ---Every call site, attributed to the function whose span contains it, its
  ---callee anchored to an absolute path where this file can do that. See the
  ---header's scope section.
  ---@return Documentation.RawCall[]
  local function extract_calls()
    local out = {}
    local ok, query =
      pcall(vim.treesitter.query.parse, "rust", "(call_expression function: (_) @callee)")
    if not ok then
      return out
    end
    local fn_names = {}
    for _, fn in ipairs(fns) do
      fn_names[fn.name] = true
    end
    for _, node in query:iter_captures(root, src) do
      local srow = node:range()
      local callee = text_of(node, src)
      if not callee:find("\n") then
        local enclosing
        for _, fn in ipairs(fns) do
          if srow >= fn.line - 1 and srow <= fn.line_end - 1 then
            enclosing = fn
            break
          end
        end
        local scope = enclosing and enclosing.owner_kind == "module" and enclosing.owner or nil
        local owner = enclosing and enclosing.owner_kind ~= "module" and enclosing.owner or nil
        local member = callee:match("^self%.([%w_]+)$") or callee:match("^Self::([%w_]+)$")
        local anchored
        if member then
          -- `self.go()` and `Self::go()` are the owner's `Widget::go`, left
          -- relative: the method is declared in this impl, so in this node,
          -- and the resolver tries this node's own names first.
          if owner then
            anchored = owner .. "::" .. member
          end
        elseif callee:match("^[%w_]+$") then
          if scope and fn_names[scope .. "::" .. callee] then
            anchored = self_module
                and (table.concat(module_segments(scope), "::") .. "::" .. callee)
              or (scope .. "::" .. callee)
          else
            local bound = bindings[scope or ""] and bindings[scope or ""][callee]
            anchored = bound and bound:find("::", 1, true) and bound or nil
          end
        elseif callee:find("::", 1, true) then
          anchored = anchor(callee, scope)
        end
        out[#out + 1] =
          { callee = anchored or callee, from_fn = enclosing and enclosing.name, line = srow + 1 }
      end
    end
    return out
  end

  -- Attribute rows, so `doc_above` can step over `#[derive(…)]` between a
  -- doc comment and the item it documents.
  local attr_rows = {}
  do
    local function mark(node)
      if node:type() == "attribute_item" then
        for r = node:start(), node:end_() do
          attr_rows[r] = true
        end
        return
      end
      for child in node:iter_children() do
        mark(child)
      end
    end
    mark(root)
  end

  ---A `use` path, resolved to a module this tree might hold.
  ---
  ---**The trailing type name comes off, and capitalisation is what says
  ---so.** `use crate::a::b::Thing` imports a *type* from module
  ---`crate::a::b`; `use crate::a::b` imports the module itself. Rust cannot
  ---be asked which without resolving the crate, but its own naming
  ---convention answers reliably — types are `UpperCamelCase`, modules are
  ---`snake_case`, and rustc's default lints enforce both. The same
  ---capitalisation fact Go's whole visibility system rests on.
  ---
  ---`super::` is rewritten against this file's own module path, because
  ---`super` means the parent module and only this file knows what that is.
  ---@param text string
  ---@return string?
  local function use_target(text)
    local target = text:gsub("%s+", "")
    -- `use crate::a::{B, C};` is one edge to `crate::a`, not an edge to a
    -- module whose name contains braces. Stripping the group is the
    -- unambiguous half of this problem; the ambiguous half is below.
    target = target:gsub("::%b{}$", "")
    target = target:gsub("::%*$", "")
    -- `crate::` means *this* crate, which in a workspace is not the same
    -- crate for every file — see `module_path_of`.
    if self_crate then
      target = target:gsub("^crate::", self_crate .. "::")
      if target == "crate" then
        target = self_crate
      end
    end
    if target:match("^super::") and self_module then
      local parent = self_module:match("^(.*)::[^:]+$") or "crate"
      target = target:gsub("^super::", parent .. "::")
    elseif target:match("^self::") and self_module then
      target = target:gsub("^self::", self_module .. "::")
    end
    -- Drop trailing segments that name a type rather than a module.
    --
    -- **The lower-case half of this is not answerable and is left alone.**
    -- `use crate::util::eq_ignore_case;` imports a *function* from module
    -- `crate::util`, while `use crate::output::textwrap;` imports the
    -- *module* `textwrap` — and both are `snake_case`, so nothing in the
    -- path says which. Guessing either way is wrong half the time, so the
    -- path is kept whole and the edge simply does not resolve: it lands in
    -- `requires_external`, which is the failure that under-claims rather
    -- than the one that points at the wrong module.
    --
    -- Measured on `clap-rs/clap`: 273 of 319 crate-internal uses resolve to
    -- a node, and this is most of the remainder.
    while true do
      local head, last = target:match("^(.*)::([^:]+)$")
      if not head or not last:sub(1, 1):match("%u") then
        break
      end
      target = head
    end
    return target ~= "" and target or nil
  end

  ---@param node TSNode
  ---@param scope string? Enclosing inline module or type, for a qualified name.
  ---@param inherited boolean? The enclosing trait's visibility, when inside one.
  ---@param kind Documentation.ScopeKind? What `scope` is, when there is one. Rust is the language that most needs the distinction kept: `x::helper`, `Widget::new` and `Doer::go` are written identically and are an inline module's function, an inherent method and a trait method.
  local function record_function(node, scope, inherited, kind)
    local name_node = child_of(node, "identifier")
    if not name_node then
      return
    end
    local bare = text_of(name_node, src)
    local qualified = scope and (scope .. "::" .. bare) or bare
    local names = param_names(child_of(node, "parameters"), src)
    local prose = doc_above(outer, node:start(), attr_rows)
    fns[#fns + 1] = {
      name = qualified,
      signature = qualified .. "(" .. table.concat(names, ", ") .. ")",
      line = node:start() + 1,
      line_end = node:end_() + 1,
      summary = split(prose),
      body = prose,
      params = {},
      returns = {},
      internal = is_internal(node, src, inherited),
      owner = kind and scope or nil,
      owner_kind = scope and kind or nil,
      see = {},
      overload = {},
      todo = {},
      bug = {},
      test = {},
    }
  end

  ---@param node TSNode
  ---@param scope string?
  local function record_type(node, scope)
    local name_node = child_of(node, "type_identifier")
    if not name_node then
      return
    end
    local bare = text_of(name_node, src)
    local prose = doc_above(outer, node:start(), attr_rows)
    symbols[#symbols + 1] = {
      name = scope and (scope .. "::" .. bare) or bare,
      kind = "table",
      detail = (node:type():gsub("_item$", "")),
      summary = split(prose),
      line = node:start() + 1,
    }
    -- A trait's methods are its whole content — the same fact C# and Go both
    -- taught, twice, on the same construct.
    local body = child_of(node, "declaration_list")
    if body and node:type() == "trait_item" then
      local trait_internal = is_internal(node, src)
      for member in body:iter_children() do
        if member:type() == "function_signature_item" or member:type() == "function_item" then
          record_function(member, bare, trait_internal, "trait")
        end
      end
    end
  end

  ---@param node TSNode Any item container.
  ---@param scope string? Enclosing inline module path.
  local function walk(node, scope)
    for child in node:iter_children() do
      local kind = child:type()

      if kind == "use_declaration" then
        local spec = child_of(child, "scoped_identifier")
          or child_of(child, "scoped_use_list")
          or child_of(child, "use_as_clause")
          or child_of(child, "identifier")
        if spec then
          local target = use_target(text_of(spec, src))
          if target then
            requires[#requires + 1] = { module = target, line = child:start() + 1 }
          end
        end
        local argument = child:field("argument")[1]
        if argument then
          uses[#uses + 1] = { node = argument, scope = scope }
        end
      elseif kind == "function_item" then
        -- At file top level `scope` is nil and this is a free function; inside
        -- `mod x { … }` it is the inline module path, which is the one owning
        -- scope in this language that is not a type.
        record_function(child, scope, nil, scope and "module" or nil)
      elseif
        kind == "struct_item"
        or kind == "enum_item"
        or kind == "trait_item"
        or kind == "union_item"
        or kind == "type_item"
      then
        record_type(child, scope)
        local name_node = child_of(child, "type_identifier")
        if name_node and not scope then
          local_types[text_of(name_node, src)] = true
        end
      elseif kind == "impl_item" then
        -- The methods belong to the type, not to the file: `Widget::new`.
        -- This is the owning-scope shape Phase 0 named, answered by
        -- qualifying rather than by an IR field.
        --
        -- **The `type` field, not the first type name.** `impl Doer for
        -- Widget` names the trait first, and reading that recorded every
        -- trait impl's methods as `Doer::go` — the trait declaration's own
        -- name, once more per impl. `impl<T> Foo<T>` has a `generic_type`
        -- there, which hid the owner entirely.
        local ty = child:field("type")[1]
        if ty and ty:type() == "generic_type" then
          ty = ty:field("type")[1]
        end
        if ty and ty:type() == "scoped_type_identifier" then
          ty = ty:field("name")[1]
        end
        local owner = ty and ty:type() == "type_identifier" and text_of(ty, src) or scope
        if owner and not scope then
          local_types[owner] = true
        end
        local body = child_of(child, "declaration_list")
        if body then
          for member in body:iter_children() do
            if member:type() == "function_item" then
              -- `impl` rather than the type's own `struct`/`enum` kind: the
              -- block is what groups these, and one type can have several.
              record_function(member, owner, nil, "impl")
            end
          end
        end
      elseif kind == "mod_item" then
        local name_node = child_of(child, "identifier")
        local body = child_of(child, "declaration_list")
        if name_node then
          local bare = text_of(name_node, src)
          local inner_scope = scope and (scope .. "::" .. bare) or bare
          mods[scope or ""] = mods[scope or ""] or {}
          mods[scope or ""][bare] = true
          if body then
            -- `mod x { … }`: an inline module, the "one file, many modules"
            -- case. Its contents are recorded under `x::`, which is what a
            -- reader would search for and what `use` would write.
            local prose = doc_above(outer, child:start(), attr_rows)
            symbols[#symbols + 1] = {
              name = inner_scope,
              kind = "table",
              detail = "mod",
              summary = split(prose),
              line = child:start() + 1,
            }
            walk(body, inner_scope)
          else
            -- `mod x;`: a declaration that the module lives in another file.
            -- That is a require edge and one of the few Rust offers that
            -- names a file rather than a path through the module tree.
            if self_module then
              requires[#requires + 1] = {
                module = self_module .. "::" .. bare,
                line = child:start() + 1,
              }
            end
          end
        end
      elseif kind == "const_item" or kind == "static_item" then
        local name_node = child_of(child, "identifier")
        if name_node then
          local prose = doc_above(outer, child:start(), attr_rows)
          symbols[#symbols + 1] = {
            name = scope and (scope .. "::" .. text_of(name_node, src)) or text_of(name_node, src),
            kind = kind == "const_item" and "constant" or "binding",
            detail = (text_of(child, src):gsub("%s+", " ")):sub(1, 60),
            summary = split(prose),
            line = child:start() + 1,
          }
        end
      end
    end
  end
  walk(root, nil)

  -- Bindings after the walk, so a `use helper::x` above its `mod helper;`
  -- still finds the child module it names.
  for _, use in ipairs(uses) do
    bind(use.node, nil, use.scope)
  end

  return fns, extract_calls(), requires, symbols, {}, {}, lines, {}
end

require("documentation.core.lang_registry").register(M.name, M)

return M
