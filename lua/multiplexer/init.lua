local config = require('multiplexer.config')

local reverse = { h = 'l', j = 'k', k = 'j', l = 'h' }

local multiplexer = {}

---@param direction direction
---@param opt? multiplexer.opt
multiplexer.activate_pane = function(direction, opt)
  for _, mux in ipairs(config.muxes) do
    if
      (not config.block_if_zoomed or not mux.is_zoomed())
      and not mux.is_blocked_on(direction)
    then
      mux.activate_pane(direction, opt)
      return
    end
  end
end

---@param direction direction
---@param amount? number
---@param opt? multiplexer.opt
multiplexer.resize_pane = function(direction, amount, opt)
  amount = amount or config.default_resize_amount
  local is_zoomed = {}
  for i, mux in ipairs(config.muxes) do
    is_zoomed[i] = mux.is_zoomed()
    if
      (not config.block_if_zoomed or not is_zoomed[i])
      and not mux.is_blocked_on(direction)
    then
      mux.resize_pane(direction, amount, opt)
      return
    end
  end
  for i, mux in ipairs(config.muxes) do
    local dir = reverse[direction]
    if
      (not config.block_if_zoomed or not is_zoomed[i])
      and not mux.is_blocked_on(dir)
    then
      mux.resize_pane(direction, -amount, opt)
      return
    end
  end
end

---@param opts? multiplexer.config
function multiplexer.setup(opts)
  config.setup(opts)

  for dir, key in pairs({ left = 'h', down = 'j', up = 'k', right = 'l' }) do
    multiplexer['activate_pane_' .. dir] = function(opt)
      multiplexer.activate_pane(key, opt)
    end
    multiplexer['resize_pane_' .. dir] = function(amount, opt)
      multiplexer.resize_pane(key, amount, opt)
    end
  end

  if config.on_init then
    config.on_init()
  end
end

return multiplexer
