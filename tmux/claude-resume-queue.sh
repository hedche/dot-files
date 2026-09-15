#!/usr/bin/env bash
# Resumes the Claude Code conversations that were running at the last
# tmux-resurrect save, back into the panes they belonged to -- a few at a time,
# so a reboot does not start a dozen Claude processes at once.
#
# Started in the background by resurrect-restore-claude.sh. Safe to re-run by
# hand: panes that are not at an idle shell, and conversations already running
# in another pane, are skipped.
#
# How it paces itself:
#   - Most recently active conversation first (transcript mtime).
#   - At most CLAUDE_RESUME_PARALLEL (default 2) starting at once. A slot frees
#     when Claude is actually up -- its SessionStart hook, claude-session-record.sh,
#     writes a fresh record for the pane -- rather than after a fixed delay.
#   - Before each launch, waits while the 1-minute load average is at or above
#     the core count or macOS reports memory pressure. The wait is capped at
#     CLAUDE_RESUME_GATE_MAX seconds (default 180) per launch, so a machine that
#     stays busy slows the queue down rather than stalling it.
#
# A session that exits or never starts is retried once, at the back of the
# queue. One still starting after CLAUDE_RESUME_TIMEOUT seconds (default 90) is
# NOT retried: Claude is most likely waiting at a prompt, and typing the command
# again would answer it. It is flagged instead.
#
# Progress: log lines on stdout (the restore hook appends them to
# ~/Library/Logs/claude-resume.log), "claude N/M" in the tmux status line via the
# @claude_resume option, and a macOS notification when the queue is done.

set -uo pipefail

parallel="${CLAUDE_RESUME_PARALLEL:-2}"
ready_timeout="${CLAUDE_RESUME_TIMEOUT:-90}"
gate_max="${CLAUDE_RESUME_GATE_MAX:-180}"
start_timeout=20  # seconds for a claude process to appear in the pane at all
launch_gap=3      # seconds between launches, so two never load transcripts together

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/tmux-claude"
panes_dir="$state_dir/panes"
lock_dir="$state_dir/resume.lock"
projects_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects"
ncpu="$(sysctl -n hw.ncpu)"

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

is_shell() { case "$1" in zsh|bash|sh|fish|dash|ksh) return 0 ;; esac; return 1; }

# Claude's pane_current_command is its version string ("2.1.272"), not "claude".
# Matching it specifically matters: a prompt hook such as direnv briefly shows up
# as the pane command too, and must not be mistaken for Claude starting.
is_claude() { case "$1" in claude|[0-9]*.[0-9]*.[0-9]*) return 0 ;; esac; return 1; }

pane_cmd() { tmux display-message -p -t "$1" '#{pane_current_command}' 2>/dev/null; }

refresh_status() {
    local c
    for c in $(tmux list-clients -F '#{client_name}' 2>/dev/null); do
        tmux refresh-client -S -t "$c" 2>/dev/null
    done
}

# ---------------------------------------------------------------------------
# One run at a time
# ---------------------------------------------------------------------------
mkdir -p "$state_dir" || exit 1
if ! mkdir "$lock_dir" 2>/dev/null; then
    other="$(cat "$lock_dir/pid" 2>/dev/null)"
    if [ -n "$other" ] && ps -p "$other" -o command= 2>/dev/null | grep -q claude-resume-queue; then
        log "already running as pid $other, exiting"
        exit 0
    fi
    # Left behind by a run that never finished (e.g. shut down mid-queue).
    rm -rf "$lock_dir"
    mkdir "$lock_dir" || exit 1
fi
echo "$$" > "$lock_dir/pid"
trap 'tmux set-option -gu @claude_resume 2>/dev/null; refresh_status; rm -rf "$lock_dir"' EXIT
trap 'exit 130' INT TERM

# ---------------------------------------------------------------------------
# Build the queue
# ---------------------------------------------------------------------------
resurrect_dir="$(tmux show-option -gqv @resurrect-dir)"
[ -n "$resurrect_dir" ] || resurrect_dir="$HOME/.tmux/resurrect"
resurrect_dir="${resurrect_dir/#\~/$HOME}"

saved="$resurrect_dir/claude-sessions.txt"
[ -f "$saved" ] || { log "no saved Claude sessions at $saved"; exit 0; }

# One line per conversation: last-active epoch, target, session id, cwd. Most
# recent first; a conversation saved against two panes keeps only the first, so
# it never ends up running twice.
queue_lines() {
    local sess win pane id cwd transcript mtime
    while IFS=$'\t' read -r sess win pane id cwd; do
        [ -n "${id:-}" ] || continue
        transcript="$(ls "$projects_dir"/*/"$id.jsonl" 2>/dev/null | head -1)"
        mtime=0
        [ -n "$transcript" ] && mtime="$(stat -f %m "$transcript")"
        printf '%s\t%s\t%s\t%s\n' "$mtime" "$sess:$win.$pane" "$id" "${cwd:-}"
    done < "$saved" | sort -t $'\t' -k1,1nr | awk -F '\t' '!seen[$3]++'
}

targets=(); ids=(); names=()
while IFS=$'\t' read -r _ target id cwd; do
    targets+=("$target"); ids+=("$id"); names+=("$(basename "${cwd:-?}")")
done < <(queue_lines)

total=${#ids[@]}
[ "$total" -gt 0 ] || { log "no saved Claude sessions to resume"; exit 0; }

# Per conversation: state is queued | starting | ready | failed | stuck | skipped.
state=(); attempts=(); pane_of=(); launched=(); seen=(); pending=()
for i in "${!ids[@]}"; do
    state[i]=queued; attempts[i]=0; pending+=("$i")
done

server_start="$(tmux display-message -p '#{start_time}')"
started_at="$(date +%s)"

label() { printf '%s (%s)' "${targets[$1]}" "${names[$1]}"; }

count() {
    local n=0 i
    for i in "${!ids[@]}"; do [ "${state[i]}" = "$1" ] && n=$((n + 1)); done
    echo "$n"
}

list_of() {
    local out="" i
    for i in "${!ids[@]}"; do [ "${state[i]}" = "$1" ] && out="$out${out:+, }${targets[i]}"; done
    echo "$out"
}

finish() {  # index, final state, message
    state[$1]="$2"
    log "$(label "$1") $3"
}

# True if session $1 is live in a pane other than $2. Records older than this
# tmux server belong to panes from before the restart and are ignored.
running_elsewhere() {
    local p rec
    while read -r p; do
        [ "$p" = "$2" ] && continue
        rec="$panes_dir/${p#%}"
        [ -f "$rec" ] && [ "$(stat -f %m "$rec")" -ge "$server_start" ] || continue
        [ "$(cut -f1 "$rec")" = "$1" ] || continue
        is_claude "$(pane_cmd "$p")" && return 0
    done < <(tmux list-panes -a -F '#{pane_id}')
    return 1
}

# Prints why the machine is too busy to start another session, or nothing.
busy_reason() {
    local load pressure
    load="$(sysctl -n vm.loadavg | awk '{print $2}')"
    # 1 = normal, 2 = warning, 4 = critical
    pressure="$(sysctl -n kern.memorystatus_vm_pressure_level 2>/dev/null)"
    if [ "${pressure:-1}" -gt 1 ]; then
        echo "memory pressure"
    elif awk -v l="$load" -v n="$ncpu" 'BEGIN { exit !(l >= n) }'; then
        echo "load $load on $ncpu cores"
    fi
}

last_status=""
show_progress() {
    local resolved problems text
    resolved=$(( total - $(count queued) - $(count starting) ))
    problems=$(( $(count failed) + $(count stuck) ))
    text="claude $resolved/$total"
    [ "$problems" -gt 0 ] && text="$text, $problems need a look"
    [ "$text" = "$last_status" ] && return
    tmux set-option -g @claude_resume "$text"
    refresh_status
    last_status="$text"
}

# A freshly restored pane may still be sourcing .zshrc. Keys sent then are
# echoed straight away but run later, which looks like a command that already
# finished. So wait for the prompt: cursor off column 0 and the screen no longer
# changing. Gives up after 15s.
wait_for_prompt() {
    local p="$1" prev="" cur x
    for _ in $(seq 1 30); do
        x="$(tmux display-message -p -t "$p" '#{cursor_x}' 2>/dev/null)"
        cur="$x|$(tmux capture-pane -p -t "$p" 2>/dev/null | cksum)"
        [ "$cur" = "$prev" ] && [ "${x:-0}" -gt 0 ] && return 0
        prev="$cur"
        sleep 0.5
    done
    return 1
}

# First non-blank line printed after the resume command was typed into the
# item's pane -- e.g. "No conversation found with session ID: ...".
command_output() {
    tmux capture-pane -p -t "${pane_of[$1]}" 2>/dev/null |
        awk -v c="claude --resume ${ids[$1]}" '
            index($0, c)       { n = NR; out = ""; next }
            n && out == "" && NF { out = $0 }
            END                { print out }'
}

launch() {
    local i="$1" p cmd
    p="$(tmux display-message -p -t "${targets[i]}" '#{pane_id}' 2>/dev/null)"
    if [ -z "$p" ]; then
        finish "$i" skipped "skipped: pane no longer exists"; return
    fi
    # Only type into an idle shell. If something else is running in there, the
    # keystrokes would go into that program's stdin.
    cmd="$(pane_cmd "$p")"
    if ! is_shell "$cmd"; then
        finish "$i" skipped "skipped: pane is busy running $cmd"; return
    fi
    if running_elsewhere "${ids[i]}" "$p"; then
        finish "$i" skipped "skipped: already running in another pane"; return
    fi
    wait_for_prompt "$p" || log "$(label "$i") prompt still not settled after 15s, typing anyway"

    attempts[i]=$(( attempts[i] + 1 ))
    pane_of[i]="$p"; launched[i]="$(date +%s)"; seen[i]=0; state[i]=starting
    # -l sends the string literally, so nothing in the UUID is read as a key name.
    tmux send-keys -t "$p" -l "claude --resume ${ids[i]}"
    tmux send-keys -t "$p" Enter
    log "$(label "$i") starting (attempt ${attempts[i]})"
}

retry_or_fail() {  # index, reason
    local i="$1"
    if [ "${attempts[i]}" -lt 2 ]; then
        state[i]=queued; pending+=("$i")
        log "$(label "$i") $2, will retry"
    else
        finish "$i" failed "failed: $2"
    fi
}

poll() {
    local i p rec cmd output now elapsed
    now="$(date +%s)"
    for i in "${!ids[@]}"; do
        [ "${state[i]}" = starting ] || continue
        p="${pane_of[i]}"
        rec="$panes_dir/${p#%}"
        elapsed=$(( now - launched[i] ))

        if [ -f "$rec" ] && [ "$(stat -f %m "$rec")" -ge "${launched[i]}" ] \
                && [ "$(cut -f1 "$rec")" = "${ids[i]}" ]; then
            finish "$i" ready "ready in ${elapsed}s"
            continue
        fi

        if ! cmd="$(pane_cmd "$p")" || [ -z "$cmd" ]; then
            finish "$i" failed "failed: pane was closed"
        elif is_claude "$cmd"; then
            seen[i]=1
            [ "$elapsed" -ge "$ready_timeout" ] &&
                finish "$i" stuck "needs a look: still starting after ${ready_timeout}s, probably waiting at a prompt"
        elif ! is_shell "$cmd"; then
            # Something else in the foreground, e.g. a prompt hook. Give it time.
            [ "$elapsed" -ge "$start_timeout" ] &&
                retry_or_fail "$i" "claude never started (pane is running $cmd)"
        else
            # Back at the shell. Output after the command means it has already
            # run and exited, even if it was too quick to be seen running.
            output="$(command_output "$i")"
            if [ "${seen[i]}" = 1 ] || { [ -n "$output" ] && [ "$elapsed" -ge 2 ]; }; then
                retry_or_fail "$i" "claude exited during startup${output:+: $output}"
            elif [ "$elapsed" -ge "$start_timeout" ]; then
                retry_or_fail "$i" "claude never started"
            fi
        fi
    done
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
log "resuming $total Claude session(s), up to $parallel at a time"

last_launch=0
gate_since=0
while :; do
    poll
    now="$(date +%s)"

    if [ "${#pending[@]}" -gt 0 ] && [ "$(count starting)" -lt "$parallel" ] \
            && [ $(( now - last_launch )) -ge "$launch_gap" ]; then
        reason="$(busy_reason)"
        if [ -n "$reason" ] && [ "$gate_since" -eq 0 ]; then
            gate_since="$now"
            log "holding the queue: $reason"
        elif [ -n "$reason" ] && [ $(( now - gate_since )) -lt "$gate_max" ]; then
            :  # still holding
        else
            if [ -n "$reason" ]; then
                log "still busy after ${gate_max}s ($reason), starting the next one anyway"
            elif [ "$gate_since" -ne 0 ]; then
                log "machine has calmed down, carrying on"
            fi
            gate_since=0
            next="${pending[0]}"
            pending=("${pending[@]:1}")
            launch "$next"
            [ "${state[next]}" = starting ] && last_launch="$now"
        fi
    fi

    show_progress
    [ "${#pending[@]}" -eq 0 ] && [ "$(count starting)" -eq 0 ] && break
    sleep 1
done

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
elapsed=$(( $(date +%s) - started_at ))
summary="$(count ready) of $total back up in $((elapsed / 60))m$((elapsed % 60))s"
failed_list="$(list_of failed)"
stuck_list="$(list_of stuck)"
skipped_list="$(list_of skipped)"
[ -n "$failed_list" ] && summary="$summary. Failed: $failed_list"
[ -n "$stuck_list" ] && summary="$summary. Needs a look: $stuck_list"
[ -n "$skipped_list" ] && summary="$summary. Skipped: $skipped_list"
log "done: $summary"

# No notification for a run that launched nothing, e.g. a manual re-run where
# everything was already up.
launched_any=0
for i in "${!ids[@]}"; do [ "${attempts[i]}" -gt 0 ] && launched_any=1; done
if [ "$launched_any" -eq 1 ]; then
    if command -v terminal-notifier >/dev/null 2>&1; then
        terminal-notifier -title "Claude sessions" -message "$summary" -group claude-resume >/dev/null 2>&1
    else
        osascript -e "display notification \"$summary\" with title \"Claude sessions\"" >/dev/null 2>&1
    fi
fi

exit 0
