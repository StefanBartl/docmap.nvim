-- TESTS/resolve_relative_spec.lua — deps.resolve_relative
--
-- A pure function, so it is tested everywhere rather than only where a
-- javascript parser happens to be installed — which matters, because this is
-- the piece that decides whether a JS import is a dependency edge or an
-- external module, and getting it wrong is silent in both directions.

return function(H)
  local eq = H.eq
  local deps = require("docmap.core.deps")

  ---A path index shaped like `deps.path_index` builds one.
  local by_path = {
    ["src/util.js"] = "src/util.js",
    ["src/parse.ts"] = "src/parse.ts",
    ["src/deep/index.ts"] = "src/deep/index.ts",
    ["lib/thing.mjs"] = "lib/thing.mjs",
    ["lua/pgl"] = "lua/pgl",
  }

  local function from(path, spec)
    return deps.resolve_relative(by_path, path, spec)
  end

  eq(from("src/parse.ts", "./util.js"), "src/util.js", "resolve: a sibling by exact filename")

  -- The extensionless form is what TypeScript sources actually write, and the
  -- candidate extensions come from the registry rather than a list here, so a
  -- future backend resolves without this function learning its name.
  eq(from("src/parse.ts", "./util"), "src/util.js", "resolve: extension appended when omitted")

  eq(
    from("src/parse.ts", "./deep"),
    "src/deep/index.ts",
    "resolve: a directory resolves through its index file"
  )

  eq(from("src/parse.ts", "../lib/thing.mjs"), "lib/thing.mjs", "resolve: `..` climbs out")
  eq(from("src/deep/index.ts", "../util.js"), "src/util.js", "resolve: ... from a nested file too")

  -- A bare specifier names a package or another project. Guessing that
  -- `utils` might mean a file in this tree is exactly the resolution this
  -- pipeline declines to invent elsewhere.
  eq(from("src/parse.ts", "react"), nil, "resolve: a bare specifier is never resolved locally")
  eq(from("src/parse.ts", "plenary.async"), nil, "resolve: ... including a dotted one")
  eq(
    from("lua/pgl/init.lua", "pgl.helper"),
    nil,
    "resolve: a Lua module path is left to the module index, not treated as a file"
  )

  -- Absent is absent. A specifier pointing at nothing must stay external
  -- rather than resolving to something nearby.
  eq(from("src/parse.ts", "./missing.js"), nil, "resolve: an unknown target resolves to nothing")

  -- Climbing above the root is meaningless, and must not wrap around into a
  -- match somewhere else in the tree.
  eq(
    from("src/parse.ts", "../../../etc/passwd"),
    nil,
    "resolve: climbing past the root finds nothing"
  )

  -- A root layout (`source = "."`) gives every id a `./` prefix, which the
  -- `.`-segment normalisation used to drop: `./pkg/helper.py` was looked up as
  -- `pkg/helper.py` and no relative import of such a project resolved.
  local rooted = {
    ["./pkg/helper.py"] = "./pkg/helper.py",
    ["./pkg/sub/deep.py"] = "./pkg/sub/deep.py",
  }
  eq(
    deps.resolve_relative(rooted, "./pkg/widget.py", "./helper"),
    "./pkg/helper.py",
    "resolve: a root-layout id keeps its ./ prefix"
  )
  eq(
    deps.resolve_relative(rooted, "./pkg/sub/deep.py", "../helper"),
    "./pkg/helper.py",
    "resolve: ...climbing out of a subpackage too"
  )
  -- The base is the importing *file*: from a package's own `__init__.py`,
  -- `./helper` is beside it, not beside the package directory.
  eq(
    deps.resolve_relative(rooted, "./pkg/__init__.py", "./helper"),
    "./pkg/helper.py",
    "resolve: relative to the package file, not the directory above it"
  )
  -- One `..` more than there are directories names something above the
  -- tree; with the `./` re-prefix it used to land on a root-level file.
  rooted["./b.py"] = "./b.py"
  eq(
    deps.resolve_relative(rooted, "./pkg/a.py", "../../b"),
    nil,
    "resolve: climbing past a root layout's top finds nothing"
  )
end
