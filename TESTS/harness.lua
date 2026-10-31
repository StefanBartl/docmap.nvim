-- TESTS/harness.lua — tiny assertion helper shared by the spec files.
-- Returned to each spec by TESTS/run.lua.

local H = {}

--- Assert equality; raises a descriptive error on mismatch (caught by the runner).
---@param a any # actual
---@param b any # expected
---@param msg string|nil
function H.eq(a, b, msg)
  if a ~= b then
    error(("FAIL %s: expected %s, got %s"):format(msg or "", vim.inspect(b), vim.inspect(a)), 2)
  end
end

--- Assert a truthy value.
---@param v any
---@param msg string|nil
function H.ok(v, msg)
  if not v then
    error(("FAIL %s: expected truthy, got %s"):format(msg or "", vim.inspect(v)), 2)
  end
end

--- Create a fresh temp file path (not created on disk).
---@param suffix string|nil
---@return string
function H.tmpfile(suffix)
  return vim.fn.tempname() .. (suffix or ".tmp")
end

--- Read all lines of a file into an array (empty array if missing).
---@param path string
---@return string[]
function H.read_lines(path)
  local out = {}
  local f = io.open(path, "r")
  if not f then
    return out
  end
  for line in f:lines() do
    out[#out + 1] = line
  end
  f:close()
  return out
end

--- Make `link` lead to the existing path `target`: a symlink, or on Windows a
--- directory junction (`mklink /J`), which needs no privilege.
---
--- A junction is the only kind of link a Windows account without developer mode
--- can make, and it is the kind a Windows repro uses -- so a directory link is
--- made as one there, with the backslash spelling `mklink` insists on. A *file*
--- link on Windows needs the symlink privilege and may not be possible; the
--- caller gets `false` and decides what that means for its case.
---@param target string Existing path the link should lead to.
---@param link string Path of the link to create; its parent must exist.
---@param is_dir boolean
---@return boolean made
---@return string? how `"symlink"` or `"junction"` when made, the error otherwise.
function H.link(target, link, is_dir)
  if vim.fn.has("win32") == 1 and is_dir then
    local out = vim.fn.system({
      "cmd",
      "/C",
      "mklink",
      "/J",
      (link:gsub("/", "\\")),
      (target:gsub("/", "\\")),
    })
    if vim.v.shell_error == 0 then
      return true, "junction"
    end
    return false, vim.trim(out)
  end
  local made, err = vim.uv.fs_symlink(target, link, { dir = is_dir })
  if made then
    return true, "symlink"
  end
  return false, tostring(err)
end

--- `path` spelled the way the engine spells a project root: resolved, so a
--- Windows 8.3 short name (`RUNNER~1`) is long and `/var` on macOS is
--- `/private/var`. `vim.fn.tempname()` gives the unresolved spelling, and the
--- engine resolves the root it is handed (`config.build`); a link whose
--- *absolute* target names the project the other way counts as leading
--- outside it. Use this for the target of a link that is meant to stay inside.
---@param path string An existing path.
---@return string
function H.canonical(path)
  local real = vim.uv.fs_realpath(path)
  return real and (real:gsub("\\", "/")) or path
end

--- Write `lines` to `path`, creating its directory.
---@param path string
---@param lines string[]
function H.write(path, lines)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(lines, path)
end

--- A file's content, or `nil`.
---@param path string
---@return string?
function H.slurp(path)
  local fd = io.open(path, "rb")
  if not fd then
    return nil
  end
  local content = fd:read("*a")
  fd:close()
  return content
end

---@param list any[]
---@return table<any, true>
local function set_of(list)
  local s = {}
  for _, v in ipairs(list) do
    s[v] = true
  end
  return s
end

--- What a spec may leave behind, taken at its start; hand it to `H.restore`
--- at its end. The specs share one editor (`isolated = "none"`), and the
--- state guard of testing.nvim (`.testing.lua`, `guards.state = "error"`)
--- fails a spec that leaves buffers, windows, tabs, user commands or
--- autocmds behind.
---@return table snapshot
function H.snapshot()
  local autocmds = {}
  for _, a in ipairs(vim.api.nvim_get_autocmds({})) do
    if a.id then
      autocmds[a.id] = true
    end
  end
  local bufs = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    bufs[buf] = vim.api.nvim_buf_get_name(buf)
  end
  return {
    bufs = bufs,
    wins = set_of(vim.api.nvim_list_wins()),
    tabs = set_of(vim.api.nvim_list_tabpages()),
    cmds = vim.api.nvim_get_commands({ builtin = false }),
    autocmds = autocmds,
    g = vim.deepcopy(vim.g),
  }
end

--- Wipe every buffer that was not there when `snap` was taken. Unlike
--- `%bwipeout!` this keeps the buffers the spec found, so the editor does not
--- have to make a fresh `[No Name]` buffer (which would outlive the spec).
--- `:edit` reuses an empty `[No Name]` buffer for the file it opens; such a
--- buffer is emptied and loses its name again instead of being wiped.
---@param snap table from `H.snapshot()`
function H.wipe_new(snap)
  for buf, name in pairs(snap.bufs) do
    if vim.api.nvim_buf_is_valid(buf) and name == "" and vim.api.nvim_buf_get_name(buf) ~= "" then
      vim.api.nvim_buf_call(buf, function()
        -- `:0file` keeps the old name as a new (alternate) buffer: wiped below.
        vim.cmd("silent! 0file")
      end)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
      vim.bo[buf].modified = false
      vim.bo[buf].filetype = ""
    end
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if not snap.bufs[buf] and vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end
end

--- Put the editor back the way `snap` found it: close the tabs and windows
--- the spec opened, wipe its buffers, delete the user commands it (or a
--- `setup()` it called) defined, and delete its autocmds. Only autocmds in a
--- group whose name starts with one of `opts.groups`, or groupless ones on an
--- event in `opts.events`, are deleted: the editor's own runtime creates
--- autocmds lazily (LSP, filetypes) that must survive for later specs.
--- `opts.vars` names `vim.g` keys to put back.
---@param snap table from `H.snapshot()`
---@param opts? { groups?: string[], events?: string[], vars?: string[] }
function H.restore(snap, opts)
  opts = opts or {}
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    if not snap.tabs[tab] and #vim.api.nvim_list_tabpages() > 1 then
      vim.cmd.tabclose({ args = { vim.api.nvim_tabpage_get_number(tab) }, bang = true })
    end
  end
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if not snap.wins[win] and vim.api.nvim_win_is_valid(win) and #vim.api.nvim_list_wins() > 1 then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
  H.wipe_new(snap)
  for name in pairs(vim.api.nvim_get_commands({ builtin = false })) do
    if not snap.cmds[name] then
      pcall(vim.api.nvim_del_user_command, name)
    end
  end
  local groups, events = opts.groups or {}, set_of(opts.events or {})
  for _, a in ipairs(vim.api.nvim_get_autocmds({})) do
    if a.id and not snap.autocmds[a.id] then
      local mine = false
      if a.group_name then
        for _, prefix in ipairs(groups) do
          mine = mine or a.group_name:sub(1, #prefix) == prefix
        end
      else
        mine = events[a.event] == true
      end
      if mine then
        pcall(vim.api.nvim_del_autocmd, a.id)
      end
    end
  end
  for _, name in ipairs(opts.vars or {}) do
    vim.g[name] = snap.g[name]
  end
end

return H
