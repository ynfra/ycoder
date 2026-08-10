#!/usr/bin/env bash
# Coder template tooling.
# Version: 2026-08-10-v4
#
#   ./ycoder.sh sync     [template...]     vendor vibestack/* into template folders
#   ./ycoder.sh create   <template>        scaffold custom.tf + startup.custom.sh
#   ./ycoder.sh validate [template...]     terraform validate, in a temp dir
#   ./ycoder.sh push     <template> [args] sync, then push (make push if present)
#   ./ycoder.sh download                   fetch latest ycoder.sh + vibestack into CWD
#   ./ycoder.sh version                    print script version
#
# Symlinked .tf files are silently dropped from the upload, so vibestack/ is
# copied into each template folder rather than referenced.
set -euo pipefail

VERSION=2026-08-10-v4
REPO=${YCODER_REPO:-ynfra/ycoder}
REF=${YCODER_REF:-master}

invoke_cwd=$PWD
cd "$(dirname "$0")"

src=vibestack

# banner <source> — header stamped into every generated file.
banner() {
  echo "###"
  echo "# Generated from $1 on $(date '+%Y-%m-%d %H:%M:%S')"
  echo "# Do not edit — edit the source and re-run ./ycoder.sh sync"
  echo "###"
}

# md_banner <source> — HTML-comment banner for Markdown.
md_banner() {
  echo "<!--"
  echo "Generated from $1 on $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Do not edit — edit the source and re-run ./ycoder.sh sync"
  echo "-->"
}

# render <dir> — write the shared files into a folder.
render() {
  local name
  name=$(basename "$1")

  { banner "$src/main.tf"; echo; cat "$src/main.tf"; } >"$1/main.tf"

  # Keep the shebang first so the file stays lintable on its own.
  { head -1 "$src/startup.sh"; banner "$src/startup.sh"; tail -n +2 "$src/startup.sh"; } >"$1/startup.sh"
  chmod +x "$1/startup.sh"

  { banner "$src/Makefile"; echo; sed "s/coder templates push vibestack /coder templates push ${name} /" "$src/Makefile"; } >"$1/Makefile"

  { banner "$src/.env.example"; echo; cat "$src/.env.example"; } >"$1/.env.example"

  { md_banner "$src/README.md"; echo; cat "$src/README.md"; } >"$1/README.md"
}

is_template() {
  [ -d "$1" ] || { echo "$1: not a template (no such directory)" >&2; exit 1; }
}

# All sibling dirs except the sync source (vibestack).
list_templates() {
  local d
  for d in */; do
    d=${d%/}
    [ -d "$d" ] || continue
    [ "$d" = "$src" ] && continue
    printf '%s\n' "$d"
  done
}

# Scaffold a new template folder, then sync vibestack into it.
cmd_create() {
  local t=$1
  [ -n "$t" ] || { echo "usage: ./ycoder.sh create <template>" >&2; exit 1; }
  [ "$t" = "$src" ] && { echo "error: cannot create over $src (the sync source)" >&2; exit 1; }
  [ -e "$t" ] && { echo "error: $t already exists" >&2; exit 1; }

  mkdir -p "$t"
  cat >"$t/custom.tf" <<EOF
# ${t} — template-specific Terraform (apps, volumes, modules, ...).
# Merges with the synced vibestack main.tf as one root config.
EOF

  cat >"$t/startup.custom.sh" <<EOF
# ${t} — runs after shared startup.sh (concatenated by main.tf).
# Helpers available: log, ok, link_file, summary_lines, summary.

WORKSPACE_LABEL="${t}"

# Example:
# log "Setting up ${t}..."
# summary_lines+=("     • ${t}          custom workspace bits")

summary
EOF
  chmod +x "$t/startup.custom.sh"

  render "$t"
  echo "▸ created $t (custom.tf, startup.custom.sh, synced from $src)"
}

cmd_sync() {
  for t in "$@"; do
    is_template "$t"
    # vibestack is the source; it has nothing to sync into itself.
    if [ "$t" = "$src" ]; then
      echo "▸ $src is the source, nothing to sync"
      continue
    fi
    render "$t"
    echo "▸ synced $src -> $t"
  done
}

# Validate a copy so the repo never gets a .terraform folder.
cmd_validate() {
  local cache=${TF_PLUGIN_CACHE_DIR:-$HOME/.terraform.d/plugin-cache}
  mkdir -p "$cache"

  for t in "$@"; do
    is_template "$t"
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT

    if [ -f "$t/custom.tf" ]; then cp "$t/custom.tf" "$tmp/"; fi
    if [ -f "$t/startup.custom.sh" ]; then cp "$t/startup.custom.sh" "$tmp/"; fi
    render "$tmp"
    (
      cd "$tmp"
      export TF_CLI_ARGS_init="" TF_PLUGIN_CACHE_DIR="$cache"
      terraform init -backend=false -input=false >/dev/null
      terraform validate
    )

    rm -rf "$tmp"
    trap - EXIT
    echo "▸ validated $t"
  done
}

# Pull the latest ycoder.sh and vibestack/ from GitHub into the caller's CWD.
cmd_download() {
  command -v gh >/dev/null || { echo "gh (GitHub CLI) is required for download" >&2; exit 1; }

  local dest=$invoke_cwd
  local tmp
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT

  echo "▸ fetching $REPO@$REF"
  gh api "repos/$REPO/tarball/$REF" | tar -xz -C "$tmp" --strip-components=1

  if [ ! -f "$tmp/ycoder.sh" ]; then
    echo "error: $REPO@$REF has no ycoder.sh" >&2
    exit 1
  fi
  if [ ! -d "$tmp/vibestack" ]; then
    echo "error: $REPO@$REF has no vibestack/" >&2
    exit 1
  fi

  local remote_ver
  remote_ver=$(grep -E '^VERSION=' "$tmp/ycoder.sh" | head -1 | cut -d= -f2)
  cp "$tmp/ycoder.sh" "$dest/ycoder.sh"
  chmod +x "$dest/ycoder.sh"
  echo "▸ ycoder.sh -> $dest/ycoder.sh (${remote_ver:-unknown})"

  # Preserve a local .env if present.
  local keep_env=
  if [ -f "$dest/vibestack/.env" ]; then
    keep_env=$(mktemp)
    cp "$dest/vibestack/.env" "$keep_env"
  fi

  rm -rf "$dest/vibestack"
  cp -a "$tmp/vibestack" "$dest/vibestack"

  if [ -n "$keep_env" ]; then
    mv "$keep_env" "$dest/vibestack/.env"
  fi

  rm -rf "$tmp"
  trap - EXIT
  echo "▸ vibestack/ -> $dest/vibestack"
}

case "${1:-}" in
  version|--version|-V)
    echo "$VERSION"
    ;;
  sync)
    shift
    if [ $# -eq 0 ]; then
      # shellcheck disable=SC2046
      set -- $(list_templates)
    fi
    [ $# -gt 0 ] || { echo "no templates to sync" >&2; exit 1; }
    cmd_sync "$@"
    ;;
  create)
    shift
    [ $# -eq 1 ] || { echo "usage: ./ycoder.sh create <template>" >&2; exit 1; }
    cmd_create "$1"
    ;;
  validate)
    shift
    if [ $# -eq 0 ]; then
      # shellcheck disable=SC2046
      set -- $(list_templates)
    fi
    [ $# -gt 0 ] || { echo "no templates to validate" >&2; exit 1; }
    cmd_validate "$@"
    ;;
  push)
    shift
    [ $# -ge 1 ] || { echo "usage: ./ycoder.sh push <template> [args...]" >&2; exit 1; }
    t=$1
    shift
    cmd_sync "$t"
    if [ -f "$t/Makefile" ] && make -C "$t" -n push >/dev/null 2>&1; then
      echo "▸ using make push in $t"
      make -C "$t" push
    else
      coder templates push "$t" -d "$t" "$@"
    fi
    ;;
  download)
    cmd_download
    ;;
  *)
    echo "ycoder.sh $VERSION" >&2
    echo "usage: ./ycoder.sh sync     [template...]" >&2
    echo "       ./ycoder.sh create   <template>" >&2
    echo "       ./ycoder.sh validate [template...]" >&2
    echo "       ./ycoder.sh push     <template> [args...]" >&2
    echo "       ./ycoder.sh download" >&2
    echo "       ./ycoder.sh version" >&2
    exit 1
    ;;
esac
