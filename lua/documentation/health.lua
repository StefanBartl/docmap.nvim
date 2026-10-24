---@module 'documentation.health'
--- Backward-compat shim for `:checkhealth documentation` (plugin renamed to
--- docmap.nvim on 2026-10-24). Delegates to the real health check.
return require("docmap.health")
