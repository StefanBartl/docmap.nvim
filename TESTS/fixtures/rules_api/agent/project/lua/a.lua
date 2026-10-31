local M = {}

function M.load(name)
  local mod = require("x")
  return mod[name]
end

return M
