---@alias direction 'h' | 'j' | 'k' | 'l'

---@class multiplexer.mux
---@field meta multiplexer.meta
---@field current_pane_id fun(opt?: multiplexer.opt): string|nil
---@field activate_pane fun(direction?: direction, opt?: multiplexer.opt)
---@field resize_pane fun(direction: direction, amount: number, opt?: multiplexer.opt)
---@field split_pane fun(direction: direction, opt?: multiplexer.opt)
---@field send_text fun(text: string, opt?: multiplexer.opt)
---@field is_blocked_on fun(direction: direction, opt?: multiplexer.opt): boolean|nil
---@field is_zoomed fun(opt?: multiplexer.opt): boolean|nil
---@field is_active fun(opt?: multiplexer.opt): boolean|nil
---@field on_init? fun()
---@field on_exit? fun()

---@class multiplexer.opt
---@field id? string
---@field dry_run? boolean

---@class multiplexer.meta
---@field name string
---@field cmd table
---@field pane_id string

local multiplexer_mux = {}

local term_program = vim.trim(vim.env.TERM_PROGRAM or ''):lower()

multiplexer_mux.is_nvim = #vim.api.nvim_list_uis() ~= 0 or vim.env.NVIM ~= nil
multiplexer_mux.is_tmux = term_program == 'tmux' or vim.env.TMUX ~= nil
multiplexer_mux.is_zellij = term_program == 'zellij' or vim.env.ZELLIJ ~= nil
multiplexer_mux.is_kitty = term_program == 'kitty' or vim.env.KITTY_PID ~= nil
multiplexer_mux.is_wezterm = term_program == 'wezterm' or vim.env.WEZTERM_EXECUTABLE ~= nil
multiplexer_mux.is_i3 = vim.env.DESKTOP_SESSION == 'i3' or vim.env.I3SOCK ~= nil

---@param mux multiplexer.mux
multiplexer_mux.validate = function(mux)
  if vim.fn.has('nvim-0.11') == 1 then
    vim.validate('mux', mux, 'table')
    vim.validate('meta', mux.meta, 'table')
    vim.validate('name', mux.meta.name, 'string')
    vim.validate('current_pane_id', mux.current_pane_id, 'function')
    vim.validate('activate_pane', mux.activate_pane, 'function')
    vim.validate('resize_pane', mux.resize_pane, 'function')
    vim.validate('split_pane', mux.split_pane, 'function')
    vim.validate('send_text', mux.send_text, 'function')
    vim.validate('is_blocked_on', mux.is_blocked_on, 'function')
    vim.validate('is_zoomed', mux.is_zoomed, 'function')
    vim.validate('is_active', mux.is_active, 'function')
    vim.validate('on_init', mux.on_init, 'function', true)
    vim.validate('on_exit', mux.on_exit, 'function', true)
  else
    vim.validate({
      mux = { mux, 'table' },
      meta = { mux.meta, 'table' },
      name = { mux.meta.name, 'string' },
      current_pane_id = { mux.current_pane_id, 'function' },
      activate_pane = { mux.activate_pane, 'function' },
      resize_pane = { mux.resize_pane, 'function' },
      split_pane = { mux.split_pane, 'function' },
      send_text = { mux.send_text, 'function' },
      is_blocked_on = { mux.is_blocked_on, 'function' },
      is_zoomed = { mux.is_zoomed, 'function' },
      is_active = { mux.is_active, 'function' },
      on_init = { mux.on_init, 'function', true },
      on_exit = { mux.on_exit, 'function', true },
    })
  end
end

return multiplexer_mux
