#!/usr/bin/env bash
# Coder template tooling.
# Version: 2026-08-12-v6
#
#   ./ycoder.sh sync     [template...]     vendor vibestack/* into template folders
#   ./ycoder.sh create   <template>        scaffold custom.tf + startup.custom.sh + CUSTOM.md
#   ./ycoder.sh validate [template...]     terraform validate, in a temp dir
#   ./ycoder.sh push     <template> [args] sync, then push (make push if present)
#   ./ycoder.sh download                   fetch latest ycoder.sh + vibestack next to this script
#   ./ycoder.sh agent                      print the rules for AI agents
#   ./ycoder.sh version                    print script version
#
# Symlinked .tf files are silently dropped from the upload, so vibestack/ is
# copied into each template folder rather than referenced.
set -euo pipefail

VERSION=2026-08-12-v6
REPO=${YCODER_REPO:-ynfra/ycoder}
REF=${YCODER_REF:-master}

# All commands act in the folder that holds this script (not the caller CWD).
cd "$(dirname "$0")"
script_dir=$PWD

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

  # Keep the frontmatter first so Coder reads it. The banner goes after it.
  # The name lines get the template folder name.
  if head -1 "$src/README.md" | grep -q '^---$'; then
    local fm_end
    fm_end=$(awk 'NR > 1 && /^---$/ { print NR; exit }' "$src/README.md")
    {
      head -n "$fm_end" "$src/README.md" |
        sed -e "s/^name: .*/name: ${name}/" -e "s/^display_name: .*/display_name: ${name}/"
      echo
      md_banner "$src/README.md"
      tail -n +$((fm_end + 1)) "$src/README.md" | sed "s/^# Vibestack$/# ${name}/"
    } >"$1/README.md"
  else
    { md_banner "$src/README.md"; echo; cat "$src/README.md"; } >"$1/README.md"
  fi
}

# A folder belongs to this tool when its main.tf carries the generated banner.
# A folder with a hand-written main.tf is somebody else's template.
is_managed() {
  [ -f "$1/main.tf" ] && head -4 "$1/main.tf" | grep -q "^# Generated from $src/main.tf"
}

is_template() {
  [ -d "$1" ] || { echo "$1: not a template (no such directory)" >&2; exit 1; }
  [ "$1" = "$src" ] && return 0
  is_managed "$1" || {
    echo "$1: not managed by this tool (main.tf has no banner) — use: ./ycoder.sh create <template>" >&2
    exit 1
  }
}

# All managed sibling dirs except the sync source (vibestack).
list_templates() {
  local d
  for d in */; do
    d=${d%/}
    [ -d "$d" ] || continue
    [ "$d" = "$src" ] && continue
    is_managed "$d" || continue
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

  # CUSTOM.md — the rules of this folder for AI agents and for people.
  sed "s/{{name}}/${t}/g" >"$t/CUSTOM.md" <<'MD'
# {{name}} — notes for AI agents

This folder is a Coder template. Read `README.md` for the workspace itself. Run
`../ycoder.sh agent` for the rules of the tool.

## Change these files

| File                | What goes in it                        |
| ------------------- | -------------------------------------- |
| `custom.tf`         | More Terraform: apps, volumes, modules |
| `startup.custom.sh` | More startup steps                     |
| `CUSTOM.md`         | Your notes about this template         |
| `.env`              | Secret values. Git ignores this file   |

## Do not change these files

`main.tf`, `startup.sh`, `Makefile`, `.env.example` and `README.md` come from
`vibestack/`. Every file has a banner. The next `./ycoder.sh sync` removes your
changes. Change the file in `vibestack/` instead.

## Rules

- Terraform reads `custom.tf` together with `main.tf`. Do not repeat a block
  from `main.tf`.
- Give your apps `order = 3` or more. code-server uses 1. opencode uses 2.
- `startup.custom.sh` runs after `startup.sh`. It can use `log`, `ok`,
  `link_file`, `summary_lines` and `summary`. Set `WORKSPACE_LABEL` first. Call
  `summary` last.
- Put secret values in `.env`. Never put them in a `.tf` file or in a document.
- Run `../ycoder.sh validate {{name}}` before every push.
- Push with `../ycoder.sh push {{name}}`.
MD

  render "$t"
  echo "▸ created $t (custom.tf, startup.custom.sh, CUSTOM.md, synced from $src)"
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

# Pull the latest ycoder.sh and vibestack/ next to this script (self-update).
cmd_download() {
  command -v gh >/dev/null || { echo "gh (GitHub CLI) is required for download" >&2; exit 1; }

  local dest=$script_dir
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
  # Atomic replace so this running script updates itself safely.
  cp "$tmp/ycoder.sh" "$dest/ycoder.sh.new"
  chmod +x "$dest/ycoder.sh.new"
  mv "$dest/ycoder.sh.new" "$dest/ycoder.sh"
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

usage() {
  cat <<'USAGE'
usage: ./ycoder.sh sync     [template...]   Copy the vibestack files into templates
       ./ycoder.sh create   <template>      Make a new template
       ./ycoder.sh validate [template...]   Run terraform validate in a temp folder
       ./ycoder.sh push     <template>      Sync, then push to Coder
       ./ycoder.sh download                 Get the newest ycoder.sh and vibestack
       ./ycoder.sh agent                    Show the rules for AI agents
       ./ycoder.sh version                  Show the version of the script
USAGE
}

# The rules of this folder, for an AI agent that reads the output.
cmd_agent() {
  cat <<'AGENT'
ycoder — rules for AI agents

FILES
  vibestack/                    The source. Change the files here
  <template>/main.tf            Generated from vibestack. Do not change
  <template>/startup.sh         Generated from vibestack. Do not change
  <template>/Makefile           Generated from vibestack. Do not change
  <template>/.env.example       Generated from vibestack. Do not change
  <template>/README.md          Generated from vibestack. Do not change
  <template>/custom.tf          Yours. More Terraform
  <template>/startup.custom.sh  Yours. More startup steps
  <template>/CUSTOM.md          Yours. The rules of that folder
  <template>/.env               Yours. Secret values. Git ignores this file

RULES
  1. Change a file in vibestack/. Then run: ./ycoder.sh sync <template>
  2. Do not change a generated file. Every one has a banner. The next sync
     removes your change.
  3. Always give the name of the template. With no name, sync and validate
     act on every managed folder.
  4. Put the changes of one template in custom.tf or startup.custom.sh.
  5. Terraform reads custom.tf together with main.tf as one plan.
  6. Give your apps order = 3 or more. code-server uses 1. opencode uses 2.
  7. startup.custom.sh runs after startup.sh. Use the helpers log, ok,
     link_file, summary_lines and summary. Set WORKSPACE_LABEL first. Call
     summary last.
  8. Put a secret value in .env. Never in a .tf file or in a document.
  9. Run ./ycoder.sh validate <template> before every push.
 10. A folder with a hand-written main.tf is not a template of this tool. The
     tool skips it. Do not sync or push it. Do not change vibestack for it.

READ
  AGENTS.md              The conventions of this folder
  README.md              The tool and the procedure
  vibestack/README.md    The workspace: apps, variables, startup
  <template>/CUSTOM.md   The rules of one template
AGENT
}

case "${1:-}" in
  version|--version|-V)
    echo "$VERSION"
    ;;
  agent)
    cmd_agent
    ;;
  help|--help|-h)
    echo "ycoder.sh $VERSION"
    usage
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
    usage >&2
    exit 1
    ;;
esac
