#!/usr/bin/env bash
# Claude Code SessionEnd hook. Drops the pane's record so a conversation you
# deliberately ended is not offered for resume after a restart.
#
# Registered in ~/.claude/settings.json by mac-dev-playbook tasks/tmux.yml.
#
# Only deletes the record if it still refers to THIS session. /clear and
# /resume end one session and start another in the same pane, and the relative
# ordering of the SessionEnd and SessionStart hooks is not guaranteed -- the
# ID check means a late-firing SessionEnd cannot wipe its successor's record.

set -uo pipefail

[ -n "${TMUX_PANE:-}" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/tmux-claude/panes"
record="$state_dir/${TMUX_PANE#%}"
[ -f "$record" ] || exit 0

payload="$(cat)"
ending_id="$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null)"
[ -n "$ending_id" ] || exit 0

recorded_id="$(cut -f1 "$record")"
[ "$recorded_id" = "$ending_id" ] && rm -f "$record"

exit 0
