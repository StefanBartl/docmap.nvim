-- TESTS/documentation_alias_spec.lua — lua/documentation/{init,health}.lua
--
-- docmap.nvim was called documentation.nvim until 2026-10-24. A real public
-- plugin, embedded by other people's lazy.nvim specs as
-- `require("documentation")`/`require("documentation").setup({})` and
-- `:checkhealth documentation` — breaking that the day the Lua module moved
-- would be a silent config failure for anyone who has not yet repointed
-- their spec at "docmap". These two files exist only to keep it working.
--
-- Remove `lua/documentation/init.lua` and `lua/documentation/health.lua` and
-- this spec goes red: `require("documentation")` falls through to whatever
-- Neovim finds next on the runtimepath (nothing, in CI) instead of the real
-- module.

return function(H)
  local eq, ok = H.eq, H.ok

  -- Fresh requires every time: another spec earlier in the run may already
  -- have pulled "docmap"/"documentation" into package.loaded, which would
  -- hide a broken shim behind an already-cached table.
  package.loaded["documentation"] = nil
  package.loaded["documentation.health"] = nil
  package.loaded["docmap"] = nil
  package.loaded["docmap.health"] = nil

  local docmap = require("docmap")
  package.loaded["documentation"] = nil -- require it fresh, not docmap's own cache entry

  local aliased = require("documentation")
  ok(aliased ~= nil, "documentation: require('documentation') resolves to something")
  eq(
    aliased,
    docmap,
    "documentation: require('documentation') is the SAME table as require('docmap')"
  )
  eq(type(aliased.setup), "function", "documentation: .setup survives the alias")
  eq(type(aliased.generate), "function", "documentation: .generate survives the alias")

  package.loaded["docmap.health"] = nil
  local health = require("docmap.health")
  package.loaded["documentation.health"] = nil
  local aliased_health = require("documentation.health")
  eq(
    aliased_health,
    health,
    "documentation.health: require('documentation.health') is the SAME table as require('docmap.health')"
  )
end
