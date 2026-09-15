#!/usr/bin/env bash
# Claude Code SessionStart hook. Records which Claude session is running in
# which tmux pane, so it can be resumed there after a restart. A fresh record
# is also how claude-resume-queue.sh knows a resumed session is up.
#
# Registered in ~/.claude/settings.json by mac-dev-playbook tasks/tmux.yml.
# Reads the hook payload as JSON on stdin.
#
# Keyed on $TMUX_PANE (e.g. "%12"). Pane IDs do NOT survive a tmux server
# restart, so this is only half the mapping -- resurrect-save-claude.sh
# resolves live pane IDs to stable session:window.pane coordinates at save time.

set -uo pipefail

# Not inside tmux, or no way to parse the payload: nothing useful to record.
[ -n "${TMUX_PANE:-}" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/tmux-claude/panes"
mkdir -p "$state_dir" || exit 0

payload="$(cat)"
session_id="$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null)"
cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)"

[ -n "$session_id" ] || exit 0

# "%12" -> "12", so it is usable as a filename.
printf '%s\t%s\n' "$session_id" "$cwd" > "$state_dir/${TMUX_PANE#%}"

exit 0
