---@module 'documentation.bindings.usrcmds.open'
--- `:DocMap open` — open the generated page in the system browser.
---
--- Also the home of the opener itself, which `graph` needs: the page's whole
--- navigable state lives in its URL fragment, so "open the deps graph for
--- module X" is this action with a hash appended rather than a second
--- rendering path. Keeping both here means the fragment-vs-filesystem-path
--- rule below is stated once.

local M = {}

---Build the opener for `ctx`.
---
---A closure rather than a function taking the whole context, because it is
---built once in `usrcmds/init.lua` and then handed *to* the context — every
---action that opens the page uses the same one.
---@param cfg Documentation.Opts
---@param notify table
---@param command_name string
---@param generate? fun()  makes the map; given, a missing map is offered to be made (and then opened)
---@return fun(hash: string?): boolean
function M.opener(cfg, notify, command_name, generate)
  ---@param hash string? Fragment including the leading "#", or nil for the default view.
  ---@param made? boolean  the map was made for this call: do not offer it again
  ---@return boolean opened
  local function open(hash, made)
    local target = cfg.root .. "/" .. (cfg.out_dir or "docs/map") .. "/index.html"
    if vim.uv.fs_stat(target) == nil then
      if generate and not made then
        require("documentation.ask").yesno(
          ("No map generated yet. Generate it now (:%s) and open it?"):format(command_name),
          "generate and open",
          function(accepted)
            if accepted then
              generate()
              open(hash, true)
            end
          end
        )
        return false
      end
      notify.warn("No map generated yet — run :" .. command_name .. " first.")
      return false
    end

    -- Prefer the server when one is running: same page, but over an origin
    -- where `fetch` is allowed, which is the only way the History tab can
    -- ask anything. Without a server this stays exactly what it always was.
    local serve = require("documentation.editor.serve")
    local info = serve.info()
    if info then
      require("lib.nvim.cross.open_default")(info.url .. (hash or ""))
      return true
    end

    -- A fragment is only meaningful on a URL. Appended to a bare filesystem
    -- path it becomes part of the filename, and every opener this dispatches
    -- to (`explorer.exe`, `open`, `xdg-open`) then looks for a file called
    -- `index.html#tab=…` and fails silently. The plain no-fragment path stays
    -- a filesystem path, which is what it has always been.
    local url = hash and (vim.uri_from_fname(target) .. hash) or target
    require("lib.nvim.cross.open_default")(url)
    return true
  end
  return function(hash)
    return open(hash)
  end
end

---@param ctx Documentation.Bindings.Ctx
function M.run(ctx)
  ctx.open_map()
end

return M
