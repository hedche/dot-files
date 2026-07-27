#!/usr/bin/env bash
# tmux-resurrect @resurrect-hook-post-restore-all
#
# For each Claude conversation that was running when the environment was saved,
# type `claude --resume <id>` into the pane it belonged to.
#
# The command is typed but NOT executed -- no Enter is sent. After a reboot you
# might have a dozen of these; launching them all unprompted would start a dozen
# Claude processes at once. You press Enter on the ones you actually want.

set -uo pipefail

resurrect_dir="$(tmux show-option -gqv @resurrect-dir)"
[ -n "$resurrect_dir" ] || resurrect_dir="$HOME/.tmux/resurrect"
resurrect_dir="${resurrect_dir/#\~/$HOME}"

saved="$resurrect_dir/claude-sessions.txt"
[ -f "$saved" ] || exit 0

while IFS=$'\t' read -r sess win pane session_id cwd; do
    [ -n "${session_id:-}" ] || continue
    target="$sess:$win.$pane"

    # The pane may not have come back (window closed before the last save, or a
    # partial restore).
    current_cmd="$(tmux display-message -p -t "$target" '#{pane_current_command}' 2>/dev/null)" || continue
    [ -n "$current_cmd" ] || continue

    # Only type into an idle shell. If something else is running in there,
    # injecting keystrokes would go into that program's stdin.
    case "$current_cmd" in
        zsh|bash|sh|fish|dash|ksh) ;;
        *) continue ;;
    esac

    # -l sends the string literally, so nothing in the UUID is interpreted as a
    # tmux key name. No Enter: see header.
    tmux send-keys -t "$target" -l "claude --resume $session_id"
done < "$saved"

exit 0
