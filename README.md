# ynfra / ycoder

`ycoder.sh` manages [Coder](https://coder.com) workspace templates. It keeps
every template equal to one source: `vibestack/`. The tool copies the files —
it does not make symbolic links, because Coder removes a symbolic link to a
`.tf` file from an upload.

## Prerequisites

- A Coder server. Make a session token at `<coder-url>/cli-auth`.
- The `coder` CLI and `terraform`.
- The [GitHub CLI](https://cli.github.com) (`gh`) — only for the `download` command.

## Usage

```bash
# Set CODER_URL and CODER_SESSION_TOKEN
cp .env.example .env && $EDITOR .env
# Set the secret values of the template
cp vibestack/.env.example vibestack/.env && $EDITOR vibestack/.env

./ycoder.sh validate vibestack
./ycoder.sh push vibestack
```

To make your own template, run `./ycoder.sh create myapp`. Put your changes in
`myapp/custom.tf` and `myapp/startup.custom.sh`. Then validate and push.

## Commands

| Command | Arguments | Description |
|---|---|---|
| `sync` | `[template...]` | Copy the `vibestack/` files into the templates |
| `create` | `<template>` | Make a new template folder; stops if the folder exists |
| `validate` | `[template...]` | Run `terraform validate` in a temporary folder |
| `push` | `<template> [args]` | Sync the template, then push it to Coder |
| `download` | — | Get the newest `ycoder.sh` and `vibestack/` from GitHub |
| `agent` | — | Show the file map and the rules for AI agents |
| `help`, `version` | — | Show the usage / the version of the script |

## Notes

- Do not change a generated file (`main.tf`, `startup.sh`, `Makefile`, `.env.example`, `README.md`) — each has a banner, and the next `sync` removes your change. Your files are `custom.tf`, `startup.custom.sh` and `CUSTOM.md`; `sync` does not change them.
- With no name, `sync` and `validate` act on every managed folder (a managed folder has the banner in its `main.tf`). Give the name of the template.
- **Caution:** `download` replaces `ycoder.sh` and all of `vibestack/`; it keeps only `vibestack/.env`. `YCODER_REPO` (default `ynfra/ycoder`) and `YCODER_REF` (default `master`) select the source; the files land next to the script.
- Do not run `terraform` yourself — `validate` works in a temporary folder against the **current** `vibestack/` files (plugins cache in `$TF_PLUGIN_CACHE_DIR`, default `~/.terraform.d/plugin-cache`), and the Coder server applies the plan.
- `push` runs `make -C <template> push` when the template `Makefile` has a `push` target (it reads `.env` and sends each secret as a `--variable` flag); if not, it runs `coder templates push <template> -d <template>`.
- `startup.custom.sh` runs after `startup.sh` and can use the `log`, `ok`, `link_shared`, `summary_lines` and `summary` helpers; in `custom.tf`, use `order = 3` or a higher value for your apps.
- Put a secret value in the template's `.env` (git ignores it), never in a `.tf` file. [direnv](https://direnv.net) reads the root `.env` through `.envrc`, so the `coder` CLI needs no other configuration.
- The script first moves to its own folder, so you can run it from any folder.
- `docker/`, `mux/` and `ohmyfelix/` are standalone templates with a hand-written `main.tf` — the tool skips them.
- [vibestack/README.md](vibestack/README.md) describes the workspace: the apps, the variables and the image version.

See [AGENTS.md](AGENTS.md) for the conventions and the writing rules.
