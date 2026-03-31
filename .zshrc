# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

export PATH="$HOME/Library/Python/3.9/bin:/opt/homebrew/bin:$PATH:/opt/yt.sh"

export PATH="$HOME/.local/bin:$PATH"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="ys"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git)

source $ZSH/oh-my-zsh.sh

# Make Ctrl+W behave like bash/readline: delete back to whitespace
# even when the word contains punctuation.
backward-kill-space-word() {
  local WORDCHARS=$'!"#$%&\'()*+,-./:;<=>?@[\\]^_`{|}~'
  zle backward-kill-word
}
zle -N backward-kill-space-word
bindkey -M emacs '^W' backward-kill-space-word
bindkey -M viins '^W' backward-kill-space-word

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

alias vrc='vim +104 $HOME/dv/dot-files/.zshrc'
alias vssh='vim $HOME/.ssh/config'
alias rcr='cp -f $HOME/dv/dot-files/.zshrc /Users/monty/.zshrc ; source /Users/monty/.zshrc'
alias n='nvim'
# Git
alias gs='git status'
alias gam='git commit -am'
alias gp='git pull'
alias ggp='git add . && git commit -m "$1" && git push'
# Docker
alias dps='docker ps -a'
alias dcu='docker-compose up -d'
alias dcd='docker-compose down'
# Networking
alias ifp='curl ifconfig.io'

# Neovim
alias fg='nvim +"Telescope live_grep"'
alias f='nvim +"Telescope find_files"'

# K8s
alias k=kubectl
complete -o default -F __start_kubectl k

# Talos
#alias t=talosctl
#source <(talosctl completion zsh)

# Navigation
alias dv='cd /Users/monty/dv'
alias mja='cd /Users/monty/dv/mja'
alias shelf='cd /Users/monty/dv/shelf'
alias dot='cd /Users/monty/dv/dot-files'
alias dl='cd /Users/monty/Downloads'
alias sshk='cd /Users/monty/dv/ssh-keys'

# Custom Commands
alias plex='/Users/monty/dv/plex-server/plex'

# Markdown preview
unalias md 2>/dev/null

md() {
  emulate -L zsh

  if [[ $# -ne 1 ]]; then
    printf 'usage: md <file.md>\n' >&2
    return 1
  fi

  local preview_dir
  preview_dir="$(
    python3 - "$1" <<'PY'
import hashlib
import html
import json
import os
import shutil
import sys
import tempfile
from pathlib import Path
from urllib.parse import quote

arg = sys.argv[1]
source_arg = Path(arg).expanduser()

try:
    source = source_arg.resolve(strict=True)
except FileNotFoundError:
    print(f"md: file not found: {arg}", file=sys.stderr)
    raise SystemExit(1)
except OSError as exc:
    print(f"md: unable to resolve path: {arg}: {exc}", file=sys.stderr)
    raise SystemExit(1)

if not source.is_file():
    print(f"md: not a file: {source}", file=sys.stderr)
    raise SystemExit(1)

if source.suffix.lower() not in {".md", ".markdown"}:
    print(f"md: expected a .md or .markdown file: {source}", file=sys.stderr)
    raise SystemExit(1)

preview_dir = Path(tempfile.gettempdir()) / f"md-preview-{hashlib.sha1(str(source).encode('utf-8')).hexdigest()[:12]}"
preview_dir.mkdir(parents=True, exist_ok=True)

source_link = preview_dir / "_source"

if source_link.exists() or source_link.is_symlink():
    source_link_target = None
    if source_link.is_symlink():
        try:
            source_link_target = source_link.resolve(strict=True)
        except OSError:
            source_link.unlink()
    if source_link.exists() or source_link.is_symlink():
        if source_link_target != source.parent.resolve():
            if source_link.is_dir() and not source_link.is_symlink():
                shutil.rmtree(source_link)
            else:
                source_link.unlink()

if not source_link.exists():
    source_link.symlink_to(source.parent, target_is_directory=True)

preview_path = preview_dir / "index.html"
preview_title = f"{source.name} — Markdown Preview"
markdown_path = f"_source/{quote(source.name)}"

document = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<base href="./_source/">
<title>{html.escape(preview_title)}</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/github-markdown-css@5.9.0/github-markdown.css">
<style>
  :root {{
    color-scheme: light dark;
  }}
  body {{
    margin: 0;
  }}
  .markdown-body {{
    box-sizing: border-box;
    min-width: 200px;
    max-width: 980px;
    margin: 0 auto;
    padding: 45px;
  }}
  @media (max-width: 767px) {{
    .markdown-body {{
      padding: 15px;
    }}
  }}
  @media (prefers-color-scheme: dark) {{
    body {{
      background-color: #0d1117;
    }}
  }}
  pre.fallback {{
    white-space: pre-wrap;
    overflow-wrap: anywhere;
  }}
</style>
</head>
<body>
<article id="content" class="markdown-body">
  <pre id="fallback" class="fallback"></pre>
</article>
<script src="https://cdn.jsdelivr.net/npm/marked/lib/marked.umd.js"></script>
<script src="https://cdn.jsdelivr.net/npm/dompurify@3.3.3/dist/purify.min.js"></script>
<script>
  const markdownPath = new URL({json.dumps(markdown_path)}, window.location.href).toString();
  const previewTitle = {json.dumps(preview_title)};
  const content = document.getElementById('content');
  const fallback = document.getElementById('fallback');
  let previousMarkdown = null;

  function renderMarkdown(markdownText) {{
    fallback.textContent = markdownText;

    if (window.marked && window.DOMPurify) {{
      const cleanedInput = markdownText.replace(/^[\\u200B\\u200C\\u200D\\u200E\\u200F\\uFEFF]/, '');
      const renderedHtml = window.marked.parse(cleanedInput);
      content.innerHTML = window.DOMPurify.sanitize(renderedHtml, {{USE_PROFILES: {{html: true}}}});
    }} else {{
      content.innerHTML = '';
      content.appendChild(fallback);
    }}

    document.title = previewTitle;
  }}

  async function refreshMarkdown() {{
    try {{
      const response = await fetch(`${{markdownPath}}?t=${{Date.now()}}`, {{cache: 'no-store'}});
      if (!response.ok) {{
        throw new Error(`HTTP ${{response.status}}`);
      }}

      const markdownText = await response.text();
      if (markdownText !== previousMarkdown) {{
        previousMarkdown = markdownText;
        renderMarkdown(markdownText);
      }}
    }} catch (error) {{
      if (previousMarkdown === null) {{
        fallback.textContent = `Unable to load preview source.\\n\\n${{error.message}}`;
      }}
    }}
  }}

  refreshMarkdown();
  setInterval(refreshMarkdown, 1000);
</script>
</body>
</html>
"""

preview_path.write_text(document, encoding="utf-8")
print(preview_dir)
PY
  )" || return 1

  local pid_file
  local port_file
  local pid
  local port
  local ready
  local attempt

  pid_file="$preview_dir/server.pid"
  port_file="$preview_dir/server.port"

  if [[ -f "$pid_file" && -f "$port_file" ]]; then
    pid="$(<"$pid_file")"
    port="$(<"$port_file")"

    if [[ -z "$pid" || -z "$port" ]]; then
      rm -f "$pid_file" "$port_file"
      pid=""
      port=""
    elif ! kill -0 "$pid" 2>/dev/null; then
      rm -f "$pid_file" "$port_file"
      pid=""
      port=""
    elif ! python3 - "$port" <<'PY'
import sys
import urllib.request

url = f"http://127.0.0.1:{sys.argv[1]}/"

try:
    with urllib.request.urlopen(url, timeout=0.5) as response:
        raise SystemExit(0 if response.status == 200 else 1)
except Exception:
    raise SystemExit(1)
PY
    then
      rm -f "$pid_file" "$port_file"
      pid=""
      port=""
    fi
  fi

  if [[ -z "$port" ]]; then
    port="$(
      python3 - <<'PY'
import socket

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
    sock.bind(("127.0.0.1", 0))
    print(sock.getsockname()[1])
PY
    )" || return 1

    nohup python3 -m http.server "$port" --bind 127.0.0.1 --directory "$preview_dir" >/dev/null 2>&1 &
    pid="$!"
    printf '%s\n' "$pid" > "$pid_file"
    printf '%s\n' "$port" > "$port_file"
    disown "$pid" 2>/dev/null || true

    ready=0
    for attempt in {1..20}; do
      if python3 - "$port" <<'PY'
import sys
import urllib.request

url = f"http://127.0.0.1:{sys.argv[1]}/"

try:
    with urllib.request.urlopen(url, timeout=0.5) as response:
        raise SystemExit(0 if response.status == 200 else 1)
except Exception:
    raise SystemExit(1)
PY
      then
        ready=1
        break
      fi

      sleep 0.1
    done

    if [[ "$ready" -ne 1 ]]; then
      printf 'md: preview server did not become ready\n' >&2
      kill "$pid" 2>/dev/null
      rm -f "$pid_file" "$port_file"
      return 1
    fi
  fi

  open "http://127.0.0.1:$port/"
}

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
[[ $commands[kubectl] ]] && source <(kubectl completion zsh)

# Added by Antigravity
export PATH="/Users/monty/.antigravity/antigravity/bin:$PATH"
eval "$(direnv hook zsh)"

# bun completions
[ -s "/Users/monty/.bun/_bun" ] && source "/Users/monty/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
