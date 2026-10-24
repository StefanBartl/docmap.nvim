---@module 'documentation'
--- Backward-compat shim: this plugin was called documentation.nvim until
--- 2026-10-24. Existing configs with `require("documentation")` or
--- `require("documentation.xxx")` keep working through this alias.
--- New code should require "docmap" directly; this shim is scheduled for
--- removal once the old name has aged out of use.

local ok, docmap = pcall(require, "docmap")
if not ok then
  error("documentation.nvim was renamed to docmap.nvim: " .. tostring(docmap), 0)
end

vim.notify_once(
  "[docmap] documentation.nvim was renamed to docmap.nvim — update your require()/plugin spec to docmap.nvim",
  vim.log.levels.WARN,
  { title = "docmap.nvim" }
)

return docmap
