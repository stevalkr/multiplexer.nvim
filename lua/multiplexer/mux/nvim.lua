local config = require('multiplexer.config')

---@class multiplexer.mux
local multiplexer_mux_nvim = {}

---@param args string
---@return table
local cmd_extend = function(args)
  local cmd = vim.deepcopy(multiplexer_mux_nvim.meta.cmd, true)
  cmd[#cmd] = cmd[#cmd] .. args .. ')<CR>'
  return cmd
end

---@type multiplexer.meta
multiplexer_mux_nvim.meta = {
  name = 'nvim',
  cmd = { 'nvim', '--server', vim.env.NVIM, '--remote-send', '<ESC>:lua print(require(\'multiplexer.mux.nvim\').' },
  pane_id = tostring(vim.api.nvim_get_current_win())
}

---@param opt? multiplexer.opt
---@return string|nil
multiplexer_mux_nvim.current_pane_id = function(opt)
  if opt and opt.dry_run then
    io.stdout:write(table.concat(cmd_extend('current_pane_id()'), ' ') .. '\n')
    return
  end
  return tostring(vim.api.nvim_get_current_win())
end

---@param direction? direction
---@param opt? multiplexer.opt
multiplexer_mux_nvim.activate_pane = function(direction, opt)
  if opt then
    if opt.dry_run then
      local dir = direction and ("\'" .. direction .. "\'") or 'nil'
      io.stdout:write(table.concat(cmd_extend('activate_pane(' .. dir .. ')'), ' ') .. '\n')
      return
    end
    if opt.id then
      vim.api.nvim_set_current_win(assert(tonumber(opt.id)))
    end
  end

  if config.float_win == 'close' and vim.api.nvim_win_get_config(0).relative ~= '' then
    vim.api.nvim_win_close(0, false)
  end

  if direction then
    vim.cmd('wincmd ' .. direction)
  end
end

---@param direction direction
---@param amount number
---@param opt? multiplexer.opt
multiplexer_mux_nvim.resize_pane = function(direction, amount, opt)
  if amount == 0 then
    return
  end

  local curr_win
  if opt then
    if opt.dry_run then
      io.stdout:write(table.concat(cmd_extend('resize_pane(' .. ("\'" .. direction .. "\'") .. ', ' .. amount .. ')'),
        ' ') .. '\n')
      return
    end
    if opt.id then
      curr_win = vim.api.nvim_get_current_win()
      vim.api.nvim_set_current_win(assert(tonumber(opt.id)))
    end
  end

  local n = (amount < 0 and '-' or '+') .. tostring(math.abs(amount))
  local cmd
  if direction == 'h' or direction == 'l' then
    cmd = string.format('vertical resize %s', n)
  else
    cmd = string.format('resize %s', n)
  end
  vim.cmd(cmd)

  if curr_win then
    vim.api.nvim_set_current_win(curr_win)
  end
end

---@param direction direction
---@param opt? multiplexer.opt
multiplexer_mux_nvim.split_pane = function(direction, opt)
  local curr_win
  if opt then
    if opt.dry_run then
      io.stdout:write(table.concat(cmd_extend('split_pane(' .. ("\'" .. direction .. "\'") .. ')'), ' ') .. '\n')
      return
    end
    if opt.id then
      curr_win = vim.api.nvim_get_current_win()
      vim.api.nvim_set_current_win(assert(tonumber(opt.id)))
    end
  end

  local ori_splitright = vim.opt.splitright
  local ori_splitbelow = vim.opt.splitbelow
  local cmd
  if direction == 'h' then
    vim.opt.splitright = false
    cmd = string.format('vsplit')
  elseif direction == 'j' then
    vim.opt.splitbelow = true
    cmd = string.format('split')
  elseif direction == 'k' then
    vim.opt.splitbelow = false
    cmd = string.format('split')
  elseif direction == 'l' then
    vim.opt.splitright = true
    cmd = string.format('vsplit')
  end
  vim.cmd(cmd)
  vim.opt.splitright = ori_splitright
  vim.opt.splitbelow = ori_splitbelow

  if curr_win then
    vim.api.nvim_set_current_win(curr_win)
  end
end

---@param direction direction
---@param opt? multiplexer.opt
---@return boolean|nil
multiplexer_mux_nvim.is_blocked_on = function(direction, opt)
  if not direction then
    return false
  end

  local curr_win
  if opt then
    if opt.dry_run then
      io.stdout:write(table.concat(cmd_extend('is_blocked_on(' .. ("\'" .. direction .. "\'") .. ')'), ' ') .. '\n')
      return
    end
    if opt.id then
      curr_win = vim.api.nvim_get_current_win()
      vim.api.nvim_set_current_win(assert(tonumber(opt.id)))
    end
  end

  local is_blocked = (vim.fn.winnr() == vim.fn.winnr(direction))
  if curr_win then
    vim.api.nvim_set_current_win(curr_win)
  end
  return is_blocked
end

---@param opt? multiplexer.opt
---@return boolean|nil
multiplexer_mux_nvim.is_zoomed = function(opt) ---@diagnostic disable-line
  local id = multiplexer_mux_nvim.current_pane_id()
  if opt then
    if opt.dry_run then
      io.stdout:write('echo Dry run not implemented yet\n')
      return
    end
    if opt.id then
      id = opt.id
    end
  end
  if config.float_win == 'zoomed' then
    return vim.api.nvim_win_get_config(assert(tonumber(id))).relative ~= ''
  end
  return false
end

---@param opt? multiplexer.opt
---@return boolean|nil
multiplexer_mux_nvim.is_active = function(opt)
  if opt then
    if opt.dry_run then
      io.stdout:write(table.concat(cmd_extend('is_active()'), ' ') .. '\n')
      return
    end
    if opt.id then
      return multiplexer_mux_nvim.current_pane_id() == opt.id
    end
  end
  return multiplexer_mux_nvim.current_pane_id() == multiplexer_mux_nvim.meta.pane_id
end

return multiplexer_mux_nvim
