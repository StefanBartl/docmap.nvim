-- TESTS/map_offer_spec.lua — a command that needs the generated page and finds none offers to make it (instead of telling
-- the person to run `:DocMap` first), then opens what was asked for. No leaves everything as it was.

return function(H)
  local eq, ok = H.eq, H.ok

  local open = require("documentation.bindings.usrcmds.open")
  local ask = require("documentation.ask")

  ---@return table cfg
  ---@return string target
  local function fresh()
    local root = vim.fn.tempname()
    vim.fn.mkdir(root, "p")
    return { root = root, out_dir = "docs/map" }, root .. "/docs/map/index.html"
  end

  local warned, asked, opened, generated
  local real_open_default = package.loaded["lib.nvim.cross.open_default"]
  local notify = {
    warn = function(msg)
      warned[#warned + 1] = msg
    end,
  }

  ---@param target string
  ---@return fun()
  local function make_map(target)
    return function()
      generated = generated + 1
      vim.fn.mkdir(vim.fs.dirname(target), "p")
      H.write(target, { "<html></html>" })
    end
  end

  ---@param answer boolean
  local function answering(answer)
    warned, asked, opened, generated = {}, {}, {}, 0
    ask.confirm = function(question, yes_label, cb)
      asked[#asked + 1] = { question = question, yes = yes_label }
      cb(answer)
    end
    package.loaded["lib.nvim.cross.open_default"] = function(url)
      opened[#opened + 1] = url
    end
  end

  local function restore()
    ask.confirm = nil
    package.loaded["lib.nvim.cross.open_default"] = real_open_default
  end

  -- Yes: the map is made, then opened
  do
    answering(true)
    local cfg, target = fresh()
    local opener = open.opener(cfg, notify, "DocMap", make_map(target))
    eq(
      opener(),
      false,
      "the call that found no map reports it did not open (the opening follows the answer)"
    )
    eq(#asked, 1, "the missing map is asked about, once")
    ok(
      asked[1].question:find("No map generated yet", 1, true) ~= nil,
      "the question says what is missing"
    )
    ok(asked[1].question:find(":DocMap", 1, true) ~= nil, "and names the command")
    eq(generated, 1, "Yes makes the map")
    eq(#opened, 1, "and opens what was asked for")
    eq(opened[1], target, "the page itself")
    eq(#warned, 0, "nothing is told as a warning")
    restore()
  end

  -- with a fragment: the same, opened with the fragment
  do
    answering(true)
    local cfg, target = fresh()
    local opener = open.opener(cfg, notify, "DocMap", make_map(target))
    opener("#tab=deps")
    eq(#opened, 1)
    ok(opened[1]:sub(-9) == "#tab=deps", "the fragment of the request survives the detour")
    restore()
  end

  -- No: nothing is made, nothing opened
  do
    answering(false)
    local cfg, target = fresh()
    local opener = open.opener(cfg, notify, "DocMap", make_map(target))
    opener()
    eq(#asked, 1)
    eq(generated, 0, "No makes nothing")
    eq(#opened, 0, "and opens nothing")
    ok(vim.uv.fs_stat(target) == nil, "the page is not there")
    restore()
  end

  -- a generation that made no page: told once, not asked again
  do
    answering(true)
    local cfg = fresh()
    local opener = open.opener(cfg, notify, "DocMap", function()
      generated = generated + 1
    end)
    opener()
    eq(#asked, 1, "asked once")
    eq(#warned, 1, "and the old hint is what is left when the map still is not there")
    ok(warned[1]:find("run :DocMap first", 1, true) ~= nil)
    restore()
  end

  -- without a way to make it (no generate given), the old hint stands
  do
    answering(true)
    local cfg = fresh()
    local opener = open.opener(cfg, notify, "DocMap")
    opener()
    eq(#asked, 0)
    eq(#warned, 1)
    restore()
  end

  -- the map is there: nothing is asked
  do
    answering(true)
    local cfg, target = fresh()
    make_map(target)()
    generated = 0
    open.opener(cfg, notify, "DocMap", make_map(target))()
    eq(#asked, 0, "nothing is asked when the map exists")
    eq(#opened, 1)
    restore()
  end
end
