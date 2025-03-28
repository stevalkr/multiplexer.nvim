# multiplexer.nvim

A Neovim plugin that enables seamless navigation and resizing across multiple terminal multiplexers, such as tmux, kitty, and wezterm, in addition to Neovim itself.

This plugin was created based on my personal config. Any contributions or suggestions, including typos, code style, features, and so on, are highly welcomed.

https://github.com/user-attachments/assets/c2dfc760-97cb-4763-9973-1bc90536413e

## Features

- **Unified Keybindings**: Move and resize between panes in multiplexers using the same keybindings.
- **CLI Integration**: Control multiplexer actions from outside Neovim via simple command-line scripts.
- **Basic Functionalities**: Split panes, get current active pane, send text and so on using the plugin's Lua API.
- **Dry Run**: An experimental dry run mode

### Supported

- Neovim
- Tmux
- Zellij (partially)
- WezTerm
- Kitty

### What It Is

A lightweight plugin inspired by the multiplexer support in [smart-splits.nvim](https://github.com/mrjones2014/smart-splits.nvim), but with a focus on integrating multiple multiplexers rather than enhancing Neovim's native window behavior.

### What It Is Not

A "smart split" plugin for Neovim. Features like edge wrapping or advanced split management should be configured within each multiplexer individually.

## Plan

- i3-wm support?
- independent of neovim

## Install

Install multiplexer.nvim using your preferred Neovim plugin manager. Below is an example with [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ 'stevalkr/multiplexer.nvim', lazy = false, opts = {} }
```

> ***"Important"***: Avoid lazy-loading this plugin, as it must be active when Neovim starts to properly integrate with multiplexers.

For other plugin managers (e.g., packer.nvim or vim-plug), refer to their respective documentation.

## Configuration

The plugin provides a default configuration that you can customize as needed. Here’s the default setup:

```lua
---@class multiplexer.config
---@field float_win 'zoomed' | 'close' | nil
---@field block_if_zoomed boolean
---@field default_resize_amount number
---@field kitty_password string|nil
---@field muxes (multiplexer.mux|'nvim'|'tmux'|'zellij'|'kitty'|'wezterm')[]
---@field on_init? fun()
{
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
  muxes = { 'nvim', 'tmux', 'zellij', 'kitty', 'wezterm' },

  -- Optional function to run after initialization
  on_init = nil
}
```

## Usage

### Lua API

<details>

```lua
---@class multiplexer.opt
---@field id? string         Target pane id if it's not the current active pane
---@field dry_run? boolean   Experimental dry run mode.

---@param direction 'h' | 'j' | 'k' | 'l'
---@param opt? multiplexer.opt
require('multiplexer').activate_pane(direction, opt)

require('multiplexer').activate_pane_left(opt)
require('multiplexer').activate_pane_down(opt)
require('multiplexer').activate_pane_up(opt)
require('multiplexer').activate_pane_right(opt)

---@param direction 'h' | 'j' | 'k' | 'l'
---@param amount? number     Resize amount (defaults to default_resize_amount)
---@param opt? multiplexer.opt
require('multiplexer').resize_pane(direction, amount, opt)

require('multiplexer').resize_pane_left(amount, opt)
require('multiplexer').resize_pane_down(amount, opt)
require('multiplexer').resize_pane_up(amount, opt)
require('multiplexer').resize_pane_right(amount, opt)

---@type bool
require('multiplexer.mux').is_nvim  -- Is in Neovim session
require('multiplexer.mux').is_tmux  -- Is in Tmux session
require('multiplexer.mux').is_kitty  -- Is in Kitty session
require('multiplexer.mux').is_wezterm  -- Is in WezTerm session

---@type multiplexer.mux[]
require('multiplexer.config').muxes

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

---@class multiplexer.meta
---@field name string
---@field cmd table
---@field pane_id string
```

For more detailed info, please refer to the source code.

</details>

### CLI Support

To integrate with multiplexers outside Neovim

<details>

Save this script in your `$PATH`, e.g., as `multiplexer`. Also available under `scripts/`

```bash
#!/usr/bin/env bash

export MULTIPLEXER=1

get_vim_direction() {
    case $1 in
        left) echo 'h'
        ;;
        down) echo 'j'
        ;;
        up) echo 'k'
        ;;
        right) echo 'l'
        ;;
        *) return 1
        ;;
    esac
}

activate_pane() {
    local dir=$(get_vim_direction "$1")
    if [ -z "$dir" ]; then
        return 1
    fi
    nvim --headless -c ":lua require('multiplexer').activate_pane('$dir')" -c ":qa"
}

resize_pane() {
    local dir=$(get_vim_direction "$1")
    if [ -z "$dir" ]; then
        return 1
    fi
    nvim --headless -c ":lua require('multiplexer').resize_pane('$dir')" -c ":qa"
}

"$1" "$2"
```

Run commands like `multiplexer activate_pane left` or `multiplexer resize_pane right` from your multiplexer configs.

You can also use the experimental dry run mode to integrate with other tools. Note that not all the commands are supported yet.

```bash
eval $(nvim --headless -c ":lua require('multiplexer').activate_pane('$dir', { dry_run = true })" -c ":qa")
```

</details>

### Neovim

<details>

```lua
{
  'stevalkr/multiplexer.nvim',
  lazy = false,
  opts = {
    on_init = function()
      local multiplexer = require('multiplexer')

      vim.keymap.set('n', '<C-h>', multiplexer.activate_pane_left, { desc = 'Activate pane to the left' })
      vim.keymap.set('n', '<C-j>', multiplexer.activate_pane_down, { desc = 'Activate pane below' })
      vim.keymap.set('n', '<C-k>', multiplexer.activate_pane_up, { desc = 'Activate pane above' })
      vim.keymap.set('n', '<C-l>', multiplexer.activate_pane_right, { desc = 'Activate pane to the right' })

      vim.keymap.set('n', '<C-S-h>', multiplexer.resize_pane_left, { desc = 'Resize pane to the left' })
      vim.keymap.set('n', '<C-S-j>', multiplexer.resize_pane_down, { desc = 'Resize pane below' })
      vim.keymap.set('n', '<C-S-k>', multiplexer.resize_pane_up, { desc = 'Resize pane above' })
      vim.keymap.set('n', '<C-S-l>', multiplexer.resize_pane_right, { desc = 'Resize pane to the right' })
    end
  }
}
```

To optimize CLI performance, add this to your `init.lua`:

```lua
if vim.env.MULTIPLEXER then -- You can change this variable in the script above
  require('lazy').setup({
    'stevalkr/multiplexer.nvim',
    lazy = false,
    opts = {}
  })
end
```

</details>

### Tmux

<details>

Integrate with tmux by adding this to `~/.config/tmux/tmux.conf`:

```tmux
## For some key bindings (e.g., Ctrl-Shift-h), you may need to enable extended-keys.
set -s  extended-keys on
set -as terminal-features 'xterm*:extkeys'

## Navigation
bind-key -n C-h if -F '#{@pane-is-vim}' { send-keys C-h } { run-shell 'multiplexer activate_pane left' }
bind-key -n C-j if -F '#{@pane-is-vim}' { send-keys C-j } { run-shell 'multiplexer activate_pane down' }
bind-key -n C-k if -F '#{@pane-is-vim}' { send-keys C-k } { run-shell 'multiplexer activate_pane up' }
bind-key -n C-l if -F '#{@pane-is-vim}' { send-keys C-l } { run-shell 'multiplexer activate_pane right' }

bind-key -T copy-mode-vi C-h if -F '#{@pane-is-vim}' { send-keys C-h } { run-shell 'multiplexer activate_pane left' }
bind-key -T copy-mode-vi C-j if -F '#{@pane-is-vim}' { send-keys C-j } { run-shell 'multiplexer activate_pane down' }
bind-key -T copy-mode-vi C-k if -F '#{@pane-is-vim}' { send-keys C-k } { run-shell 'multiplexer activate_pane up' }
bind-key -T copy-mode-vi C-l if -F '#{@pane-is-vim}' { send-keys C-l } { run-shell 'multiplexer activate_pane right' }

## Resize for WezTerm
bind-key -n C-H if -F '#{@pane-is-vim}' { send-keys C-S-h } { run-shell 'multiplexer resize_pane left' }
bind-key -n C-J if -F '#{@pane-is-vim}' { send-keys C-S-j } { run-shell 'multiplexer resize_pane down' }
bind-key -n C-K if -F '#{@pane-is-vim}' { send-keys C-S-k } { run-shell 'multiplexer resize_pane up' }
bind-key -n C-L if -F '#{@pane-is-vim}' { send-keys C-S-l } { run-shell 'multiplexer resize_pane right' }

bind-key -T copy-mode-vi C-H if -F '#{@pane-is-vim}' { send-keys C-S-h } { run-shell 'multiplexer resize_pane left' }
bind-key -T copy-mode-vi C-J if -F '#{@pane-is-vim}' { send-keys C-S-j } { run-shell 'multiplexer resize_pane down' }
bind-key -T copy-mode-vi C-K if -F '#{@pane-is-vim}' { send-keys C-S-k } { run-shell 'multiplexer resize_pane up' }
bind-key -T copy-mode-vi C-L if -F '#{@pane-is-vim}' { send-keys C-S-l } { run-shell 'multiplexer resize_pane right' }

## Resize for Kitty
bind-key -n C-S-h if -F '#{@pane-is-vim}' { send-keys C-S-h } { run-shell 'multiplexer resize_pane left' }
bind-key -n C-S-j if -F '#{@pane-is-vim}' { send-keys C-S-j } { run-shell 'multiplexer resize_pane down' }
bind-key -n C-S-k if -F '#{@pane-is-vim}' { send-keys C-S-k } { run-shell 'multiplexer resize_pane up' }
bind-key -n C-S-l if -F '#{@pane-is-vim}' { send-keys C-S-l } { run-shell 'multiplexer resize_pane right' }

bind-key -T copy-mode-vi C-S-h if -F '#{@pane-is-vim}' { send-keys C-S-h } { run-shell 'multiplexer resize_pane left' }
bind-key -T copy-mode-vi C-S-j if -F '#{@pane-is-vim}' { send-keys C-S-j } { run-shell 'multiplexer resize_pane down' }
bind-key -T copy-mode-vi C-S-k if -F '#{@pane-is-vim}' { send-keys C-S-k } { run-shell 'multiplexer resize_pane up' }
bind-key -T copy-mode-vi C-S-l if -F '#{@pane-is-vim}' { send-keys C-S-l } { run-shell 'multiplexer resize_pane right' }
```

For automatic detection in shell, add:

bash:
```bash
## ~/.bashrc
__set_user_var() {
    if command -v base64 >/dev/null 2>&1; then
        printf "\033]1337;SetUserVar=%s=%s\007" "$1" "$(echo -n "$2" | base64)"
    fi
}

tmux() {
    local ori_multiplexer_list="$MULTIPLEXER_LIST"
    export MULTIPLEXER_LIST="tmux,$ori_multiplexer_list"
    __set_user_var IS_TMUX true

    command tmux "$@"

    export MULTIPLEXER_LIST="$ori_multiplexer_list"
    __set_user_var IS_TMUX false
}
```

fish:
```fish
## ~/.config/fish/functions/tmux.fish
function tmux
    function __fish_set_user_var
        if type -q base64
            printf "\033]1337;SetUserVar=%s=%s\007" "$argv[1]" (echo -n "$argv[2]" | base64)
        end
    end

    set -l ori_multiplexer_list $MULTIPLEXER_LIST
    set -gx MULTIPLEXER_LIST "tmux,$ori_multiplexer_list"
    __fish_set_user_var IS_TMUX true

    command tmux $argv

    set -gx MULTIPLEXER_LIST $ori_multiplexer_list
    __fish_set_user_var IS_TMUX false
end
```

</details>

### Zellij

<details>

Integrate with zellij (partially) by adding this to `~/.config/zellij/config.conf`:

```kdl
keybinds clear-defaults=true {
    shared_except "locked" {
        bind "Ctrl h" { Run "multiplexer" "activate_pane" "left" { in_place true; close_on_exit true; }; }
        bind "Ctrl j" { Run "multiplexer" "activate_pane" "down" { in_place true; close_on_exit true; }; }
        bind "Ctrl k" { Run "multiplexer" "activate_pane" "up" { in_place true; close_on_exit true; }; }
        bind "Ctrl l" { Run "multiplexer" "activate_pane" "right" { in_place true; close_on_exit true; }; }

        bind "Alt h" { Run "multiplexer" "resize_pane" "left" { in_place true; close_on_exit true; }; }
        bind "Alt j" { Run "multiplexer" "resize_pane" "down" { in_place true; close_on_exit true; }; }
        bind "Alt k" { Run "multiplexer" "resize_pane" "up" { in_place true; close_on_exit true; }; }
        bind "Alt l" { Run "multiplexer" "resize_pane" "right" { in_place true; close_on_exit true; }; }
    }
}
```

For automatic detection in shell, add:

bash:
```bash
## ~/.bashrc
__set_user_var() {
    if command -v base64 >/dev/null 2>&1; then
        printf "\033]1337;SetUserVar=%s=%s\007" "$1" "$(echo -n "$2" | base64)"
    fi
}

zellij() {
    local ori_multiplexer_list="$MULTIPLEXER_LIST"
    export MULTIPLEXER_LIST="zellij,$ori_multiplexer_list"
    __set_user_var IS_ZELLIJ true

    command zellij "$@"

    export MULTIPLEXER_LIST="$ori_multiplexer_list"
    __set_user_var IS_ZELLIJ false
}
```

fish:
```fish
## ~/.config/fish/functions/zellij.fish
function zellij
    function __fish_set_user_var
        if type -q base64
            printf "\033]1337;SetUserVar=%s=%s\007" "$argv[1]" (echo -n "$argv[2]" | base64)
        end
    end

    set -l ori_multiplexer_list $MULTIPLEXER_LIST
    set -gx MULTIPLEXER_LIST "zellij,$ori_multiplexer_list"
    __fish_set_user_var IS_ZELLIJ true

    command zellij $argv

    set -gx MULTIPLEXER_LIST $ori_multiplexer_list
    __fish_set_user_var IS_ZELLIJ false
end
```

It is recommended to use [zellij-autolock](https://github.com/fresh2dev/zellij-autolock) to automatically switch between Zellij's "Normal" and "Locked" modes. Also, please note that currently, `zellij`’s CLI support isn’t great, and you may experience screen flashes.

</details>

### WezTerm

<details>

Integrate with WezTerm by adding this to `~/.config/wezterm/wezterm.lua`:

```lua
---@param opts wezterm.key
---@param direction "left" | "down" | "up" | "right"
local activate_pane = function(opts, direction)
  opts.action = wezterm.action_callback(function(win, pane)
    if pane:get_user_vars().IS_NVIM == 'true' or pane:get_user_vars().IS_TMUX == 'true' or pane:get_user_vars().IS_ZELLIJ == 'true' then
      wezterm.background_child_process({ 'bash', '-ilc', -- For macOS users, use zsh instead
        'multiplexer activate_pane ' .. direction
      })
    else
      win:perform_action({ SendKey = { key = opts.key, mods = opts.mods } }, pane)
    end
  end)
  return opts
end

---@param opts wezterm.key
---@param direction "left" | "down" | "up" | "right"
---@param amount? number
local adjust_pane = function(opts, direction, amount)
  opts.action = wezterm.action_callback(function(win, pane)
    if pane:get_user_vars().IS_NVIM == 'true' or pane:get_user_vars().IS_TMUX == 'true' or pane:get_user_vars().IS_ZELLIJ == 'true' then
      wezterm.background_child_process({ 'bash', '-ilc', -- For macOS users, use zsh instead
        'multiplexer resize_pane ' .. direction
      })
    else
      win:perform_action({ SendKey = { key = opts.key, mods = opts.mods } }, pane)
    end
  end)
  return opts
end

config.set_environment_variables = {
  MULTIPLEXER_LIST = 'wezterm'
}
config.keys = {
  activate_pane({ key = 'h', mods = 'CTRL' }, 'left'),
  activate_pane({ key = 'j', mods = 'CTRL' }, 'down'),
  activate_pane({ key = 'k', mods = 'CTRL' }, 'up'),
  activate_pane({ key = 'l', mods = 'CTRL' }, 'right'),

  adjust_pane({ key = 'h', mods = 'CTRL|SHIFT' }, 'left'),
  adjust_pane({ key = 'j', mods = 'CTRL|SHIFT' }, 'down'),
  adjust_pane({ key = 'k', mods = 'CTRL|SHIFT' }, 'up'),
  adjust_pane({ key = 'l', mods = 'CTRL|SHIFT' }, 'right')
}
```

</details>

### Kitty

<details>

Integrate with Kitty by adding this to `~/.config/kitty/kitty.conf`:

```kitty
allow_remote_control  on
listen_on             unix:${TEMP}/mykitty     # or unix:@mykitty on Linux
env                   MULTIPLEXER_LIST=kitty

## For macOS users, use zsh instead
map ctrl+h          launch --copy-env --keep-focus --type background bash -ilc "multiplexer activate_pane left"
map ctrl+j          launch --copy-env --keep-focus --type background bash -ilc "multiplexer activate_pane down"
map ctrl+k          launch --copy-env --keep-focus --type background bash -ilc "multiplexer activate_pane up"
map ctrl+l          launch --copy-env --keep-focus --type background bash -ilc "multiplexer activate_pane right"
map ctrl+shift+h    launch --copy-env --keep-focus --type background bash -ilc "multiplexer resize_pane left"
map ctrl+shift+j    launch --copy-env --keep-focus --type background bash -ilc "multiplexer resize_pane down"
map ctrl+shift+k    launch --copy-env --keep-focus --type background bash -ilc "multiplexer resize_pane up"
map ctrl+shift+l    launch --copy-env --keep-focus --type background bash -ilc "multiplexer resize_pane right"

map --when-focus-on "var:IS_NVIM=true or var:IS_TMUX=true or var:IS_ZELLIJ" ctrl+h no_op
map --when-focus-on "var:IS_NVIM=true or var:IS_TMUX=true or var:IS_ZELLIJ" ctrl+j no_op
map --when-focus-on "var:IS_NVIM=true or var:IS_TMUX=true or var:IS_ZELLIJ" ctrl+k no_op
map --when-focus-on "var:IS_NVIM=true or var:IS_TMUX=true or var:IS_ZELLIJ" ctrl+l no_op
map --when-focus-on "var:IS_NVIM=true or var:IS_TMUX=true or var:IS_ZELLIJ" ctrl+shift+h no_op
map --when-focus-on "var:IS_NVIM=true or var:IS_TMUX=true or var:IS_ZELLIJ" ctrl+shift+j no_op
map --when-focus-on "var:IS_NVIM=true or var:IS_TMUX=true or var:IS_ZELLIJ" ctrl+shift+k no_op
map --when-focus-on "var:IS_NVIM=true or var:IS_TMUX=true or var:IS_ZELLIJ" ctrl+shift+l no_op
```

</details>

## Contributing

Contributions are welcome! Feel free to submit issues or pull requests for bugs, feature suggestions, or documentation improvements.
