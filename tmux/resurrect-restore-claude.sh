#!/usr/bin/env bash
# tmux-resurrect @resurrect-hook-post-restore-all
#
# Hands the Claude conversations that were running at the last save to
# claude-resume-queue.sh, which resumes them into their panes a few at a time.
# See that script for the pacing, and ~/Library/Logs/claude-resume.log for
# progress.
#
# Resurrect runs this hook synchronously, so the queue is started detached. All
# of its descriptors are redirected: an inherited stdout would keep tmux's
# run-shell waiting until the last session was up.

set -uo pipefail

log_file="${CLAUDE_RESUME_LOG:-$HOME/Library/Logs/claude-resume.log}"
mkdir -p "$(dirname "$log_file")" || exit 0

nohup "$(dirname "$0")/claude-resume-queue.sh" >> "$log_file" 2>&1 < /dev/null &

exit 0
