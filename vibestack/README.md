# Vibestack

> Version: 2026-08-09-v1

General-purpose Coder workspace: **VS Code in the browser** (code-server), a
background **opencode** server, and **nested Docker** so you can
`docker compose up` any stack right inside the workspace.

It serves two roles:

- **Standalone template** — push it as-is for a general dev workspace.
- **Shared foundation** — every other sibling folder is a template; optional
  `custom.tf` / `startup.custom.sh` add on top of the synced vibestack files.

`vibestack/` is **not** a Terraform module. `../ycoder.sh sync` copies its
`main.tf`, `startup.sh`, `Makefile`, `.env.example`, and `README.md` into each
template folder. Optional `custom.tf` / `startup.custom.sh` in a template stay
local and merge with the synced root config. Symlinked `.tf` files are silently
dropped from the template upload, which is why the files are vendored rather
than referenced. The synced `Makefile` rewrites the push name to the template
folder.

## Files

| File                | Purpose                                                     |
| ------------------- | ----------------------------------------------------------- |
| `main.tf`           | Terraform: containers, volumes, agent, apps, env, variables |
| `startup.sh`        | Shared half of the agent startup script                     |
| `.env.example`      | Template variables to copy to `.env` before pushing         |
| `Makefile`          | `make push` — loads `.env` and passes `--variable` flags    |
| `README.md`         | This document                                               |

## Containers

- `coder-<owner>-<workspace>` — dev workspace (`dockette/coder:fx`).
- `coder-<owner>-<workspace>-dind` — privileged `dockerd` sidecar (`docker:dind`).

They share `/home/coder` (volume `coder-<workspace_id>-home`); the dind volume
persists `/var/lib/docker` across restarts. The workspace joins the sidecar's
network namespace (`network_mode = "container:…"`), so compose-published ports
are reachable on `localhost` and Coder's port detection sees them.

That shared namespace is also why the workspace container sets no `hostname`
and no host-to-IP mapping — Docker rejects both alongside `network_mode`.

## Apps

| App         | URL      | Order | Notes                                   |
| ----------- | -------- | ----- | --------------------------------------- |
| code-server | `:13337` | 1     | opens `/home/coder`                     |
| opencode    | `:4096`  | 2     | headless `opencode serve`, bound to `~` |

Templates add their own apps from `order = 3` upward.

## Opencode

`opencode serve` runs in the background on port `4096`, serving `$HOME`. Manage
it from any terminal with `opencode-ctl`:

| Command                | Action                               |
| ---------------------- | ------------------------------------ |
| `opencode-ctl status`  | up / down                            |
| `opencode-ctl start`   | start (idempotent)                   |
| `opencode-ctl stop`    | stop                                 |
| `opencode-ctl restart` | restart                              |
| `opencode-ctl logs`    | follow `~/.cache/opencode/serve.log` |
| `opencode-ctl help`    | usage                                |

## xclaude

`xclaude` runs `claude` against an alternate gateway. Its config is exposed as
`XCLAUDE_*` env vars (never the real `ANTHROPIC_*`), and the wrapper maps them
onto `ANTHROPIC_*` only for that one invocation — so your workspace's real
`ANTHROPIC_*` vars stay untouched:

```bash
xclaude          # == claude, routed through the XCLAUDE_* gateway
xclaude --help
```

`XCLAUDE_MODEL` fills the Sonnet/Opus/subagent slots, `XCLAUDE_SMALL_MODEL` the
Haiku slot.

By default `xclaude` runs with `--permission-mode auto`; set
`xclaude_permission_mode` to `false` to disable it. Set `xclaude_bypass` to
`true` to run with `--dangerously-skip-permissions` instead (overrides the
permission mode).

It's only wired up when `xclaude_auth_token` is set; otherwise `xclaude` exits
with a hint. `xclaude_base_url`, `xclaude_model` and `xclaude_small_model` have
**no defaults** — set them alongside the token.

## AI

`/srv/coder/<owner>/shared/ai` is bind-mounted at `~/.ai`, and select tool files
are symlinked into it so state persists across the owner's workspaces.

**Claude is deliberately not shared** — `~/.claude`, `~/.claude.json`,
`~/.config/claude` and `~/.local/share/claude` all stay local and plain, with no
symlinks. **opencode** shares only login and config; its chat sessions database
(`~/.local/share/opencode/opencode.db`) stays local, so workspaces don't see
each other's sessions.

| Shared path (`~/.ai/…`)         | Workspace path                          | Kind |
| ------------------------------- | --------------------------------------- | ---- |
| `config-opencode/opencode.json` | `~/.config/opencode/opencode.json`      | file |
| `local-opencode/auth.json`      | `~/.local/share/opencode/auth.json`     | file |
| `local-opencode/mcp-auth.json`  | `~/.local/share/opencode/mcp-auth.json` | file |
| `docker`                        | `~/.docker`                             | dir  |

## Open in Coder

Set the **Git repository** parameter (an SSH URL) when creating the workspace.
The repo clones into `~/code/<basename>` on first start. Skipped if the folder
already has content. The clone is best-effort — it logs a warning on failure
rather than aborting startup.

Templates that clone their own repo into `~/code` (via the `git-clone` module)
simply leave this parameter blank.

## Parameters

| Parameter  | Default | Purpose                                             |
| ---------- | ------- | --------------------------------------------------- |
| `git_repo` | `""`    | Optional repo to clone into `~/code` on first start |

## Template variables

Sensitive, template-wide values set at push time (not per workspace). Each is
injected only when non-empty, so an unset value won't export an empty variable.

| Variable                  | Default | Purpose                                                        |
| ------------------------- | ------- | -------------------------------------------------------------- |
| `docker_socket`           | `""`    | Optional Docker socket URI for the provider                    |
| `gitlab_token`            | `""`    | Exposed as `GITLAB_TOKEN` (sensitive)                          |
| `gitlab_host`             | `""`    | Exposed as `GITLAB_HOST`                                       |
| `github_token`            | `""`    | Exposed as `GITHUB_TOKEN`, used by the `gh` CLI (sensitive)    |
| `composer_auth`           | `""`    | Base64 JSON, decoded into `COMPOSER_AUTH` (sensitive)          |
| `docker_registry_host`    | `""`    | `docker login` host, exposed as `DOCKER_REGISTRY_HOST`         |
| `docker_registry_user`    | `""`    | `docker login` user, exposed as `DOCKER_REGISTRY_USER`         |
| `docker_registry_token`   | `""`    | `docker login` password (sensitive); gates all three           |
| `xclaude_auth_token`      | `""`    | Auth token for the `xclaude` gateway (sensitive); gates all `XCLAUDE_*` |
| `xclaude_base_url`        | `""`    | Base URL for the `xclaude` gateway                             |
| `xclaude_model`           | `""`    | Primary model (Sonnet/Opus/subagent slots)                     |
| `xclaude_small_model`     | `""`    | Small/fast model (Haiku slot)                                  |
| `xclaude_effort`          | `high`  | Reasoning effort for the `xclaude` gateway                     |
| `xclaude_permission_mode` | `true`  | Run `xclaude` with `--permission-mode auto`                    |
| `xclaude_bypass`          | `false` | Run `xclaude` with `--dangerously-skip-permissions`            |

`composer_auth` is base64-encoded so the value stays quote-free and survives
coder's inline `--variable` parser.

Values come from `<template>/.env` via that template's `Makefile` `push`
target (see `.env.example`). `../ycoder.sh push` delegates to `make push`
when present.

## Environment

**Container** — set on the workspace container itself:

| Variable            | Value                  | Notes                                     |
| ------------------- | ---------------------- | ----------------------------------------- |
| `DOCKER_HOST`       | `tcp://localhost:2375` | Points the Docker CLI at the DIND sidecar |
| `CODER_AGENT_TOKEN` | _(generated)_          | Injected by the platform                  |

**Git** — per workspace, from the workspace owner:

| Variable              | Value                                                 | Notes                            |
| --------------------- | ----------------------------------------------------- | -------------------------------- |
| `GIT_AUTHOR_NAME`     | owner full name (or username)                         | always set                       |
| `GIT_COMMITTER_NAME`  | owner full name (or username)                         | always set                       |
| `GIT_AUTHOR_EMAIL`    | owner email                                           | only when the owner has an email |
| `GIT_COMMITTER_EMAIL` | owner email                                           | only when the owner has an email |
| `GIT_SSH_COMMAND`     | `coder gitssh -- -o StrictHostKeyChecking=accept-new` | git-over-SSH via the Coder key   |
| `GIT_REPO`            | the `git_repo` parameter                              | only when the parameter is set   |

**Forge** — from the sensitive template variables, injected only when set:

| Variable        | Source variable | Notes            |
| --------------- | --------------- | ---------------- |
| `GITLAB_TOKEN`  | `gitlab_token`  | used by `glab`   |
| `GITLAB_HOST`   | `gitlab_host`   | used by `glab`   |
| `GITHUB_TOKEN`  | `github_token`  | used by `gh`     |
| `COMPOSER_AUTH` | `composer_auth` | used by Composer |

**Docker registry** — injected only when `docker_registry_token` is set; startup
runs `docker login` with them, writing into the shared `~/.docker`:

| Variable                | Source variable         |
| ----------------------- | ----------------------- |
| `DOCKER_REGISTRY_HOST`  | `docker_registry_host`  |
| `DOCKER_REGISTRY_USER`  | `docker_registry_user`  |
| `DOCKER_REGISTRY_TOKEN` | `docker_registry_token` |

**xclaude** — injected only when `xclaude_auth_token` is set:

| Variable                  | Source variable           |
| ------------------------- | ------------------------- |
| `XCLAUDE_BASE_URL`        | `xclaude_base_url`        |
| `XCLAUDE_AUTH_TOKEN`      | `xclaude_auth_token`      |
| `XCLAUDE_MODEL`           | `xclaude_model`           |
| `XCLAUDE_SMALL_MODEL`     | `xclaude_small_model`     |
| `XCLAUDE_EFFORT`          | `xclaude_effort`          |
| `XCLAUDE_PERMISSION_MODE` | `xclaude_permission_mode` |
| `XCLAUDE_BYPASS`          | `xclaude_bypass`          |

**opencode** — always set, enabling experimental opencode features:

| Variable                          | Value  |
| --------------------------------- | ------ |
| `OPENCODE_ENABLE_EXA`             | `1`    |
| `OPENCODE_EXPERIMENTAL`           | `true` |
| `OPENCODE_EXPERIMENTAL_SCOUT`     | `true` |
| `OPENCODE_EXPERIMENTAL_PLAN_MODE` | `true` |
| `OPENCODE_EXPERIMENTAL_PARALLEL`  | `true` |

## Startup composition

`main.tf` sets the agent's `startup_script` to `startup.sh` +
`startup.custom.sh` concatenated. The custom half therefore inherits everything
the base half defines:

| Helper          | Use                                                      |
| --------------- | -------------------------------------------------------- |
| `log "…"`       | cyan progress line                                        |
| `ok "…"`        | green success line                                        |
| `link_file A B` | force `B` into a symlink to shared `A`, adopting existing |
| `summary_lines` | array of summary rows — append your own                   |
| `summary`       | print the summary block; call it last                     |

A template's `startup.custom.sh` sets `WORKSPACE_LABEL`, does its own setup,
appends to `summary_lines`, and calls `summary` last.

It is **optional**: `main.tf` uses `fileexists()`, and a template without one
gets a bare `summary` call appended instead — which is why standalone vibestack
has no `startup.custom.sh`. Note the concatenation happens in Terraform, at plan
time: `startup_script` is a string, so the custom file is never uploaded to the
workspace and `startup.sh` cannot look for it at runtime.

`main.tf` also ships a `welcome` script that seeds `~/code/README.md` — it exits
early when `~/code` is a git checkout or already has content, so templates that
clone a repo there are unaffected.

## Agent guide

Startup writes `~/AGENTS.md` (rewritten every start — template-owned) listing
the preinstalled runtimes and the `opencode-ctl` / `glab` / `gh` /
`agent-browser` / `coder` CLIs. `~/CLAUDE.md` is seeded once with `@AGENTS.md`
so it points at the same guide, and is never overwritten afterwards.

## Deployment

Copy `.env.example` to `.env`, fill in the tokens, then from `ycoder/`:

```bash
./ycoder.sh push vibestack
```

`push` runs `make push`, which passes every non-empty `.env` value as a
`--variable`. Since vibestack is the sync source, pushing it needs no sync step.

## Image

`dockette/coder:fx` is re-pulled when the registry digest changes **or** when
`local.template_version` is bumped. Keep that value in `YYYY-MM-DD-vN` form and
mirror it in the `Version:` line at the top of this file.

## Host prerequisites

Both fail at workspace **build** time, not push time:

- **Privileged containers** must be allowed on the Coder host (the DIND sidecar).
- **`/srv/coder/<owner>/shared/ai`** must exist or be creatable. Docker creates
  it root-owned; startup runs `sudo chown coder:coder` to fix it.
