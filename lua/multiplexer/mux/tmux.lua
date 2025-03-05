---@class multiplexer.mux
local multiplexer_mux_tmux = {}

local nav = { h = 'L', j = 'D', k = 'U', l = 'R' }
local pane_nav = { h = 'left', j = 'bottom', k = 'top', l = 'right' }

---@param args table
---@return table
local cmd_extend = function(args)
  return vim.list_extend(vim.deepcopy(multiplexer_mux_tmux.meta.cmd, true), args)
end

---@param command table
---@param opt? multiplexer.opt
---@return boolean
local apply_opt = function(command, opt)
  if opt then
    if opt.id then
      table.insert(command, 5, '-t')
      table.insert(command, 6, opt.id)
    end
    if opt.dry_run then
      io.stdout:write(table.concat(command, ' ') .. '\n')
      return true
    end
  end
  return false
end

---@type multiplexer.meta
multiplexer_mux_tmux.meta = {
  name = 'tmux',
  cmd = { 'tmux', '-S', string.match(vim.env.TMUX, '^(.-),') },
  pane_id = vim.env.TMUX_PANE
}

---@param opt? multiplexer.opt
---@return string|nil
multiplexer_mux_tmux.current_pane_id = function(opt)
  local command = cmd_extend({ 'display', '-p', '\'#{pane_id}\'' })
  if opt and opt.dry_run then
    io.stdout:write(table.concat(command, ' ') .. '\n')
    return
  end
  local ret = vim.system(command, { text = true }):wait()
  if ret.code ~= 0 then
    vim.notify('Failed to get pane id\n' .. ret.stderr, vim.log.levels.ERROR)
    return
  end
  ret.stdout = vim.trim(ret.stdout)
  if #ret.stdout == 0 then
    return
  end
  return ret.stdout
end

---@param direction? direction
---@param opt? multiplexer.opt
multiplexer_mux_tmux.activate_pane = function(direction, opt)
  local command
  if direction then
    command = cmd_extend({ 'select-pane', '-' .. nav[direction] })
  else
    command = cmd_extend({ 'select-pane' })
  end
  if apply_opt(command, opt) then
    return
  end
  vim.system(command, { text = true }, function(p)
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
multiplexer_mux_tmux.resize_pane = function(direction, amount, opt)
  if amount == 0 then
    return
  end
  local command = cmd_extend({ 'resize-pane', '-' .. nav[direction], tostring(math.abs(amount)) })
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
multiplexer_mux_tmux.split_pane = function(direction, opt)
  local command
  if direction == 'h' then
    command = cmd_extend({ 'split-window', '-h', '-b' })
  elseif direction == 'j' then
    command = cmd_extend({ 'split-window', '-v' })
  elseif direction == 'k' then
    command = cmd_extend({ 'split-window', '-v', '-b' })
  elseif direction == 'l' then
    command = cmd_extend({ 'split-window', '-h' })
  end
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
multiplexer_mux_tmux.is_blocked_on = function(direction, opt)
  local command = cmd_extend({ 'if-shell', '-F', string.format('#{pane_at_%s}', pane_nav[direction]), 'display -p true' })
  if apply_opt(command, opt) then
    return
  end
  local ret = vim.system(command, { text = true }):wait()
  if ret.code ~= 0 then
    vim.notify('Failed to list panes\n' .. ret.stderr, vim.log.levels.ERROR)
    return
  end
  return #ret.stdout ~= 0
end

---@param opt? multiplexer.opt
---@return boolean|nil
multiplexer_mux_tmux.is_zoomed = function(opt)
  local command = cmd_extend({ 'if-shell', '-F', '#{window_zoomed_flag}', 'display -p true' })
  if apply_opt(command, opt) then
    return
  end
  local ret = vim.system(command, { text = true }):wait()
  if ret.code ~= 0 then
    vim.notify('Failed to check zoomed\n' .. ret.stderr, vim.log.levels.ERROR)
    return
  end
  return #ret.stdout ~= 0
end

---@param opt? multiplexer.opt
---@return boolean|nil
multiplexer_mux_tmux.is_active = function(opt)
  local command = cmd_extend({ 'if-shell', '-F', '#{pane_active}', 'display -p true' })
  if opt and not opt.id then
    opt.id = multiplexer_mux_tmux.meta.pane_id
  end
  if apply_opt(command, opt) then
    return
  end
  local ret = vim.system(command, { text = true }):wait()
  if ret.code ~= 0 then
    vim.notify('Failed to check active\n' .. ret.stderr, vim.log.levels.ERROR)
    return
  end
  return #ret.stdout ~= 0
end

local set_pane_option = function(option, value)
  local command = cmd_extend({ 'set-option', '-t', multiplexer_mux_tmux.meta.pane_id, '-p', option, value })
  vim.system(command, { text = true }, function(p)
    if p.code ~= 0 then
      vim.schedule(function()
        vim.notify('Failed to set option ' .. option .. ' to ' .. value .. '\n' .. p.stderr,
          vim.log.levels.ERROR)
      end)
    end
  end)
end

multiplexer_mux_tmux.on_init = function()
  set_pane_option('@pane-is-vim', '1')
end

multiplexer_mux_tmux.on_exit = function()
  set_pane_option('@pane-is-vim', '0')
end

return multiplexer_mux_tmux
