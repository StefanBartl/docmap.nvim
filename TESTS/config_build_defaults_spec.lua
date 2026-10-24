-- TESTS/config_build_defaults_spec.lua -- what `config.build` shares with `DEFAULTS`: nothing.
--
-- `build()` runs on every keystroke of a `:DocMap` argument and hands its result to code that writes into
-- it. A table the result shares with `DEFAULTS` would carry one caller's change into every later `build()`.
-- `DEFAULTS` has only scalars today, so the spec gives it a list and a map for the length of the run.

return function(H)
  local eq, ok = H.eq, H.ok
  local cfg = require("docmap.config")
  local DEFAULTS = require("docmap.config.DEFAULTS")

  local root = (vim.fn.tempname():gsub("\\", "/"))
  vim.fn.mkdir(root .. "/lua/thing", "p")
  vim.fn.writefile({ "return {}" }, root .. "/lua/thing/init.lua")

  DEFAULTS.__spec_list = { "a", "b" }
  DEFAULTS.__spec_map = { inner = { n = 1 } }
  local ran, err = pcall(function()
    local first = cfg.build(root, {})
    ok(first.__spec_list ~= DEFAULTS.__spec_list, "a list default is a copy")
    ok(first.__spec_map ~= DEFAULTS.__spec_map, "a map default is a copy")
    ok(first.__spec_map.inner ~= DEFAULTS.__spec_map.inner, "and so is the table inside it")
    ok(vim.deep_equal(first.__spec_list, { "a", "b" }), "with the same content")

    -- a write into one result does not reach the defaults, nor the next build
    first.__spec_list[#first.__spec_list + 1] = "c"
    first.__spec_map.inner.n = 99
    ok(vim.deep_equal(DEFAULTS.__spec_list, { "a", "b" }), "the defaults keep their list")
    eq(DEFAULTS.__spec_map.inner.n, 1, "and their map")
    local second = cfg.build(root, {})
    ok(
      vim.deep_equal(second.__spec_list, { "a", "b" }),
      "the next build starts from the real defaults"
    )
    eq(second.__spec_map.inner.n, 1)

    -- the order of the layers is unchanged: derived < file/defaults < the host's table, shallow by key
    local over = cfg.build(root, { title = "mine", __spec_list = { "z" } })
    eq(over.title, "mine", "a host option beats the derived title")
    ok(vim.deep_equal(over.__spec_list, { "z" }), "and replaces a default list whole")
  end)
  DEFAULTS.__spec_list, DEFAULTS.__spec_map = nil, nil
  vim.fn.delete(root, "rf")
  if not ran then
    error(err, 0)
  end
end
