local utils = require('multiplexer.utils')

---@class multiplexer.mux
local multiplexer_mux_zellij = {}

local nav = { h = 'left', j = 'down', k = 'up', l = 'right' }
local split_nav = { h = 'right', j = 'down', k = 'down', l = 'right' }
local reverse_nav = { h = 'right', j = 'up', k = 'down', l = 'left' }

---@param args table
---@return table
local cmd_extend = function(args)
  return vim.list_extend(
    vim.deepcopy(multiplexer_mux_zellij.meta.cmd, true),
    args
  )
end

---@param command table
---@param opt? multiplexer.opt
---@return boolean
local apply_opt = function(command, opt)
  if opt then
    if opt.id then
      vim.notify(
        'Zellij does not support setting pane id',
        vim.log.levels.ERROR
      )
      return true
    end
    if opt.dry_run then
      io.stdout:write(table.concat(command, ' ') .. '\n')
      return true
    end
  end
  return false
end

---@type multiplexer.meta
multiplexer_mux_zellij.meta = {
  name = 'zellij',
  cmd = { 'zellij', 'action' },
  pane_id = vim.env.ZELLIJ_PANE_ID,
}

---@param opt? multiplexer.opt
---@return string|nil
multiplexer_mux_zellij.current_pane_id = function(opt)
  if opt and opt.dry_run then
    io.stdout:write('echo Dry run not implemented yet\n')
    return
  end
  local command = cmd_extend({ 'list-clients' })
  return utils.exec(command, function(p)
    if p.code ~= 0 or #p.stdout == 0 then
      vim.notify('Failed to get pane id\n' .. p.stderr, vim.log.levels.ERROR)
      return
    end
    local data = vim.split(vim.trim(p.stdout), '\n')
    if #data < 2 then
      vim.notify('Failed to get pane id\n' .. p.stderr, vim.log.levels.ERROR)
      return
    end
    local row = 2
    while row <= #data do
      local columns = vim.split(data[row], '%s+')
      local pane_id = vim.split(columns[2], '_')
      if #pane_id == 2 and pane_id[1] == 'terminal' then
        return pane_id[2]
      end
      row = row + 1
    end
  end, { async = false })
end

---@param direction? direction
---@param opt? multiplexer.opt
multiplexer_mux_zellij.activate_pane = function(direction, opt)
  local command = {}
  if direction then
    command = cmd_extend({ 'move-focus', nav[direction] })
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
multiplexer_mux_zellij.resize_pane = function(direction, amount, opt)
  if amount == 0 then
    return
  end
  local command = cmd_extend({
    'resize',
    (amount < 0 and '-' or '+'),
    (amount < 0 and reverse_nav[direction] or nav[direction]),
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
multiplexer_mux_zellij.split_pane = function(direction, opt)
  if opt and opt.id then
    vim.notify('Zellij does not support setting pane id', vim.log.levels.ERROR)
    return
  end
  local swap, dry_run_commands = nil, {}
  if direction == 'h' or direction == 'k' then
    local command = cmd_extend({ 'move-pane', nav[direction] })
    table.insert(dry_run_commands, 1, table.concat(command, ' '))
    swap = function()
      utils.exec(command, function(p)
        if p.code ~= 0 then
          vim.schedule(function()
            vim.notify(
              'Failed to swap pane ' .. direction .. '\n' .. p.stderr,
              vim.log.levels.ERROR
            )
          end)
        end
      end)
    end
  end
  local command =
    cmd_extend({ 'new-pane', '--direction', split_nav[direction] })
  table.insert(dry_run_commands, 1, table.concat(command, ' '))
  if opt and opt.dry_run then
    io.stdout:write(table.concat(dry_run_commands, ' && ') .. '\n')
    return
  end
  utils.exec(command, function(p)
    if p.code ~= 0 then
      vim.schedule(function()
        vim.notify(
          'Failed to split pane ' .. direction .. '\n' .. p.stderr,
          vim.log.levels.ERROR
        )
      end)
    elseif swap then
      swap()
    end
  end)
end

---@param text string
---@param opt? multiplexer.opt
multiplexer_mux_zellij.send_text = function(text, opt)
  if opt and opt.id then
    vim.notify('Zellij does not support setting pane id', vim.log.levels.ERROR)
    return
  end
  local command = cmd_extend({ 'write-chars', text })
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
multiplexer_mux_zellij.is_blocked_on = function(direction, opt)
  if opt and opt.id then
    vim.notify('Zellij does not support setting pane id', vim.log.levels.ERROR)
    return
  end
  local command = cmd_extend({ 'move-focus', nav[direction] })
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
  if
    multiplexer_mux_zellij.meta.pane_id
    == multiplexer_mux_zellij.current_pane_id()
  then
    if opt and opt.dry_run then
      io.stdout:write('echo true\n')
      return
    end
    return true
  end
  command = cmd_extend({ 'move-focus', reverse_nav[direction] })
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
multiplexer_mux_zellij.is_zoomed = function(opt)
  if opt then
    if opt.id then
      vim.notify(
        'Zellij does not support setting pane id',
        vim.log.levels.ERROR
      )
      return
    end
    if opt.dry_run then
      io.stdout:write('echo false\n')
      return
    end
  end
  return false
end

---@param opt? multiplexer.opt
---@return boolean|nil
multiplexer_mux_zellij.is_active = function(opt)
  if opt then
    if opt.id then
      vim.notify(
        'Zellij does not support setting pane id',
        vim.log.levels.ERROR
      )
      return
    end
    if opt.dry_run then
      io.stdout:write('echo true\n')
      return
    end
  end
  return true
end

return multiplexer_mux_zellij
