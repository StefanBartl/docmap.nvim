# Fixture ruleset for the `rules/plan` and `rules/validate` routes

Each manual rule here takes one path through `rules.nvim`'s planner; the project's `.rules.json` sets a small
`max_context_bytes`, a deny entry and a family scope for `SCP`.

## Sent

#### `AGT-01` — its own scope

```rule
id = "AGT-01",
severity = "recommended",
agent = { question = "Is every require guarded?", include = { "lua/a.lua", "lua/b.lua" } },
```

Every `require` of an optional module is wrapped in `pcall`.

#### `AGT-08` — a scope capped by max_files

```rule
id = "AGT-08",
severity = "nice-to-have",
agent = { include = { "lua/*.lua" }, max_files = 1 },
```

#### `SCP-01` — the scope of its family

```rule
id = "SCP-01",
severity = "recommended",
```

Modules return a table.

## Not sent

#### `AGT-02` — a scope the deny list empties

```rule
id = "AGT-02",
severity = "critical",
agent = { include = { ".env", "keys/**" } },
```

#### `AGT-03` — no scope at all

```rule
id = "AGT-03",
severity = "recommended",
```

#### `AGT-04` — more context than the limit

```rule
id = "AGT-04",
severity = "recommended",
agent = { include = { "lua/big.lua" } },
```

#### `AGT-05` — only a binary file

```rule
id = "AGT-05",
severity = "recommended",
agent = { include = { "lua/blob.bin" } },
```

## With a check

#### `AGT-06` — a grep

```rule
id = "AGT-06",
severity = "recommended",
check = { type = "grep", pattern = "require%(", include = "%.lua$" },
```

#### `AGT-07` — a predicate, which planning never runs

```rule
id = "AGT-07",
severity = "recommended",
check = {
  type = "lua_predicate",
  fn = function()
    error("a predicate must never run while a plan is made")
  end,
},
```
