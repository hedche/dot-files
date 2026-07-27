#!/usr/bin/env bash
# Started at login by the uk.leafbit.tmux-server LaunchAgent.
#
# Brings up a tmux server headlessly so tmux-continuum's restore-on-server-start
# fires. Nothing is displayed -- by the time you open a terminal and run
# `tmux a`, the sessions are already there.
#
# This replaces tmux-continuum's own @continuum-boot, which opens a GUI terminal
# window at login and supports only Terminal.app/iTerm2/kitty/Alacritty. Ghostty
# is not among them.

set -uo pipefail

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

if ! command -v tmux >/dev/null 2>&1; then
    log "tmux not found on PATH ($PATH) -- check EnvironmentVariables in the LaunchAgent plist"
    exit 1
fi

# Already running (e.g. the agent was re-bootstrapped mid-session). Leave it be:
# continuum only restores on server start, so there is nothing to do and
# plenty to break.
if tmux list-sessions >/dev/null 2>&1; then
    log "tmux server already running, nothing to do"
    exit 0
fi

log "starting tmux server"
# Sourcing .tmux.conf loads tpm -> continuum, which sees @continuum-restore 'on'
# and restores the last saved environment.
tmux new-session -d -s _boot

# Restore is asynchronous. Wait for it to produce something before tidying up.
for _ in $(seq 1 60); do
    others="$(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep -vxF '_boot' | wc -l | tr -d ' ')"
    [ "${others:-0}" -gt 0 ] && break
    sleep 1
done

if [ "${others:-0}" -gt 0 ]; then
    log "restored $others session(s), removing bootstrap session"
    tmux kill-session -t _boot 2>/dev/null
else
    # Nothing was restored -- either no save exists yet, or restore failed.
    # Keep _boot so the server (and the next continuum save) stays alive, and
    # so the empty session is a visible hint that something went wrong.
    log "no sessions restored; leaving _boot in place"
fi

exit 0
