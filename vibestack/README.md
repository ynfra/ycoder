---
name: vibestack
display_name: Vibestack
description: A Coder workspace with code-server, opencode and Docker in Docker
icon: /icon/code.svg
maintainer_github: f3l1x
tags: [docker, container, ai]
---

# Vibestack

> Version: 2026-08-15-v1

A Coder workspace with three things:

- **code-server** — VS Code in your browser.
- **opencode** — an AI coding server on port `4096`.
- **Docker in Docker** — `docker compose` works.

The image has PHP, Composer, Node, Bun, Deno, Python and Go. It also has `git`,
`glab`, `gh`, `agent-browser` and `coder`.

## TOC

- [Containers](#containers) — The two containers and the volumes
- [Apps](#apps) — The dashboard apps and ports
- [OpenCode](#opencode) — The server and `opencode-ctl`
- [xclaude](#xclaude) — The Claude gateway shortcut
- [Symlinks](#symlinks) — The shared `~/.ai` links
- [Git repository](#git-repository) — The clone of the project
- [Template variables](#template-variables) — The values for the push
- [Your own startup steps](#your-own-startup-steps) — The custom startup script
- [Image](#image) — The image and the version
- [Host](#host) — The host requirements
- [Deployment](#deployment) — The push steps

---

## Containers

The template starts two containers. One is the workspace. One is the Docker
server. It needs privileged mode.

Both use the same home volume. A second volume keeps the Docker data. Both
volumes stay after a restart.

The workspace uses the network of the Docker container. Therefore Compose ports
open on `localhost`, and Coder finds them. But the workspace container must not
set `hostname` or extra hosts.

## Apps


| App         | URL      | Order |
| ----------- | -------- | ----- |
| code-server | `:13337` | 1     |
| opencode    | `:4096`  | 2     |




## OpenCode

The workspace starts the opencode server on port `4096`. Open the **opencode**
app in the Coder dashboard, or open `http://localhost:4096`.

Use `opencode-ctl` to manage the server:

| Command                | Action                         |
| ---------------------- | ------------------------------ |
| `opencode-ctl status`  | Report if the server is up     |
| `opencode-ctl start`   | Start the server if it is down |
| `opencode-ctl stop`    | Stop the server                |
| `opencode-ctl restart` | Restart the server             |
| `opencode-ctl logs`    | Follow the server log          |
| `opencode-ctl help`    | Show the help                  |

The log file is `~/.cache/opencode/serve.log`.

Use the `opencode` CLI for sessions and history. Use `opencode-ctl` only for
the background server.

## xclaude

`xclaude` runs `claude` through another gateway. It maps the `XCLAUDE_*` values
to `ANTHROPIC_*` for one call. Your own `ANTHROPIC_*` values stay.

You must set `xclaude_auth_token`. Without it, `xclaude` stops. Set
`xclaude_base_url`, `xclaude_model` and `xclaude_small_model` too. The big model
runs Sonnet, Opus and the subagents. The small model runs Haiku.

`xclaude` uses `--permission-mode auto`. Set `xclaude_permission_mode` to
`false` to stop it. Set `xclaude_bypass` to `true` for
`--dangerously-skip-permissions`. Bypass wins.

## Symlinks

The host folder `/srv/coder/<owner>/shared/ai` is your `~/.ai`. The workspace
links these things into it: the opencode configuration, the opencode login and
`~/.docker`. All your workspaces share them. They stay after you delete a
workspace.

The workspace links each entry, not the parent folder. The first start makes
these entries:


| In `~/.ai`                      | Link in the workspace                   | Content            |
| ------------------------------- | --------------------------------------- | ------------------ |
| `config-opencode/opencode.json` | `~/.config/opencode/opencode.json`      | The configuration  |
| `config-opencode/agents`        | `~/.config/opencode/agents`             | The agents         |
| `config-opencode/commands`      | `~/.config/opencode/commands`           | The commands       |
| `config-opencode/modes`         | `~/.config/opencode/modes`              | The modes          |
| `config-opencode/plugins`       | `~/.config/opencode/plugins`            | The plugins        |
| `config-opencode/skills`        | `~/.config/opencode/skills`             | The skills         |
| `config-opencode/themes`        | `~/.config/opencode/themes`             | The themes         |
| `config-opencode/tools`         | `~/.config/opencode/tools`              | The tools          |
| `local-opencode/auth.json`      | `~/.local/share/opencode/auth.json`     | The login          |
| `local-opencode/mcp-auth.json`  | `~/.local/share/opencode/mcp-auth.json` | The MCP login      |
| `docker`                        | `~/.docker`                             | The registry login |


Put a new file or folder in `~/.ai/config-opencode`. The next start of each
workspace links it too.

Claude files stay local. Opencode chats stay local too.

## Git repository

Give the **Git repository** parameter an SSH URL. The workspace clones it into
`~/code/<name>`. It skips a folder with files. A failed clone gives a warning
only.

Leave it empty when the template uses the `git-clone` module.

## Template variables

Give these when you push. Empty values are not sent.


| Variable                  | Default | What it does                                        |
| ------------------------- | ------- | --------------------------------------------------- |
| `docker_socket`           | `""`    | The Docker socket URI                               |
| `gitlab_token`            | `""`    | `GITLAB_TOKEN`. Secret                              |
| `gitlab_host`             | `""`    | `GITLAB_HOST`                                       |
| `github_token`            | `""`    | `GITHUB_TOKEN`. Secret                              |
| `composer_auth`           | `""`    | `COMPOSER_AUTH`, in Base64. Secret                  |
| `docker_registry_host`    | `""`    | The `docker login` host                             |
| `docker_registry_user`    | `""`    | The `docker login` user                             |
| `docker_registry_token`   | `""`    | The password. Secret. Turns on all three            |
| `xclaude_auth_token`      | `""`    | The gateway token. Secret. Turns on all `XCLAUDE_*` |
| `xclaude_base_url`        | `""`    | The gateway URL                                     |
| `xclaude_model`           | `""`    | The big model                                       |
| `xclaude_small_model`     | `""`    | The small model                                     |
| `xclaude_effort`          | `high`  | How much the model thinks                           |
| `xclaude_permission_mode` | `true`  | `--permission-mode auto`                            |
| `xclaude_bypass`          | `false` | `--dangerously-skip-permissions`                    |


Base64 removes the quotation marks, so Coder can read `composer_auth`. In `.env`
the name is `COMPOSER_AUTH_B64`.

With `docker_registry_token`, the workspace runs `docker login`. The login goes
to the shared `~/.docker`.

## Your own startup steps

Terraform joins `startup.sh` and your `startup.custom.sh`. Your part can use
these helpers:

| Name | What it does |
| --- | --- |
| `log MESSAGE` | Print a progress line |
| `ok MESSAGE` | Print a success line |
| `seed PATH CONTENT` | Write `CONTENT` to `PATH` if the file is missing |
| `link_shared SRC DST` | Link each entry of `SRC` into `DST` |
| `summary_lines` | The array of lines for the ready banner |
| `summary` | Print the ready banner. Call it last |
| `WORKSPACE_LABEL` | The name in the ready banner. Default is `workspace` |
| `bare_host URL` | Return the host name from a URL |

Write `startup.custom.sh` like this:

1. Set `WORKSPACE_LABEL`.
2. Do your setup.
3. Add lines to `summary_lines`.
4. Call `summary` last.

The file is optional. This template has none.

Every start writes `~/AGENTS.md`, the guide for the AI agents. Keep no notes in
it. The first start writes `~/CLAUDE.md`. Your changes there stay.

## Image

Terraform gets `dockette/coder:fx` again after a new image, or a new
`local.template_version` in `main.tf`. Use the `YYYY-MM-DD-vN` format. Write the
same value in the `Version:` line above.

## Host

The host must allow privileged containers. It must have the
`/srv/coder/<owner>/shared/ai` folder, or let Docker make it. A bad host breaks
the **build**, not the push.

## Deployment

1. Copy `.env.example` to `.env` in the template folder.
2. Write your secret values there.
3. Run `./ycoder.sh validate <template>`.
4. Run `./ycoder.sh push <template>`.

The push sends each value from the template `.env` as a `--variable` flag.
