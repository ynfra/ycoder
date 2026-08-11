# Vibestack

> Version: 2026-08-11-v1

Vibestack is a general-purpose Coder workspace template. It gives you three
things:

- **code-server**. This is VS Code in the browser.
- **opencode**. This is an AI coding server. It runs in the background.
- **Docker in Docker**. You can run `docker compose up` in the workspace.

Vibestack has two functions:

- It is a template. You can push it without changes.
- It is the source for all other templates. Each other folder is a template. A
  template can add a `custom.tf` file and a `startup.custom.sh` file.

Vibestack is not a Terraform module. The `../ycoder.sh sync` command copies
five files into each template folder: `main.tf`, `startup.sh`, `Makefile`,
`.env.example` and `README.md`. Coder removes symbolic links to `.tf` files
from the upload. Therefore the command copies the files. It does not make
links. The command also writes the template folder name into the copied
`Makefile`. The `custom.tf` file and the `startup.custom.sh` file stay in the
template. Terraform reads them together with the copied `main.tf`.

## Files

| File           | Purpose                                                     |
| -------------- | ----------------------------------------------------------- |
| `main.tf`      | Terraform: containers, volumes, agent, apps, env, variables |
| `startup.sh`   | The shared part of the agent startup script                 |
| `.env.example` | Template variables. Copy to `.env` before you push          |
| `Makefile`     | `make push` reads `.env` and sends `--variable` flags       |
| `README.md`    | This document                                               |

## Containers

The template makes two containers:

- `coder-<owner>-<workspace>` is the workspace. It uses the `dockette/coder:fx`
  image.
- `coder-<owner>-<workspace>-dind` is the Docker daemon. It uses the
  `docker:dind` image. It is privileged.

The two containers share `/home/coder`. The volume name is
`coder-<workspace_id>-home`. A second volume keeps `/var/lib/docker`. Therefore
Docker data stays after a restart.

The workspace container joins the network of the dind container. The setting is
`network_mode = "container:…"`. This gives three results:

- Compose publishes its ports on `localhost`.
- Coder finds these ports.
- The workspace container must not set `hostname` or a host-to-IP map. Docker
  rejects these two settings when `network_mode` is set.

## Apps

| App         | URL      | Order | Notes                                    |
| ----------- | -------- | ----- | ---------------------------------------- |
| code-server | `:13337` | 1     | Opens `/home/coder`                      |
| opencode    | `:4096`  | 2     | Runs `opencode serve` in `~`             |

A template must use `order = 3` or a higher value for its own apps.

## Opencode

The `opencode serve` command runs in the background on port `4096`. It serves
`$HOME`. Use the `opencode-ctl` command in a terminal to control the server:

| Command                | Action                                 |
| ---------------------- | -------------------------------------- |
| `opencode-ctl status`  | Shows the server status                |
| `opencode-ctl start`   | Starts the server                      |
| `opencode-ctl stop`    | Stops the server                       |
| `opencode-ctl restart` | Restarts the server                    |
| `opencode-ctl logs`    | Shows `~/.cache/opencode/serve.log`    |
| `opencode-ctl help`    | Shows the usage                        |

The `start` command is idempotent. If the server is up, the command does
nothing.

## xclaude

The `xclaude` command runs `claude` through a different gateway. The gateway
configuration is in the `XCLAUDE_*` environment variables. The `xclaude` command
copies these values into the `ANTHROPIC_*` variables for one call only.
Therefore the `ANTHROPIC_*` variables of the workspace do not change.

```bash
xclaude          # The same as claude, but through the XCLAUDE_ gateway
xclaude --help
```

The `XCLAUDE_MODEL` value fills the Sonnet slot, the Opus slot and the subagent
slot. The `XCLAUDE_SMALL_MODEL` value fills the Haiku slot.

The `xclaude` command uses `--permission-mode auto` by default. To stop this,
set `xclaude_permission_mode` to `false`. To use
`--dangerously-skip-permissions`, set `xclaude_bypass` to `true`. The
`xclaude_bypass` variable has a higher priority than the
`xclaude_permission_mode` variable.

You must set `xclaude_auth_token`. If the token is empty, the `xclaude` command
stops and shows a message. The `xclaude_base_url`, `xclaude_model` and
`xclaude_small_model` variables have no default values. Set them together with
the token.

## AI

The host folder `/srv/coder/<owner>/shared/ai` is mounted at `~/.ai`. Startup
makes symbolic links from the workspace to this folder. Therefore the state
stays after you delete a workspace, and all workspaces of one owner share it.

Claude does not share its state. The `~/.claude`, `~/.claude.json`,
`~/.config/claude` and `~/.local/share/claude` paths stay local. Startup does
not make links for them.

Opencode shares only the login data and the configuration. The session database
`~/.local/share/opencode/opencode.db` stays local. Therefore one workspace does
not show the sessions of a different workspace.

| Shared path (`~/.ai/…`)         | Workspace path                          | Type |
| ------------------------------- | --------------------------------------- | ---- |
| `config-opencode/opencode.json` | `~/.config/opencode/opencode.json`      | File |
| `local-opencode/auth.json`      | `~/.local/share/opencode/auth.json`     | File |
| `local-opencode/mcp-auth.json`  | `~/.local/share/opencode/mcp-auth.json` | File |
| `docker`                        | `~/.docker`                             | Dir  |

## Git repository

Set the **Git repository** parameter when you make a workspace. Use an SSH URL.
At the first start, startup clones the repository into `~/code/<name>`. If the
folder has content, startup does not clone. If the clone fails, startup writes a
warning and continues.

Some templates clone a repository with the `git-clone` module. For these
templates, keep this parameter empty.

## Parameters

| Parameter  | Default | Purpose                                               |
| ---------- | ------- | ----------------------------------------------------- |
| `git_repo` | `""`    | The repository to clone into `~/code` at first start  |

## Template variables

These variables hold secret values. You set them when you push the template.
They apply to all workspaces of the template. The template sends a variable to
the workspace only when the value is not empty. Therefore an empty value does
not make an empty environment variable.

| Variable                  | Default | Purpose                                                                 |
| ------------------------- | ------- | ----------------------------------------------------------------------- |
| `docker_socket`           | `""`    | The Docker socket URI for the provider. Optional                        |
| `gitlab_token`            | `""`    | Becomes `GITLAB_TOKEN`. Secret                                          |
| `gitlab_host`             | `""`    | Becomes `GITLAB_HOST`                                                   |
| `github_token`            | `""`    | Becomes `GITHUB_TOKEN` for the `gh` CLI. Secret                         |
| `composer_auth`           | `""`    | Base64 JSON. Becomes `COMPOSER_AUTH`. Secret                            |
| `docker_registry_host`    | `""`    | The `docker login` host. Becomes `DOCKER_REGISTRY_HOST`                 |
| `docker_registry_user`    | `""`    | The `docker login` user. Becomes `DOCKER_REGISTRY_USER`                 |
| `docker_registry_token`   | `""`    | The `docker login` password. Secret. Controls all three values          |
| `xclaude_auth_token`      | `""`    | The token for the `xclaude` gateway. Secret. Controls all `XCLAUDE_*`   |
| `xclaude_base_url`        | `""`    | The URL of the `xclaude` gateway                                        |
| `xclaude_model`           | `""`    | The primary model for the Sonnet, Opus and subagent slots               |
| `xclaude_small_model`     | `""`    | The small model for the Haiku slot                                      |
| `xclaude_effort`          | `high`  | The reasoning effort for the `xclaude` gateway                          |
| `xclaude_permission_mode` | `true`  | Runs `xclaude` with `--permission-mode auto`                            |
| `xclaude_bypass`          | `false` | Runs `xclaude` with `--dangerously-skip-permissions`                    |

The `composer_auth` value is Base64 text. Base64 removes the quotation marks.
Therefore the value passes through the `--variable` parser of Coder.

The values come from the `.env` file of the template. The `push` target of the
`Makefile` reads this file. See `.env.example`. The `../ycoder.sh push` command
calls `make push` when a `Makefile` is present.

## Environment

**Container.** The template sets these variables on the workspace container:

| Variable            | Value                  | Notes                                     |
| ------------------- | ---------------------- | ----------------------------------------- |
| `DOCKER_HOST`       | `tcp://localhost:2375` | Sends the Docker CLI to the dind sidecar  |
| `CODER_AGENT_TOKEN` | *(generated)*          | Coder sets this value                     |

**Git.** The template reads these values from the workspace owner:

| Variable              | Value                                                 | Notes                             |
| --------------------- | ----------------------------------------------------- | --------------------------------- |
| `GIT_AUTHOR_NAME`     | The full name of the owner, or the user name          | Always set                        |
| `GIT_COMMITTER_NAME`  | The full name of the owner, or the user name          | Always set                        |
| `GIT_AUTHOR_EMAIL`    | The email of the owner                                | Set only when the owner has one   |
| `GIT_COMMITTER_EMAIL` | The email of the owner                                | Set only when the owner has one   |
| `GIT_SSH_COMMAND`     | `coder gitssh -- -o StrictHostKeyChecking=accept-new` | Uses the SSH key of Coder for git |
| `GIT_REPO`            | The `git_repo` parameter                              | Set only when the parameter is set |

**Forge.** The template sets these variables only when the source variable has
a value:

| Variable        | Source variable | Used by  |
| --------------- | --------------- | -------- |
| `GITLAB_TOKEN`  | `gitlab_token`  | `glab`   |
| `GITLAB_HOST`   | `gitlab_host`   | `glab`   |
| `GITHUB_TOKEN`  | `github_token`  | `gh`     |
| `COMPOSER_AUTH` | `composer_auth` | Composer |

**Docker registry.** The template sets these variables only when
`docker_registry_token` has a value. Startup runs `docker login` with them and
writes the result into the shared `~/.docker` folder:

| Variable                | Source variable         |
| ----------------------- | ----------------------- |
| `DOCKER_REGISTRY_HOST`  | `docker_registry_host`  |
| `DOCKER_REGISTRY_USER`  | `docker_registry_user`  |
| `DOCKER_REGISTRY_TOKEN` | `docker_registry_token` |

**xclaude.** The template sets these variables only when `xclaude_auth_token`
has a value:

| Variable                  | Source variable           |
| ------------------------- | ------------------------- |
| `XCLAUDE_BASE_URL`        | `xclaude_base_url`        |
| `XCLAUDE_AUTH_TOKEN`      | `xclaude_auth_token`      |
| `XCLAUDE_MODEL`           | `xclaude_model`           |
| `XCLAUDE_SMALL_MODEL`     | `xclaude_small_model`     |
| `XCLAUDE_EFFORT`          | `xclaude_effort`          |
| `XCLAUDE_PERMISSION_MODE` | `xclaude_permission_mode` |
| `XCLAUDE_BYPASS`          | `xclaude_bypass`          |

**opencode.** The template always sets these variables. They enable
experimental opencode functions:

| Variable                          | Value  |
| --------------------------------- | ------ |
| `OPENCODE_ENABLE_EXA`             | `1`    |
| `OPENCODE_EXPERIMENTAL`           | `true` |
| `OPENCODE_EXPERIMENTAL_SCOUT`     | `true` |
| `OPENCODE_EXPERIMENTAL_PLAN_MODE` | `true` |
| `OPENCODE_EXPERIMENTAL_PARALLEL`  | `true` |

## Startup composition

The `main.tf` file makes the `startup_script` of the agent. The script is one
text: first `startup.sh`, then `startup.custom.sh` of the template. The two
parts run as one script. Therefore the second part can use all the variables and
all the functions of the first part:

| Helper          | Use                                                          |
| --------------- | ------------------------------------------------------------ |
| `log "…"`       | Writes a cyan progress line                                  |
| `ok "…"`        | Writes a green success line                                  |
| `link_file A B` | Makes `B` a symbolic link to the shared file `A`             |
| `summary_lines` | The array of summary lines. Add your lines to it             |
| `summary`       | Writes the summary block. Call this function last            |

Write a `startup.custom.sh` file with these steps:

1. Set `WORKSPACE_LABEL`.
2. Do the setup of the template.
3. Add your lines to `summary_lines`.
4. Call `summary` as the last command.

The `startup.custom.sh` file is optional. The `main.tf` file uses `fileexists()`
to find it. If the file is not present, `main.tf` adds only a `summary` call.
Vibestack has no `startup.custom.sh` file for this reason.

Terraform joins the two parts when it makes the plan. Therefore Coder does not
upload the `startup.custom.sh` file to the workspace. The `startup.sh` script
cannot find this file when it runs.

The `main.tf` file also has a `welcome` script. This script writes
`~/code/README.md`. The script stops if `~/code` is a git clone, or if `~/code`
has content. Therefore the script does not change a repository.

## Agents

Startup writes two files in `$HOME` for the AI coding agents:

- `~/AGENTS.md` is the guide to the workspace. It lists the installed runtimes
  and these CLI tools: `opencode-ctl`, `glab`, `gh`, `agent-browser` and
  `coder`. The template owns this file. Startup writes it again at each start.
  Do not keep your changes in this file.
- `~/CLAUDE.md` contains `@AGENTS.md`. Startup writes this file one time only.
  Therefore Claude reads the same guide, and your changes to this file stay
  after a restart.

## Image

Terraform pulls the `dockette/coder:fx` image again in two conditions:

- The digest in the registry changes.
- The `local.template_version` value changes.

Use the `YYYY-MM-DD-vN` format for `local.template_version`. Write the same
value in the `Version:` line at the top of this document.

## Host

The Coder host must obey two conditions. If it does not, the **build** of the
workspace fails. The push does not fail.

- The host must permit privileged containers, because of the dind sidecar.
- The `/srv/coder/<owner>/shared/ai` folder must be present, or Docker must be
  able to make it. Docker makes the folder with the root owner. Startup then
  runs `sudo chown coder:coder` on it.

## Deployment

1. Copy `.env.example` to `.env`.
2. Write your secret values in `.env`.
3. Push the template from the templates folder:

```bash
./ycoder.sh push <template>
```

The `push` command first copies the vibestack files into the template. It then
runs the `make push` target. This target sends each value from `.env` as a
`--variable` flag. When you push `vibestack`, the command does not copy the
files, because vibestack is the source.

The `coder` CLI reads the `CODER_URL` and `CODER_SESSION_TOKEN` variables. See
the `.envrc` file in the templates folder.
