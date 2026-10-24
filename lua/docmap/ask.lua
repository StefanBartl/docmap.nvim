---@module 'docmap.ask'
--- A yes/no question for the commands that would otherwise only tell the person what to type first ("run :DocMap
--- first"): the question, then the thing that was asked for. `ui.kit.confirm` when it is there, `vim.ui.select` as the
--- fallback; the answer comes by callback, once, and `cb(true)` only for a yes. No is the first choice of the fallback.
---
--- `M.confirm` is the seam the specs replace: a spec that asks a question answers it itself, nothing opens.

local M = {}

---@type (fun(question: string, yes_label: string, cb: fun(accepted: boolean)))|nil
M.confirm = nil

---@param question string
---@param yes_label string  shown as "Yes, <yes_label>" in the fallback
---@param cb fun(accepted: boolean)
function M.yesno(question, yes_label, cb)
  if M.confirm then
    return M.confirm(question, yes_label, cb)
  end
  local ok, kit = pcall(require, "ui.kit")
  if ok and type(kit) == "table" and type(kit.confirm) == "function" then
    local shown = pcall(kit.confirm, {
      question = question,
      on_answer = function(yes)
        cb(yes == true)
      end,
    })
    if shown then
      return
    end
  end
  vim.ui.select({ "No", "Yes, " .. yes_label }, { prompt = question }, function(_, index)
    cb(index == 2)
  end)
end

return M
