-- TESTS/harness_spec.lua — the cleanup helpers of TESTS/harness.lua.
--
-- The specs share one editor (`isolated = "none"`), so a cleanup helper that
-- silently does nothing turns into state-guard failures in unrelated specs.

return function(H)
  local eq, ok = H.eq, H.ok

  -- `opts.vars`: the values are taken at snapshot time. `vim.deepcopy(vim.g)`
  -- would copy the proxy's metatable and read the live value at restore time,
  -- making the restore a no-op.
  vim.g.docmap_harness_spec_set = 1
  vim.g.docmap_harness_spec_unset = nil
  local opts = { vars = { "docmap_harness_spec_set", "docmap_harness_spec_unset" } }
  local snap = H.snapshot(opts)
  vim.g.docmap_harness_spec_set = 2
  vim.g.docmap_harness_spec_unset = "leaked"
  H.restore(snap, opts)
  eq(vim.g.docmap_harness_spec_set, 1, "restore: a changed vim.g key gets its old value back")
  eq(vim.g.docmap_harness_spec_unset, nil, "restore: a key unset at snapshot time is unset again")
  vim.g.docmap_harness_spec_set = nil

  -- `with_restore`: the cleanup runs when the body raises, and the body's
  -- error still reaches the caller unchanged.
  local cmd = "DocmapHarnessSpecLeak"
  local wins_before = #vim.api.nvim_list_wins()
  local ok_run, err = pcall(H.with_restore, { vars = { "docmap_harness_spec_set" } }, function()
    vim.api.nvim_create_user_command(cmd, function() end, {})
    vim.cmd("new")
    vim.g.docmap_harness_spec_set = "leaked"
    error("boom", 0)
  end)
  eq(ok_run, false, "with_restore: the body's error is raised again")
  eq(err, "boom", "with_restore: ...unchanged")
  eq(
    vim.api.nvim_get_commands({ builtin = false })[cmd],
    nil,
    "with_restore: user command removed on error"
  )
  eq(#vim.api.nvim_list_wins(), wins_before, "with_restore: window closed on error")
  eq(vim.g.docmap_harness_spec_set, nil, "with_restore: vim.g key restored on error")

  local ran = false
  H.with_restore(nil, function(s)
    ran = type(s) == "table" and s.bufs ~= nil
  end)
  ok(ran, "with_restore: the body runs and gets the snapshot")
end
