-- TESTS/ask_dialog_spec.lua -- `docmap.ask.yesno` asks through lib.nvim's shared dialog and passes the boolean on;
-- a replaced `M.confirm` (the seam of the other specs) still wins.

---@diagnostic disable: duplicate-set-field
-- Why: the spec replaces the dialog's `yesno` and the seam with test doubles on purpose.

return function(H)
  local eq = H.eq
  local ask = require("docmap.ask")
  local dialog = require("lib.nvim.ui.dialog")
  local orig_yesno, orig_confirm = dialog.yesno, ask.confirm

  local good, failure = pcall(function()
    local seen
    dialog.yesno = function(question, label, cb)
      seen = { question = question, label = label, cb = cb }
    end
    local got = {}
    ask.yesno("Run :DocMap first?", "run it", function(yes)
      got[#got + 1] = yes
    end)
    eq(seen.question, "Run :DocMap first?", "the question reaches the dialog")
    eq(seen.label, "run it", "and the label")
    seen.cb(true)
    seen.cb(false)
    eq(got[1], true, "a yes is true")
    eq(got[2], false, "a no is false")

    -- a replaced confirm answers without opening a dialog
    dialog.yesno = function()
      error("must not open")
    end
    ask.confirm = function(_, _, cb)
      cb(true)
    end
    local answered
    ask.yesno("Q?", "go", function(yes)
      answered = yes
    end)
    eq(answered, true, "the seam still wins")
  end)
  dialog.yesno, ask.confirm = orig_yesno, orig_confirm
  assert(good, failure)
end
