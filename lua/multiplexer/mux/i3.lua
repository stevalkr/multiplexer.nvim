local utils = require('multiplexer.utils')

---@class multiplexer.mux
local multiplexer_mux_i3 = {}

local nav = { h = 'left', j = 'down', k = 'up', l = 'right' }
local reverse_nav = { h = 'right', j = 'up', k = 'down', l = 'left' }

---@param args table
---@return table
local cmd_extend = function(args)
  return vim.list_extend(vim.deepcopy(multiplexer_mux_i3.meta.cmd, true), args)
end

---@param command table
---@param opt? multiplexer.opt
---@return boolean
local apply_opt = function(command, opt)
  if opt then
    if opt.id then
      table.insert(command, 2, string.format('[id=%s]', opt.id))
    end
    if opt.dry_run then
      io.stdout:write(table.concat(command, ' ') .. '\n')
      return true
    end
  end
  return false
end

local find_focused
---@param node table
---@param fn fun(node: table): boolean
---@return table|nil
find_focused = function(node, fn)
  if node and fn(node) then
    return node
  end
  local found = nil
  if node and node.nodes then
    for _, child in ipairs(node.nodes) do
      found = find_focused(child, fn)
      if found then
        return found
      end
    end
  end
  if node and node.floating_nodes then
    for _, child in ipairs(node.floating_nodes) do
      found = find_focused(child, fn)
      if found then
        return found
      end
    end
  end
  return nil
end

---@type multiplexer.meta
multiplexer_mux_i3.meta = {
  name = 'i3',
  cmd = { 'i3-msg', '-s', vim.env.I3SOCK },
  pane_id = '',
}

---@param opt? multiplexer.opt
---@return string|nil
multiplexer_mux_i3.current_pane_id = function(opt)
  if opt and opt.dry_run then
    io.stdout:write('echo Dry run not implemented yet\n')
    return
  end
  local command = cmd_extend({ '-t', 'get_tree' })
  return utils.exec(command, function(p)
    if p.code ~= 0 then
      vim.notify('Failed to get tree info\n' .. p.stderr, vim.log.levels.ERROR)
      return
    end
    local data = vim.json.decode(p.stdout)
    if not data or next(data) == nil then
      vim.notify('Failed to get tree info\n' .. p.stderr, vim.log.levels.ERROR)
      return
    end
    local node = find_focused(data, function(n)
      return n.focused
    end)
    if not node then
      return
    end
    return tostring(node.id)
  end, { async = false })
end

multiplexer_mux_i3.meta.pane_id = multiplexer_mux_i3.current_pane_id() or ''
if #multiplexer_mux_i3.meta.pane_id == 0 then
  vim.notify('Failed to get i3 pane id', vim.log.levels.ERROR)
end

---@param direction? direction
---@param opt? multiplexer.opt
multiplexer_mux_i3.activate_pane = function(direction, opt)
  local command
  if direction then
    command = cmd_extend({ 'focus', nav[direction] })
  else
    command = cmd_extend({ 'focus' })
  end
  if apply_opt(command, opt) then
    return
  end
  utils.exec(command, function(p)
    if p.code ~= 0 then
      vim.schedule(function()
        vim.notify(
          'Failed to move to pane ' .. (direction or '') .. '\n' .. p.stderr,
          vim.log.levels.ERROR
        )
      end)
    end
  end)
end

---@param direction direction
---@param amount number
---@param opt? multiplexer.opt
multiplexer_mux_i3.resize_pane = function(direction, amount, opt)
  if amount == 0 then
    return
  end
  local command = cmd_extend({
    'resize',
    (amount < 0 and 'shrink' or 'grow'),
    (amount < 0 and reverse_nav[direction] or nav[direction]),
    tostring(math.abs(amount)),
  })
  if apply_opt(command, opt) then
    return
  end
  utils.exec(command, function(p)
    if p.code ~= 0 then
      vim.schedule(function()
        vim.notify(
          'Failed to resize pane '
            .. direction
            .. ' by '
            .. amount
            .. '\n'
            .. p.stderr,
          vim.log.levels.ERROR
        )
      end)
    end
  end)
end

---@param direction direction
---@param opt? multiplexer.opt
multiplexer_mux_i3.split_pane = function(direction, opt)
  vim.notify('i3wm does not support splitting pane', vim.log.levels.ERROR)
end

---@param text string
---@param opt? multiplexer.opt
multiplexer_mux_i3.send_text = function(text, opt)
  local command = cmd_extend({ 'exec', 'xdotool', 'type', text })
  if apply_opt(command, opt) then
    return
  end
  utils.exec(command, function(p)
    if p.code ~= 0 then
      vim.schedule(function()
        vim.notify(
          'Failed to send text to pane\n' .. p.stderr,
          vim.log.levels.ERROR
        )
      end)
    end
  end)
end

---@param direction direction
---@param opt? multiplexer.opt
---@return boolean|nil
multiplexer_mux_i3.is_blocked_on = function(direction, opt)
  local command = cmd_extend({ 'focus', nav[direction] })
  if
    utils.exec(command, function(p)
      if p.code ~= 0 then
        vim.notify(
          'Failed to move to pane ' .. (direction or '') .. '\n' .. p.stderr,
          vim.log.levels.ERROR
        )
        return true
      end
    end, { async = false })
  then
    return
  end
  if
    multiplexer_mux_i3.meta.pane_id == multiplexer_mux_i3.current_pane_id()
  then
    if opt and opt.dry_run then
      io.stdout:write('echo true\n')
      return
    end
    return true
  end
  command = cmd_extend({ 'focus', reverse_nav[direction] })
  if
    utils.exec(command, function(p)
      if p.code ~= 0 then
        vim.notify(
          'Failed to move to pane ' .. direction .. '\n' .. p.stderr,
          vim.log.levels.ERROR
        )
        return true
      end
    end, { async = false })
  then
    return
  end
  if opt and opt.dry_run then
    io.stdout:write('echo false\n')
    return
  end
  return false
end

---@param opt? multiplexer.opt
---@return boolean|nil
multiplexer_mux_i3.is_zoomed = function(opt)
  local command = cmd_extend({ '-t', 'get_tree' })
  return utils.exec(command, function(p)
    if p.code ~= 0 then
      vim.notify('Failed to get tree info\n' .. p.stderr, vim.log.levels.ERROR)
    end
    local data = vim.json.decode(p.stdout)
    if not data or next(data) == nil then
      vim.notify('Failed to get tree info\n' .. p.stderr, vim.log.levels.ERROR)
    end
    local node = find_focused(data, function(n)
      if opt and opt.id then
        return tostring(n.id) == opt.id
      else
        return n.focused
      end
    end)
    if not node then
      return
    end
    return node.fullscreen_mode == 1
  end, { async = false })
end

---@param opt? multiplexer.opt
---@return boolean|nil
multiplexer_mux_i3.is_active = function(opt)
  local command = cmd_extend({ '-t', 'get_tree' })
  return utils.exec(command, function(p)
    if p.code ~= 0 then
      vim.notify('Failed to get tree info\n' .. p.stderr, vim.log.levels.ERROR)
    end
    local data = vim.json.decode(p.stdout)
    if not data or next(data) == nil then
      vim.notify('Failed to get tree info\n' .. p.stderr, vim.log.levels.ERROR)
    end
    local node = find_focused(data, function(n)
      return tostring(n.id)
        == (opt and opt.id or multiplexer_mux_i3.meta.pane_id)
    end)
    if not node then
      return
    end
    return node.focused == 1
  end, { async = false })
end

return multiplexer_mux_i3
