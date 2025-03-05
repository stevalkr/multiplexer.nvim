---@class multiplexer.config
---@field float_win 'zoomed' | 'close' | nil
---@field block_if_zoomed boolean
---@field default_resize_amount number
---@field kitty_password string|nil
---@field muxes (multiplexer.mux|'nvim'|'tmux'|'kitty'|'wezterm')[]
---@field on_init? fun()

local config = {
  ---@type multiplexer.config
  default = {
    float_win = 'zoomed',
    block_if_zoomed = true,
    default_resize_amount = 1,
    kitty_password = nil,
    muxes = { 'nvim', 'tmux', 'kitty', 'wezterm' },
  }
}

---@type multiplexer.config
local multiplexer_config = setmetatable({
}, {
  __index = function(_, key)
    return config[key]
  end,
  __newindex = function(_, key, value)
    config[key] = value
  end
})

---@param opts? multiplexer.config
multiplexer_config.setup = function(opts) ---@diagnostic disable-line
  config = vim.tbl_deep_extend('force', config.default, opts or {})

  local multiplexer_mux = require('multiplexer.mux')

  if vim.env.MULTIPLEXER_LIST then
    if multiplexer_mux.is_nvim then
      vim.fn.setenv('MULTIPLEXER_LIST', 'nvim,' .. vim.env.MULTIPLEXER_LIST)
    end
    config.muxes = vim.split(vim.env.MULTIPLEXER_LIST, ',', { trimempty = true })
  end

  local muxes = {}
  for _, mux in ipairs(config.muxes) do
    local m
    if type(mux) == 'string' then
      if multiplexer_mux['is_' .. mux] == true then
        m = require('multiplexer.mux.' .. mux)
      end
    else
      m = mux
    end
    if m then
      multiplexer_mux.validate(m)
      muxes[#muxes + 1] = m
    end
  end
  config.muxes = muxes

  if multiplexer_mux.is_nvim then
    vim.api.nvim_create_autocmd({ 'VimEnter', 'VimResume' }, {
      callback = vim.schedule_wrap(function()
        for _, mux in ipairs(config.muxes) do
          if mux.on_init then
            mux.on_init()
          end
        end
      end)
    })
    vim.api.nvim_create_autocmd({ 'VimLeavePre', 'VimSuspend' }, {
      callback = vim.schedule_wrap(function()
        for _, mux in ipairs(config.muxes) do
          if mux.on_exit then
            mux.on_exit()
          end
        end
      end)
    })
  end
end

return multiplexer_config
