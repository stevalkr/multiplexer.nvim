#!/usr/bin/env bash

set -e
set -o pipefail

# --- Helper Functions ---
info() {
  echo "INFO: $*"
}

fail() {
  echo "FAIL: $*" >&2
  sleep 5
  exit 1
}

assert_eq() {
  if [[ "$1" != "$2" ]]; then
    fail "Assertion failed: '$1' does not equal '$2'. $3"
  fi
  info "✅ Assertion passed: '$1' == '$2'"
}

# Wrapper to run headless nvim with the correct plugin path
# Usage: nvim_exec <mux_list_str> <lua_command>
nvim_exec() {
  local lua_cmd=$1
  nvim -u NONE --headless \
    -c "set rtp+=$CWD" \
    -c "lua require('multiplexer').setup()" \
    -c "lua $lua_cmd" \
    -c "qa"
}

# Wrapper to get the current terminal pane ID
# Usage: current_pane_id <mux>
current_pane_id() {
  eval $(nvim_exec "require('multiplexer.mux.$TERMINAL').current_pane_id({ dry_run = true })")
}

# Wrapper to send text to the active pane by using the plugin's send_text
# Usage: term_send_text <text>
term_send_text() {
  local text="$1"
  nvim_exec "require('multiplexer.mux.$TERMINAL').send_text([[$text]], { id = '$(current_pane_id)', async = false })"
}

start_tmux() {
  TMUX=/tmp/tmux-e2e-test.socket
  tmux -S $TMUX kill-session -t e2e-test 2>/dev/null || true
  term_send_text "tmux -S $TMUX new-session -s e2e-test ';' \
                    bind-key -n C-h \"if -F '#{@pane-is-vim}' { send-keys C-h } { run-shell '/tmp/multiplexer activate_pane left' }\"  ';' \
                    bind-key -n C-j \"if -F '#{@pane-is-vim}' { send-keys C-j } { run-shell '/tmp/multiplexer activate_pane down' }\"  ';' \
                    bind-key -n C-k \"if -F '#{@pane-is-vim}' { send-keys C-k } { run-shell '/tmp/multiplexer activate_pane up' }\"    ';' \
                    bind-key -n C-l \"if -F '#{@pane-is-vim}' { send-keys C-l } { run-shell '/tmp/multiplexer activate_pane right' }\" ';' \
                  "
}

# Wrapper to start nvim in the terminal pane
# Usage: start_nvim <tag>
start_nvim() {
  local tag="$1"
  term_send_text "nvim -u NONE \
                    -c 'set rtp+=$CWD' \
                    -c 'autocmd FocusGained * silent !echo $tag > /tmp/active_nvim.log' \
                    -c 'lua require(\"multiplexer\").setup({ \
                          on_init = function() \
                            local multiplexer = require(\"multiplexer\") \
                            vim.keymap.set( { \"n\", \"i\" }, \"<C-h>\", multiplexer.activate_pane_left, \
                              { desc = \"Activate pane to the left\" } \
                            ) \
                            vim.keymap.set( { \"n\", \"i\" }, \"<C-l>\", multiplexer.activate_pane_right, \
                              { desc = \"Activate pane to the right\" } \
                            ) \
                          end \
                        })' \
                  "
}

# --- Core Test Logic ---
run_tests() {
  # Cleanup previous runs
  rm -f /tmp/active_nvim.log
  sleep 1

  info "--- E2E TEST START (Terminal: $TERMINAL) ---"

  # 1. Start a new terminal tab for testing
  info "Creating a new tab for testing..."
  if [[ "$TERMINAL" == "wezterm" ]]; then
    wezterm cli spawn --cwd $CWD
  elif [[ "$TERMINAL" == "kitty" ]]; then
    kitty @ launch --type=tab --cwd=$CWD
  fi
  sleep 1

  # 2. Split native terminal pane to the right
  info "Splitting $TERMINAL pane..."
  # Command not running in active pane, set id manually
  nvim_exec "require('multiplexer.mux.$TERMINAL').split_pane('l', { id = '$(current_pane_id)' })"
  sleep 1

  # 3. In the right pane, start tmux
  info "Starting tmux in right pane..."
  start_tmux
  sleep 1

  # 4. Split tmux pane to the right
  info "Splitting tmux pane..."
  # Command not running in TMUX, set $TMUX manually
  nvim_exec "vim.fn.setenv('TMUX', '$TMUX,'); require('multiplexer.mux.tmux').split_pane('l')"
  sleep 1

  # 5. In the right tmux pane, start nvim (will be tmux_nvim)
  info "Starting nvim in tmux pane..."
  start_nvim "tmux_nvim"
  sleep 1

  # 6. Switch to the left terminal pane twice (leaving tmux)
  info "Activating left pane twice..."
  term_send_text ""
  sleep 1
  term_send_text ""
  sleep 1

  # 7. In the left pane, start nvim (will be term_nvim)
  info "Starting nvim in terminal pane..."
  start_nvim "term_nvim"
  sleep 1

  # --- Verification ---
  info "--- Starting Navigation Verification ---"

  # Navigate right (from terminal to tmux)
  term_send_text ""
  sleep 1
  term_send_text ""
  sleep 1

  active_nvim=$(cat /tmp/active_nvim.log)
  assert_eq "$active_nvim" "tmux_nvim" "Focus should switch to tmux nvim."

  # Navigate left (from tmux to terminal)
  term_send_text ""
  sleep 1
  term_send_text ""
  sleep 1

  active_nvim=$(cat /tmp/active_nvim.log)
  assert_eq "$active_nvim" "term_nvim" "Focus should switch back to terminal nvim."

  info "--- E2E TEST PASS ---"
  # Cleanup
  term_send_text ":qa!" # quit term_nvim
  sleep 1
  term_send_text ""
  sleep 1
  term_send_text ""
  sleep 1
  term_send_text ":qa!" # quit tmux_nvim
  sleep 1
  term_send_text ""
  sleep 1
  term_send_text ""
  sleep 1
}


# --- Main ---
main() {
  # Detect terminal for the main script run
  info "Detecting terminal..."
  if [[ -n "$WEZTERM_EXECUTABLE" ]]; then
    TERMINAL="wezterm"
  elif [[ -n "$KITTY_PID" ]]; then
    TERMINAL="kitty"
  else
    fail "Unsupported terminal for E2E tests. Please run inside WezTerm or Kitty."
  fi
  info "Running in $TERMINAL."

  info "Setting multiplexer CLI..."
  cp ./scripts/multiplexer /tmp/multiplexer
  chmod u+x /tmp/multiplexer

  CWD=$(realpath .)

  run_tests
}

main "$@"
