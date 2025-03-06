local multiplexer_utils = {}

---@class multiplexer.exec_opt
---@field async boolean

---@param command string[]
---@param callback fun(p: vim.SystemCompleted): any
---@param opts? multiplexer.exec_opt
---@return any
multiplexer_utils.exec = function(command, callback, opts)
  opts = opts or {}
  if opts.async == nil then
    opts.async = require('multiplexer.mux').is_nvim
  end
  if opts.async then
    vim.system(command, { text = true }, callback)
  else
    local obj = vim.system(command, { text = true }):wait()
    return callback(obj)
  end
end

return multiplexer_utils
