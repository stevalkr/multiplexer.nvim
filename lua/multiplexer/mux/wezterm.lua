local utils = require('multiplexer.utils')

---@class multiplexer.mux
local multiplexer_mux_wezterm = {}

local nav = { h = 'Left', j = 'Down', k = 'Up', l = 'Right' }
local split_nav = { h = '--left', j = '--bottom', k = '--top', l = '--right' }

---@param args table
---@return table
local cmd_extend = function(args)
  return vim.list_extend(vim.deepcopy(multiplexer_mux_wezterm.meta.cmd, true), args)
end

---@param command table
---@param opt? multiplexer.opt
---@return boolean
local apply_opt = function(command, opt)
  if opt then
    if opt.id then
      table.insert(command, 4, '--pane-id')
      table.insert(command, 5, opt.id)
    end
    if opt.dry_run then
      io.stdout:write(table.concat(command, ' ') .. '\n')
      return true
    end
  end
  return false
end

---@type multiplexer.meta
multiplexer_mux_wezterm.meta = {
  name = 'wezterm',
  cmd = { 'wezterm', 'cli' },
  pane_id = vim.env.WEZTERM_PANE
}

---@param opt? multiplexer.opt
---@return string|nil
multiplexer_mux_wezterm.current_pane_id = function(opt)
  if opt and opt.dry_run then
    io.stdout:write('echo Dry run not implemented yet\n')
    return
  end
  local command = cmd_extend({ 'list-clients', '--format', 'json' })
  return utils.exec(command, function(p)
    if p.code ~= 0 then
      vim.notify('Failed to get clients info\n' .. p.stderr, vim.log.levels.ERROR)
      return
    end
    local data = vim.json.decode(p.stdout)
    if not data or #data == 0 then
      vim.notify('Failed to get clients info\n' .. p.stderr, vim.log.levels.ERROR)
      return
    end
    return tostring(data[1].focused_pane_id)
  end, { async = false })
end

---@param direction? direction
---@param opt? multiplexer.opt
multiplexer_mux_wezterm.activate_pane = function(direction, opt)
  local command
  if direction then
    command = cmd_extend({ 'activate-pane-direction', nav[direction] })
  else
    command = cmd_extend({ 'activate-pane' })
  end
  if apply_opt(command, opt) then
    return
  end
  utils.exec(command, function(p)
    if p.code ~= 0 then
      vim.schedule(function()
        vim.notify('Failed to move to pane ' .. (direction or '') .. '\n' .. p.stderr, vim.log.levels.ERROR)
      end)
    end
  end)
end

---@param direction direction
---@param amount number
---@param opt? multiplexer.opt
multiplexer_mux_wezterm.resize_pane = function(direction, amount, opt)
  local command = cmd_extend({ 'adjust-pane-size', '--amount', tostring(math.abs(amount)), nav[direction] })
  if apply_opt(command, opt) then
    return
  end
  utils.exec(command, function(p)
    if p.code ~= 0 then
      vim.schedule(function()
        vim.notify('Failed to resize pane ' .. direction .. ' by ' .. amount .. '\n' .. p.stderr,
          vim.log.levels.ERROR)
      end)
    end
  end)
end

---@param direction direction
---@param opt? multiplexer.opt
multiplexer_mux_wezterm.split_pane = function(direction, opt)
  local command = cmd_extend({ 'split-pane', split_nav[direction] })
  if apply_opt(command, opt) then
    return
  end
  utils.exec(command, function(p)
    if p.code ~= 0 then
      vim.schedule(function()
        vim.notify('Failed to split pane ' .. direction .. '\n' .. p.stderr,
          vim.log.levels.ERROR)
      end)
    end
  end)
end

---@param text string
---@param opt? multiplexer.opt
multiplexer_mux_wezterm.send_text = function(text, opt)
  local command = cmd_extend({ 'send-text', '--no-paste', text })
  if apply_opt(command, opt) then
    return
  end
  utils.exec(command, function(p)
    if p.code ~= 0 then
      vim.schedule(function()
        vim.notify('Failed to send text to pane\n' .. p.stderr, vim.log.levels.ERROR)
      end)
    end
  end)
end

---@param direction direction
---@param opt? multiplexer.opt
---@return boolean|nil
multiplexer_mux_wezterm.is_blocked_on = function(direction, opt)
  local command = cmd_extend({ 'get-pane-direction', nav[direction] })
  if apply_opt(command, opt) then
    return
  end
  return utils.exec(command, function(p)
    if p.code ~= 0 then
      vim.notify('Failed to get relative pane id\n' .. p.stderr, vim.log.levels.ERROR)
    else
      return #p.stdout == 0
    end
  end, { async = false })
end

---@param opt? multiplexer.opt
---@return boolean|nil
multiplexer_mux_wezterm.is_zoomed = function(opt)
  local command = cmd_extend({ 'list', '--format', 'json' })
  if apply_opt(command, opt) then
    return
  end
  return utils.exec(command, function(p)
    if p.code ~= 0 then
      vim.notify('Failed to get pane info\n' .. p.stderr, vim.log.levels.ERROR)
      return
    end
    local data = vim.json.decode(p.stdout)
    if not data or #data == 0 then
      vim.notify('Failed to get clients info\n' .. p.stderr, vim.log.levels.ERROR)
      return
    end
    for _, pane in pairs(data) do
      if pane.is_active == true and tostring(pane.pane_id) == multiplexer_mux_wezterm.meta.pane_id then
        return pane.is_zoomed
      end
    end
  end, { async = false })
end

---@param opt? multiplexer.opt
---@return boolean|nil
multiplexer_mux_wezterm.is_active = function(opt)
  if opt and opt.dry_run then
    io.stdout:write('echo Dry run not implemented yet\n')
    return
  end
  local command = cmd_extend({ 'list', '--format', 'json' })
  return utils.exec(command, function(p)
    if p.code ~= 0 then
      vim.notify('Failed to get pane info\n' .. p.stderr, vim.log.levels.ERROR)
      return
    end
    local requested_pane_id = opt and opt.id or multiplexer_mux_wezterm.meta.pane_id
    local data = vim.json.decode(p.stdout)
    if not data or #data == 0 then
      vim.notify('Failed to get clients info\n' .. p.stderr, vim.log.levels.ERROR)
      return
    end
    for _, pane in pairs(data) do
      if tostring(pane.pane_id) == requested_pane_id then
        return pane.is_active
      end
    end
  end, { async = false })
end

---@param key string
---@param value string
local set_user_vars = function(key, value)
  -- Lua uses decimal for escape sequences but terminal uses octal, \033 is changed to \027
  io.stderr:write(string.format('\027]1337;SetUserVar=%s=%s\007', key, vim.base64.encode(value)))
end

multiplexer_mux_wezterm.on_init = function()
  set_user_vars('IS_NVIM', 'true')
end

multiplexer_mux_wezterm.on_exit = function()
  set_user_vars('IS_NVIM', 'false')
end

return multiplexer_mux_wezterm
