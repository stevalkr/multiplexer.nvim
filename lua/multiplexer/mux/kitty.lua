---@class multiplexer.mux
local multiplexer_mux_kitty = {}

local nav = { h = 'left', j = 'bottom', k = 'top', l = 'right' }

---@param args table
---@return table
local cmd_extend = function(args)
  return vim.list_extend(vim.deepcopy(multiplexer_mux_kitty.meta.cmd, true), args)
end

---@param command table
---@param opt? multiplexer.opt
---@return boolean
local apply_opt = function(command, opt)
  if opt then
    if opt.id then
      table.insert(command, '--match')
      table.insert(command, 'id:' .. opt.id)
    end
    if opt.dry_run then
      io.stdout:write(table.concat(command, ' ') .. '\n')
      return true
    end
  end
  return false
end

---@type multiplexer.meta
multiplexer_mux_kitty.meta = {
  name = 'kitty',
  cmd = { 'kitten', '@', '--to', vim.env.KITTY_LISTEN_ON },
  pane_id = vim.env.KITTY_WINDOW_ID
}
if require('multiplexer.config').kitty_password then
  table.insert(multiplexer_mux_kitty.meta.cmd, 3, require('multiplexer.config').kitty_password)
end

---@param opt? multiplexer.opt
---@return string|nil
multiplexer_mux_kitty.current_pane_id = function(opt)
  if opt and opt.dry_run then
    io.stdout:write('echo Dry run not implemented yet\n')
    return
  end
  local command = cmd_extend({ 'ls', '--match', 'state:active and state:parent_active' })
  local ret = vim.system(command, { text = true }):wait()
  if ret.code ~= 0 then
    vim.notify('Failed to get clients info\n' .. ret.stderr, vim.log.levels.ERROR)
    return
  end
  local data = vim.json.decode(ret.stdout)
  if not data or #data == 0 then
    vim.notify('Failed to get clients info\n' .. ret.stderr, vim.log.levels.ERROR)
    return
  end
  for _, client in pairs(data) do
    if client.is_active then
      if #client.tabs ~= 1 or #client.tabs[1].windows ~= 1 then
        vim.notify('Unexpected number of tabs or windows\n', vim.log.levels.ERROR)
        return
      end
      return tostring(client.tabs[1].windows[1].id)
    end
  end
end

---@param direction? direction
---@param opt? multiplexer.opt
multiplexer_mux_kitty.activate_pane = function(direction, opt)
  local activate, dry_run_commands = nil, {}
  if direction then
    local command = cmd_extend({ 'focus-window', '--match', 'neighbor:' .. nav[direction] })
    table.insert(dry_run_commands, 1, table.concat(command, ' '))
    activate = function()
      vim.system(command, { text = true }, function(p)
        if p.code ~= 0 then
          vim.schedule(function()
            vim.notify(
              'Failed to move to pane ' .. direction .. '\n' .. p.stderr,
              vim.log.levels.ERROR)
          end)
        end
      end)
    end
  end
  if opt then
    if opt.id then
      local command = cmd_extend({ 'focus-window', '--match', 'id:' .. opt.id })
      table.insert(dry_run_commands, 1, table.concat(command, ' '))
      activate = function()
        vim.system(command, { text = true }, function(p)
          if p.code ~= 0 then
            vim.schedule(function()
              vim.notify(
                'Failed to move to pane ' .. opt.id .. '\n' .. p.stderr,
                vim.log.levels.ERROR)
            end)
          else
            if activate then
              activate()
            end
          end
        end)
      end
    end
    if opt.dry_run then
      io.stdout:write(table.concat(dry_run_commands, ' && ') .. '\n')
      return
    end
  end
  if activate then
    activate()
  end
end

---@param direction direction
---@param amount number
---@param opt? multiplexer.opt
multiplexer_mux_kitty.resize_pane = function(direction, amount, opt)
  local str = (amount < 0 and '-' or '+') .. tostring(math.abs(amount))
  local cmd = { 'resize-window', '--increment', str }
  if direction == 'h' or direction == 'l' then
    vim.list_extend(cmd, { '--axis', 'horizontal' })
  else
    vim.list_extend(cmd, { '--axis', 'vertical' })
  end
  local command = cmd_extend(cmd)
  if apply_opt(command, opt) then
    return
  end
  vim.system(command, { text = true }, function(p)
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
multiplexer_mux_kitty.split_pane = function(direction, opt)
  local cmd = { 'launch' }
  if direction == 'h' or direction == 'l' then
    vim.list_extend(cmd, { '--location', 'vsplit' })
  else
    vim.list_extend(cmd, { '--location', 'hsplit' })
  end
  local command = cmd_extend(cmd)
  if apply_opt(command, opt) then
    return
  end
  vim.system(command, { text = true }, function(p)
    if p.code ~= 0 then
      vim.schedule(function()
        vim.notify('Failed to split pane ' .. direction .. '\n' .. p.stderr,
          vim.log.levels.ERROR)
      end)
    end
  end)
end

---@param direction direction
---@param opt? multiplexer.opt
---@return boolean|nil
multiplexer_mux_kitty.is_blocked_on = function(direction, opt)
  local curr_win
  if opt then
    if opt.dry_run then
      io.stdout:write('echo Dry run not implemented yet\n')
      return
    end
    if opt.id then
      curr_win = multiplexer_mux_kitty.meta.pane_id
      local ret = vim.system(cmd_extend({ 'focus-window', '--match', 'id:' .. opt.id }), { text = true }):wait()
      if ret.code ~= 0 then
        vim.notify('Failed to move to pane ' .. opt.id .. '\n' .. ret.stderr, vim.log.levels.ERROR)
      end
    end
  end
  local command = cmd_extend({ 'ls', '--match', 'neighbor:' .. nav[direction] })
  local ret = vim.system(command, { text = true }):wait()
  if curr_win then
    vim.system(cmd_extend({ 'focus-window', '--match', 'id:' .. curr_win }), { text = true }):wait()
  end
  if ret.code ~= 0 then
    if ret.stderr:find('No matching windows') then
      return true
    end
    vim.notify('Failed to get relative pane id\n' .. ret.stderr, vim.log.levels.ERROR)
    return
  end
  return false
end

---@param opt? multiplexer.opt
---@return boolean|nil
multiplexer_mux_kitty.is_zoomed = function(opt)
  if opt and opt.dry_run then
    io.stdout:write('echo Dry run not implemented yet\n')
    return
  end
  local match = 'state:active and state:parent_active'
  if opt and opt.id then
    match = 'id:' .. opt.id
  end
  local command = cmd_extend({ 'ls', '--match', match })
  local ret = vim.system(command, { text = true }):wait()
  if ret.code ~= 0 then
    vim.notify('Failed to get pane info\n' .. ret.stderr, vim.log.levels.ERROR)
    return
  end
  for _, client in pairs(vim.json.decode(ret.stdout)) do
    if client.is_active then
      if #client.tabs ~= 1 or #client.tabs[1].windows ~= 1 then
        vim.notify('Unexpected number of tabs or windows\n', vim.log.levels.ERROR)
        return
      end
      return client.tabs[1].layout == 'stack'
    end
  end
end

---@param opt? multiplexer.opt
---@return boolean|nil
multiplexer_mux_kitty.is_active = function(opt)
  if opt and opt.dry_run then
    io.stdout:write('echo Dry run not implemented yet\n')
    return
  end
  local requested_pane_id = opt and opt.id or multiplexer_mux_kitty.meta.pane_id
  local command = cmd_extend({ 'ls', '--match', 'id:' .. requested_pane_id })
  local ret = vim.system(command, { text = true }):wait()
  if ret.code ~= 0 then
    vim.notify('Failed to get pane info\n' .. ret.stderr, vim.log.levels.ERROR)
    return
  end
  for _, client in pairs(vim.json.decode(ret.stdout)) do
    if client.is_active then
      if #client.tabs ~= 1 or #client.tabs[1].windows ~= 1 then
        vim.notify('Unexpected number of tabs or windows\n', vim.log.levels.ERROR)
        return
      end
      return client.tabs[1].windows[1].is_active
    end
  end
end

---@param key string
---@param value string
local set_user_vars = function(key, value)
  -- Lua uses decimal for escape sequences but terminal uses octal, \033 is changed to \027
  io.stderr:write(string.format('\027]1337;SetUserVar=%s=%s\007', key, vim.base64.encode(value)))
end

multiplexer_mux_kitty.on_init = function()
  set_user_vars('IS_NVIM', 'true')
end

multiplexer_mux_kitty.on_exit = function()
  set_user_vars('IS_NVIM', 'false')
end

return multiplexer_mux_kitty
