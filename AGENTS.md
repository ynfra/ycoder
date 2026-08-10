# ycoder — Coder workspace templates

This folder holds Coder templates. The `ycoder.sh` tool manages them. The
`vibestack/` folder is the shared source. Each other folder is a template. A
template holds a **copy** of the source files.

Read `README.md` for the full procedure. Read `vibestack/README.md` for the
content of the workspace.

## Layout

| Path                           | Owner     | Notes                                     |
| ------------------------------ | --------- | ----------------------------------------- |
| `ycoder.sh`                    | Tool      | sync, create, validate, push, download    |
| `vibestack/`                   | Source    | Change the files here                     |
| `<template>/main.tf`           | Generated | From `vibestack/main.tf`. Do not change   |
| `<template>/startup.sh`        | Generated | From `vibestack/startup.sh`. Do not change |
| `<template>/Makefile`          | Generated | Holds the name of the template folder     |
| `<template>/.env.example`      | Generated | Copy to `.env`. Git ignores `.env`        |
| `<template>/README.md`         | Generated | From `vibestack/README.md`. Do not change |
| `<template>/custom.tf`         | Yours     | More Terraform. Terraform reads it with `main.tf` |
| `<template>/startup.custom.sh` | Yours     | More startup commands                     |

Each generated file has a banner. The banner tells you to change the source and
to run `./ycoder.sh sync`. If you change a generated file, the subsequent `sync`
command removes your change.

## Tool

```bash
./ycoder.sh sync     [template...]     # Copy vibestack files into templates
./ycoder.sh create   <template>        # Make custom.tf and startup.custom.sh
./ycoder.sh validate [template...]     # Run terraform validate in a temp folder
./ycoder.sh push     <template> [args] # Sync, then push. Uses make push if present
./ycoder.sh download                   # Get the newest ycoder.sh and vibestack
./ycoder.sh version
```

The script first moves to its own folder. Therefore `../ycoder.sh push
vibestack` works in a template folder.

## Setup of the stack

1. Copy `.env.example` to `.env` in the `ycoder/` folder. Set `CODER_URL` and
   `CODER_SESSION_TOKEN`. Make the token at the `<coder-url>/cli-auth` page.
   The `.envrc` file reads `.env` with direnv. The `coder` CLI needs no other
   configuration.
2. Copy `<template>/.env.example` to `<template>/.env`. Write the secret values
   for the template: GitLab, GitHub, Composer, the Docker registry and xclaude.
   Each template has its own `.env` file. Git ignores this file.
3. Run `./ycoder.sh validate <template>` before each push.
4. Run `./ycoder.sh push <template>`. The command copies the source files, then
   runs `make push`. This target reads `.env` and sends each secret value as a
   `--variable` flag.

The Coder host must permit privileged containers, because of the dind sidecar.
The `/srv/coder/<owner>/shared/ai` folder must be present, or Docker must be
able to make it. If the host does not obey these two conditions, the **build**
of the workspace fails. The push does not fail.

## Key rules

- **Change the files in `vibestack/`. Do not change a generated file.** Change
  the source, then run `./ycoder.sh sync`.
- **The `sync` and `validate` commands read all folders when you give no name.**
  The `docker/`, `mux/` and `ohmyfelix/` folders are old templates with their
  own `main.tf` files. A `sync` command without a name replaces their files.
  Always give the names of the templates that you want.
- **Copy the files. Do not make symbolic links.** Coder removes symbolic links
  to `.tf` files from a template upload. This is the reason for the copy.
- **Put the changes of a template in `custom.tf` or `startup.custom.sh`.** The
  two files are optional. The `sync` command does not change them.
- **The `startup.custom.sh` file is joined to `startup.sh`. The shell does not
  source it.** It can use the `log`, `ok`, `link_file`, `summary_lines` and
  `summary` helpers. Set `WORKSPACE_LABEL`, add your lines to `summary_lines`,
  and call `summary` last. Terraform joins the two files when it makes the plan.
  Therefore Coder does not upload `startup.custom.sh` to the workspace.
- **Use `order = 3` or a higher value for your apps.** code-server uses order 1
  and opencode uses order 2.
- **Change `local.template_version` in `vibestack/main.tf` to pull the image
  again.** Use the `YYYY-MM-DD-vN` format. Write the same value in the
  `Version:` line of `vibestack/README.md`.
- **The `download` command replaces `ycoder.sh` and the full `vibestack/`
  folder.** It writes both next to the script. It keeps only the
  `vibestack/.env` file. Do not keep local changes in `vibestack/` in a
  repository that uses the `download` command.
- **Put secret values in `.env`. Do not put them in a `.tf` file or in a
  document.** Each secret variable has the default value `""`. The template
  sends a variable only when the value is not empty.
- **The `composer_auth` value is Base64 text.** Base64 removes the quotation
  marks. Therefore the value passes through the `--variable` parser of Coder.
  The variable in `.env` is `COMPOSER_AUTH_B64`.
- **The `xclaude_auth_token` variable controls all `XCLAUDE_*` variables.** If
  the token is empty, the `xclaude` command stops and shows a message. The
  `xclaude_base_url`, `xclaude_model` and `xclaude_small_model` variables have
  no default values. Set them together with the token.

## Documents and comments

Write all documents and all code comments in **Simplified Technical English**
(ASD-STE100). Keep the comments short. Obey these rules:

- Write short sentences. Use a maximum of 20 words in an instruction. Use a
  maximum of 25 words in a description.
- Write one instruction in one sentence.
- Use the active voice. Write "The command copies the files", not "The files are
  copied".
- Use the simple present tense when possible.
- Use the same word for the same thing. Do not use a different word for variety.
- Use the imperative mood for an instruction. Write "Set the token".
- Do not remove the articles. Write "the token", not "token".
- Do not use slang, idioms or jargon.
- Do not use more than three nouns together.
- Use "must" for a mandatory action. Use "can" for a permitted action.
- Give a warning or a caution before the instruction, not after it.
