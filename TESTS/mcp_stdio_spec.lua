-- TESTS/mcp_stdio_spec.lua — the stdio transport of the MCP server as a real process.
--
-- `mcp_spec.lua` drives `protocol.dispatch` and never the read loop, which is how a Windows-only buffering defect (the
-- answer to `initialize` stayed in the C buffer until stdin closed, and the client ran into its connect timeout) went
-- unnoticed. Here `scripts/mcp_server.lua` runs as a child with stdin held OPEN: each answer has to arrive while the
-- client is still waiting, not when it hangs up. The scan before the loop makes the start slow (seconds), so this
-- is one case that covers the whole conversation.
---@diagnostic disable: need-check-nil

return function(H)
  local eq, ok = H.eq, H.ok
  local here = vim.fs.dirname(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p"))
  local root = vim.fs.dirname(here)

  local lib = vim.api.nvim_get_runtime_file("lua/lib/nvim", false)[1]
  if not lib then
    H.ok(true, "mcp stdio: lib.nvim is not on the runtimepath here, nothing to start")
    return
  end
  local lib_dir = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(lib)))

  local lines, errs, exited = {}, {}, nil
  local pending = ""
  local proc = vim.system(
    { vim.v.progpath, "--headless", "-u", "NONE", "-l", "scripts/mcp_server.lua" },
    {
      cwd = root,
      env = { LIB_NVIM_DIR = lib_dir },
      stdin = true,
      stdout = function(_, data)
        if data then
          pending = pending .. data
          while true do
            local nl = pending:find("\n", 1, true)
            if not nl then
              break
            end
            lines[#lines + 1] = pending:sub(1, nl - 1)
            pending = pending:sub(nl + 1)
          end
        end
      end,
      stderr = function(_, data)
        if data then
          errs[#errs + 1] = data
        end
      end,
    },
    function(obj)
      exited = obj.code
    end
  )

  ---Send one line and wait for the answer while stdin stays open.
  ---@param text string
  ---@return table decoded
  local function ask(text)
    local before = #lines
    proc:write(text .. "\n")
    local got = vim.wait(20000, function()
      return #lines > before
    end, 20)
    ok(got, "mcp stdio: an answer arrives while stdin is still open (" .. text:sub(1, 40) .. ")")
    return got and vim.json.decode(lines[#lines]) or {}
  end

  local init = ask(
    '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"spec","version":"0"}}}'
  )
  eq(init.id, 1, "mcp stdio: initialize is answered under its id")
  ok(init.result ~= nil, "mcp stdio: with a result")

  -- one hostile line (an id that cannot be written back) does not end the process
  local bad = ask('{"jsonrpc":"2.0","id":1e999,"method":"ping"}')
  eq(
    bad.error and bad.error.code,
    -32600,
    "mcp stdio: an id of infinity is an invalid request, not a crash"
  )
  local after = ask('{"jsonrpc":"2.0","id":2,"method":"ping"}')
  eq(after.id, 2, "mcp stdio: and the server still answers afterwards")

  proc:write(nil) -- close stdin: the normal end
  local done = vim.wait(30000, function()
    return exited ~= nil
  end, 20)
  ok(done, "mcp stdio: the process ends when stdin closes")
  eq(exited, 0, "mcp stdio: with exit code 0 (stderr: " .. table.concat(errs):sub(1, 200) .. ")")
  eq(pending, "", "mcp stdio: nothing but whole lines on stdout")
end
