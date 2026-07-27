#!/usr/bin/env bash
# tmux-resurrect @resurrect-hook-post-save-all
#
# Turns the pane-ID-keyed records written by claude-session-record.sh into
# coordinate-keyed ones that survive a tmux server restart.
#
# Pane IDs (%12) are reassigned when the server restarts; what resurrect
# faithfully recreates is session_name:window_index.pane_index. So we resolve
# one to the other here, while the panes still exist.
#
# Note we never try to detect Claude by process name: pane_current_command
# reports the version string ("2.1.220") rather than "claude", so the usual
# `ps`-based detection other plugins use does not work. The SessionStart hook
# is the source of truth instead.

set -uo pipefail

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/tmux-claude/panes"

resurrect_dir="$(tmux show-option -gqv @resurrect-dir)"
[ -n "$resurrect_dir" ] || resurrect_dir="$HOME/.tmux/resurrect"
resurrect_dir="${resurrect_dir/#\~/$HOME}"
mkdir -p "$resurrect_dir" || exit 0

out="$resurrect_dir/claude-sessions.txt"
tmp="$out.tmp.$$"
: > "$tmp"

[ -d "$state_dir" ] || { mv -f "$tmp" "$out"; exit 0; }

live_panes="$(tmux list-panes -a -F '#{pane_id}')"

while IFS=' ' read -r pane_id sess win pane; do
    record="$state_dir/${pane_id#%}"
    [ -f "$record" ] || continue

    IFS=$'\t' read -r session_id cwd < "$record"
    [ -n "${session_id:-}" ] || continue

    printf '%s\t%s\t%s\t%s\t%s\n' "$sess" "$win" "$pane" "$session_id" "${cwd:-}" >> "$tmp"
done < <(tmux list-panes -a -F '#{pane_id} #{session_name} #{window_index} #{pane_index}')

mv -f "$tmp" "$out"

# Drop records for panes that no longer exist, so the state dir does not grow
# without bound as panes come and go.
for record in "$state_dir"/*; do
    [ -f "$record" ] || continue
    pane_id="%$(basename "$record")"
    printf '%s\n' "$live_panes" | grep -qxF "$pane_id" || rm -f "$record"
done

exit 0
