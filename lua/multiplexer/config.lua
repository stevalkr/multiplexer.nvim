---@class multiplexer.config
---@field float_win 'zoomed' | 'close' | nil
---@field block_if_zoomed boolean
---@field default_resize_amount number
---@field kitty_password string|nil
---@field muxes (multiplexer.mux|'nvim'|'tmux'|'zellij'|'kitty'|'wezterm'|'i3')[]
---@field on_init? fun()

local config = {
  ---@type multiplexer.config
  default = {
    -- Behavior for Neovim floating windows during navigation:
    -- 'zoomed' => Treat as a zoomed window
    -- 'close'  => Close the window before navigating
    -- nil      => No special behavior
    float_win = 'zoomed',

    -- Prevent navigation when the current pane is zoomed
    block_if_zoomed = true,

    -- Default resize increment (in character cells)
    default_resize_amount = 1,

    -- Kitty remote control password (e.g., '--password=1234' or '--password-file=/path/to/file')
    -- See https://sw.kovidgoyal.net/kitty/remote-control/#cmdoption-kitten-password
    kitty_password = nil,

    -- Enabled multiplexers (overridable by $MULTIPLEXER_LIST environment variable)
    -- Won't load if you're not in a session
    muxes = { 'nvim', 'tmux', 'zellij', 'kitty', 'wezterm', 'i3' },

    -- Optional function to run after initialization
    on_init = nil
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
