---@module 'docmap.health'
--- The entry point Neovim looks for when you type `:checkhealth documentation`.
---
--- Neovim resolves that name to `lua/docmap/health.lua`, and nothing
--- else: it does not search sub-namespaces. The actual checks live in
--- `docmap.editor.health`, on the editor side of the core/editor split,
--- because every one of them is about the editing session -- dependencies on
--- the runtimepath, the treesitter parser, which root `:DocMap` resolved. That
--- is the right home for them, but it left `:checkhealth documentation` -- the
--- spelling the README, the vimdoc and three other docs tell people to use --
--- resolving to nothing at all.
---
--- Hence this file: the name Neovim needs, forwarding to where the checks
--- live. Nothing else belongs here; add checks to
--- `docmap/editor/health.lua`.

local M = {}

---Entry point for `:checkhealth documentation`.
function M.check()
  require("docmap.editor.health").check()
end

return M
