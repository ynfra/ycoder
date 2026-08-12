# Vibestack

> Version: 2026-08-11-v1

A Coder workspace with three things:

- **code-server** — VS Code in your browser.
- **opencode** — an AI coding server on port `4096`.
- **Docker in Docker** — `docker compose` works.

The image has PHP, Composer, Node, Bun, Deno, Python and Go. It also has `git`,
`glab`, `gh`, `agent-browser` and `coder`.

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

Give your own apps `order = 3` or more.

Control the opencode server with `opencode-ctl`:

```bash
opencode-ctl status   # start | stop | restart | logs
```

## xclaude

`xclaude` runs `claude` through another gateway. It maps the `XCLAUDE_*` values
to `ANTHROPIC_*` for one call. Your own `ANTHROPIC_*` values stay.

You must set `xclaude_auth_token`. Without it, `xclaude` stops. Set
`xclaude_base_url`, `xclaude_model` and `xclaude_small_model` too. The big model
runs Sonnet, Opus and the subagents. The small model runs Haiku.

`xclaude` uses `--permission-mode auto`. Set `xclaude_permission_mode` to
`false` to stop it. Set `xclaude_bypass` to `true` for
`--dangerously-skip-permissions`. Bypass wins.

## Shared AI files

The host folder `/srv/coder/<owner>/shared/ai` is your `~/.ai`. The workspace
links three things into it: the opencode configuration, the opencode login and
`~/.docker`. All your workspaces share them. They stay after you delete a
workspace.

Claude files stay local. Opencode chats stay local too.

## Git repository

Give the **Git repository** parameter an SSH URL. The workspace clones it into
`~/code/<name>`. It skips a folder with files. A failed clone gives a warning
only.

Leave it empty when the template uses the `git-clone` module.

## Template variables

Give these when you push. Empty values are not sent.

| Variable                  | Default | What it does                                            |
| ------------------------- | ------- | ------------------------------------------------------- |
| `docker_socket`           | `""`    | The Docker socket URI                                   |
| `gitlab_token`            | `""`    | `GITLAB_TOKEN`. Secret                                  |
| `gitlab_host`             | `""`    | `GITLAB_HOST`                                           |
| `github_token`            | `""`    | `GITHUB_TOKEN`. Secret                                  |
| `composer_auth`           | `""`    | `COMPOSER_AUTH`, in Base64. Secret                      |
| `docker_registry_host`    | `""`    | The `docker login` host                                 |
| `docker_registry_user`    | `""`    | The `docker login` user                                 |
| `docker_registry_token`   | `""`    | The password. Secret. Turns on all three                |
| `xclaude_auth_token`      | `""`    | The gateway token. Secret. Turns on all `XCLAUDE_*`     |
| `xclaude_base_url`        | `""`    | The gateway URL                                         |
| `xclaude_model`           | `""`    | The big model                                           |
| `xclaude_small_model`     | `""`    | The small model                                         |
| `xclaude_effort`          | `high`  | How much the model thinks                               |
| `xclaude_permission_mode` | `true`  | `--permission-mode auto`                                |
| `xclaude_bypass`          | `false` | `--dangerously-skip-permissions`                        |

Base64 removes the quotation marks, so Coder can read `composer_auth`. In `.env`
the name is `COMPOSER_AUTH_B64`.

With `docker_registry_token`, the workspace runs `docker login`. The login goes
to the shared `~/.docker`.

## Your own startup steps

Terraform joins `startup.sh` and your `startup.custom.sh`. Your part can use
`log`, `ok`, `link_file`, `summary_lines` and `summary`.

Write `startup.custom.sh` like this:

1. Set `WORKSPACE_LABEL`.
2. Do your setup.
3. Add lines to `summary_lines`.
4. Call `summary` last.

The file is optional. Vibestack has none.

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

## How to push

1. Copy `.env.example` to `.env` in the template folder.
2. Write your secret values there.
3. Run `./ycoder.sh validate <template>`.
4. Run `./ycoder.sh push <template>`.

The push sends each `.env` value to Coder as a `--variable` flag. The `coder`
command needs `CODER_URL` and `CODER_SESSION_TOKEN` from the `.env` of the
`ycoder/` folder.
