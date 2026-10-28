---@module 'docmap.ask'
--- A yes/no question for the commands that would otherwise only tell the person what to type first ("run :DocMap
--- first"): the question, then the thing that was asked for. Asked through lib.nvim's shared dialog
--- (`dialog.yesno`: "No" first and focused, `n`/`y` are keys, a native question when no float can open); the answer
--- comes by callback, once, and `cb(true)` only for a yes.
---
--- `M.confirm` is the seam the specs replace: a spec that asks a question answers it itself, nothing opens.

local M = {}

---@type (fun(question: string, yes_label: string, cb: fun(accepted: boolean)))|nil
M.confirm = nil

---@param question string
---@param yes_label string  shown as "Yes, <yes_label>"
---@param cb fun(accepted: boolean)
function M.yesno(question, yes_label, cb)
  if M.confirm then
    return M.confirm(question, yes_label, cb)
  end
  require("lib.nvim.ui.dialog").yesno(question, yes_label, cb)
end

return M
