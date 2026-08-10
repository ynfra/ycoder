#!/usr/bin/env bash
# Shared startup. Concatenated with optional startup.custom.sh by main.tf.
set -e

c_reset=$'\033[0m'; c_cyan=$'\033[36m'; c_green=$'\033[32m'; c_dim=$'\033[2m'
log() { printf '%s  ▸%s %s\n' "$c_cyan" "$c_reset" "$*"; }
ok() { printf '%s  ✓%s %s\n' "$c_green" "$c_reset" "$*"; }

printf '\n%s' "$c_cyan"
cat <<'BANNER'
   ┌──────────────────────────────────────────────┐
   │   coder workspace                            │
   │   code-server · opencode · Docker-in-Docker  │
   └──────────────────────────────────────────────┘
BANNER
printf '%s\n' "$c_reset"

# Seed home from /etc/skel on first start.
if [ ! -f ~/.init_done ]; then
  log "Preparing home directory from /etc/skel"
  cp -rT /etc/skel ~ 2>/dev/null || true
  touch ~/.init_done
fi

# bare_host URL → hostname (strips scheme and any trailing path).
bare_host() { h=${1#*://}; printf '%s' "${h%%/*}"; }

# Trust the GitLab host key. `|| true` is load-bearing: the host may be
# unresolvable (VPN down), and `set -e` would kill the whole startup.
mkdir -p ~/.ssh
if [ -n "${GITLAB_HOST:-}" ]; then
  ssh-keyscan "$(bare_host "$GITLAB_HOST")" >>~/.ssh/known_hosts 2>/dev/null || true
fi

# Disable code-server workspace trust prompt.
mkdir -p ~/.local/share/code-server/User
cat >~/.local/share/code-server/User/settings.json <<'JSON'
{
  "security.workspace.trust.enabled": false
}
JSON

# Shared ~/.ai (bind-mounted). ~/.claude stays local — not linked.
sudo chown coder:coder /home/coder/.ai 2>/dev/null || true

log "Linking opencode config into shared ~/.ai"
mkdir -p ~/.ai/config-opencode ~/.ai/local-opencode ~/.ai/docker

# Share opencode login+config; keep sessions DB local.
# Replace stale whole-dir symlinks from older templates with real dirs.
for d in ~/.config/opencode ~/.local/share/opencode; do
  if [ -L "$d" ]; then rm -f "$d"; fi
done
mkdir -p ~/.config/opencode ~/.local/share/opencode

# link_file SRC DST: symlink DST→SRC; adopt existing DST into SRC if SRC missing.
link_file() {
  if [ ! -e "$1" ] && [ -f "$2" ] && [ ! -L "$2" ]; then mv "$2" "$1"; fi
  ln -sfn "$1" "$2"
}
link_file ~/.ai/config-opencode/opencode.json ~/.config/opencode/opencode.json
link_file ~/.ai/local-opencode/auth.json ~/.local/share/opencode/auth.json
link_file ~/.ai/local-opencode/mcp-auth.json ~/.local/share/opencode/mcp-auth.json

# link SRC DST: symlink only if DST does not exist.
link() { [ -e "$2" ] || [ -L "$2" ] || ln -sfn "$1" "$2"; }
link ~/.ai/docker ~/.docker
ok "opencode login+config shared; sessions local; ~/.claude stays local"

mkdir -p ~/code

# AGENTS.md is rewritten every start; CLAUDE.md is seeded once so edits survive.
log "Writing ~/AGENTS.md"
cat >~/AGENTS.md <<'MD'
# Agent guide

- Runtimes preinstalled: PHP, Composer, Node (npm), Bun, Deno, Python 3, Go.
- Manage the opencode server with `opencode-ctl` (run `opencode-ctl help`).
- Use the `opencode` CLI to manage opencode sessions, history, etc.
- Use `git` for git, `glab` for GitLab, and `gh` for GitHub.
- Use `agent-browser` to drive a browser and run E2E flows.
- Use the `coder` CLI to manage Coder (run `coder --help`).
- Nested Docker is ready — `docker ps` and `docker compose` work out of the box.
- Projects live under `~/code`.
MD

[ -f ~/CLAUDE.md ] || printf '@AGENTS.md\n' >~/CLAUDE.md

# opencode-ctl — install here so the server starts after symlinks exist.
log "Installing opencode-ctl CLI (/usr/local/bin/opencode-ctl)"
sudo tee /usr/local/bin/opencode-ctl >/dev/null <<'CTL'
#!/usr/bin/env bash
# Manage the background `opencode serve` daemon.
PORT=4096
LOG="$HOME/.cache/opencode/serve.log"

is_up() { curl -sf -o /dev/null "http://localhost:$PORT" 2>/dev/null; }

start() {
  if is_up; then echo "opencode already up on :$PORT"; return 0; fi
  mkdir -p "$HOME/.cache/opencode"
  cd "$HOME" || return 1
  nohup opencode serve --hostname 0.0.0.0 --port "$PORT" >"$LOG" 2>&1 &
  for i in $(seq 1 15); do
    if is_up; then echo "opencode up on :$PORT (cwd: $HOME)"; return 0; fi
    sleep 1
  done
  echo "opencode did not come up; last log:"; tail -n 30 "$LOG" 2>/dev/null
  return 1
}

usage() {
  cat <<'USAGE'
opencode-ctl — manage the background `opencode serve` daemon

usage: opencode-ctl {start|stop|restart|status|logs|help}

  start    start the server (idempotent)
  stop     stop the server
  restart  restart the server
  status   report up / down
  logs     follow the server log
  help     show this help
USAGE
}

case "$1" in
  start)          start ;;
  stop)           pkill -f "opencode serve" && echo "stopped" || echo "not running" ;;
  restart)        pkill -f "opencode serve"; sleep 1; start ;;
  status)         if is_up; then echo "up on :$PORT"; else echo "down"; fi ;;
  logs)           tail -n +1 -f "$LOG" ;;
  help|-h|--help) usage ;;
  *)              usage; exit 1 ;;
esac
CTL
sudo chmod +x /usr/local/bin/opencode-ctl

# xclaude — run claude with XCLAUDE_* mapped to ANTHROPIC_* for this call only.
log "Installing xclaude shortcut (/usr/local/bin/xclaude)"
sudo tee /usr/local/bin/xclaude >/dev/null <<'XCL'
#!/usr/bin/env bash
# claude via XCLAUDE_* gateway config.
if [ -z "$XCLAUDE_AUTH_TOKEN" ]; then
  echo "xclaude: XCLAUDE_AUTH_TOKEN is not set (configure the xclaude_auth_token template variable)" >&2
  exit 1
fi

# BYPASS wins; else --permission-mode auto unless PERMISSION_MODE is falsy.
pre_args=()
case "${XCLAUDE_BYPASS:-false}" in
  true | 1 | yes | on) pre_args+=(--dangerously-skip-permissions) ;;
  *)
    case "${XCLAUDE_PERMISSION_MODE:-true}" in
      false | 0 | no | off | "") ;;
      *) pre_args+=(--permission-mode auto) ;;
    esac
    ;;
esac

exec env \
  ANTHROPIC_BASE_URL="$XCLAUDE_BASE_URL" \
  ANTHROPIC_AUTH_TOKEN="$XCLAUDE_AUTH_TOKEN" \
  ANTHROPIC_MODEL="$XCLAUDE_MODEL" \
  ANTHROPIC_DEFAULT_SONNET_MODEL="$XCLAUDE_MODEL" \
  ANTHROPIC_DEFAULT_OPUS_MODEL="$XCLAUDE_MODEL" \
  ANTHROPIC_DEFAULT_HAIKU_MODEL="${XCLAUDE_SMALL_MODEL:-$XCLAUDE_MODEL}" \
  CLAUDE_CODE_SUBAGENT_MODEL="$XCLAUDE_MODEL" \
  ANTHROPIC_REASONING_EFFORT="$XCLAUDE_EFFORT" \
  CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1 \
  claude "${pre_args[@]}" "$@"
XCL
sudo chmod +x /usr/local/bin/xclaude

# Start opencode; don't abort startup on failure.
log "Starting opencode server on :4096"
opencode-ctl start || true

# glab auth — glab wants a bare hostname, not a URL.
if command -v glab >/dev/null 2>&1 && [ -n "${GITLAB_TOKEN:-}" ] && [ -n "${GITLAB_HOST:-}" ]; then
  gl_host=$(bare_host "$GITLAB_HOST")
  log "Authenticating glab with $gl_host"
  if printf '%s' "$GITLAB_TOKEN" | glab auth login --hostname "$gl_host" --stdin; then
    ok "glab authenticated ($gl_host)"
  else
    log "glab auth failed"
  fi
fi

# gh uses GITHUB_TOKEN from the env; just wire git HTTPS credentials.
if command -v gh >/dev/null 2>&1 && [ -n "${GITHUB_TOKEN:-}" ]; then
  log "Configuring gh git credential helper from GITHUB_TOKEN"
  if gh auth setup-git 2>/dev/null; then
    ok "gh authenticated via GITHUB_TOKEN"
  else
    log "gh setup-git failed"
  fi
fi

# Clone GIT_REPO into ~/code on first start (skip if already present).
if [ -n "${GIT_REPO:-}" ]; then
  folder=$(basename "$GIT_REPO" .git)
  dest=~/code/"$folder"
  if [ -d "$dest" ] && [ -n "$(ls -A "$dest" 2>/dev/null)" ]; then
    ok "Project '$folder' already present, skipping clone"
  else
    log "Cloning $GIT_REPO into $dest"
    git clone "$GIT_REPO" "$dest" || log "git clone failed — check repo URL and git auth"
  fi
fi

# Wait for DIND before finishing.
log "Waiting for Docker (DIND) to be ready"
until docker info >/dev/null 2>&1; do
  sleep 1
done
ok "Docker is ready"

# docker login via DOCKER_REGISTRY_* (creds land in shared ~/.docker).
if [ -n "${DOCKER_REGISTRY_TOKEN:-}" ]; then
  if [ -z "${DOCKER_REGISTRY_HOST:-}" ] || [ -z "${DOCKER_REGISTRY_USER:-}" ]; then
    log "DOCKER_REGISTRY_TOKEN set but HOST/USER missing — skipping docker login"
  else
    log "Logging into Docker registry $DOCKER_REGISTRY_HOST"
    if printf '%s' "$DOCKER_REGISTRY_TOKEN" | docker login "$DOCKER_REGISTRY_HOST" \
      -u "$DOCKER_REGISTRY_USER" --password-stdin >/dev/null; then
      ok "Docker registry login OK ($DOCKER_REGISTRY_HOST)"
    else
      log "Docker registry login failed"
    fi
  fi
fi

# Shared summary lines; startup.custom.sh can append and call `summary`.
summary_lines=(
  "     • code-server   VS Code in the browser (opens ~)"
  "     • opencode      http://localhost:4096"
  "                     manage with: opencode-ctl {status|start|stop|restart|logs}"
  "     • Docker (DIND) docker ps / compose work; put projects under ~/code"
  "     • AI state      opencode login+config shared via ~/.ai (sessions local)"
  "                     ~/.claude is local — not shared, not symlinked"
  "     • Env           OPENCODE_* experimental flags enabled"
)

summary() {
  printf '\n%s   %s is ready 🚀\n%s%s\n' "$c_green" "${WORKSPACE_LABEL:-workspace}" "$c_reset" "$c_dim"
  printf '%s\n' "${summary_lines[@]}"
  printf '%s\n' "$c_reset"
}
