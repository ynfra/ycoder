# ycoder

`ycoder.sh` manages [Coder](https://coder.com) workspace templates. It keeps
every template equal to one source.

[Quickstart](#quickstart) | [Installation](#installation) | [Usage](#usage) | [Commands](#commands) | [Workspace](vibestack/README.md)

`vibestack/` is the source. Each other folder is a template. A template holds a
copy of the source files and adds its own files.

The tool copies the files. It does not make symbolic links. Coder removes a
symbolic link to a `.tf` file from an upload.

---

## Quickstart

```bash
# Set CODER_URL and CODER_SESSION_TOKEN. Make the token at <coder-url>/cli-auth
cp .env.example .env && $EDITOR .env

# Set the secret values of the template
cp vibestack/.env.example vibestack/.env && $EDITOR vibestack/.env

./ycoder.sh validate vibestack
./ycoder.sh push vibestack
```

[direnv](https://direnv.net) reads `.env` through `.envrc`. The `coder` CLI then
needs no other configuration.

## Installation

The tool is here already. Install it only when your templates are in a
different repository.

```bash
cd /path/to/your-templates-repo
curl -fsSL https://raw.githubusercontent.com/ynfra/ycoder/master/ycoder.sh -o ycoder.sh
chmod +x ycoder.sh
./ycoder.sh download    # Get the newest tool and vibestack/ from GitHub
```

The `download` command needs the [GitHub CLI](https://cli.github.com) (`gh`).
It writes the files next to the script, not into your current folder.

**Caution:** `download` replaces `ycoder.sh` and all of `vibestack/`. It keeps
only the `vibestack/.env` file. Therefore you must not change your copy of
`vibestack/`. Put your changes in `custom.tf` and `startup.custom.sh`.

Two variables control the source. `YCODER_REPO` has the default value
`ynfra/ycoder`. `YCODER_REF` has the default value `master`.

```bash
YCODER_REPO=myorg/ycoder YCODER_REF=main ./ycoder.sh download
```



## Usage



### Make a template

```bash
./ycoder.sh create myapp
```

The command makes the folder. It writes `custom.tf`, `startup.custom.sh` and
`CUSTOM.md`. Then it copies the source files in. It stops if the folder exists.

```
myapp/
├── main.tf, startup.sh, Makefile, .env.example, README.md
│                      # The tool writes these files. Do not change them
├── custom.tf          # Yours. More Terraform
├── startup.custom.sh  # Yours. More startup commands
├── CUSTOM.md          # Yours. The rules of the folder for AI agents
└── .env               # Yours. Secret values. Git ignores this file
```



### Write your files

Put your changes in `custom.tf` and `startup.custom.sh`. Do not change a
generated file. The next `sync` command removes your change.

Terraform reads `custom.tf` and `main.tf` as one configuration. Use `custom.tf`
for apps, volumes, modules and parameters. Use `order = 3` or a higher value for
your apps.

`startup.custom.sh` runs after `startup.sh`. Therefore it can use the `log`,
`ok`, `link_file`, `summary_lines` and `summary` helpers. Set
`WORKSPACE_LABEL`. Do your setup. Add your lines to `summary_lines`. Call
`summary` last.

`CUSTOM.md` holds these rules for an AI agent that opens the folder. Add your
own notes about the template to it.

The three files are optional. The `sync` command does not change them.

### Set the secret values

```bash
cp myapp/.env.example myapp/.env && $EDITOR myapp/.env
```

Each template has its own `.env` file. Git ignores it. Put a secret value here.
Do not put it in a `.tf` file.

### Validate and push

```bash
./ycoder.sh validate myapp
./ycoder.sh push myapp
```



## Commands

```bash
./ycoder.sh sync     [template...]     # Copy the vibestack files into templates
./ycoder.sh create   <template>        # Make a new template
./ycoder.sh validate [template...]     # Run terraform validate in a temp folder
./ycoder.sh push     <template> [args] # Sync, then push to Coder
./ycoder.sh download                   # Get the newest ycoder.sh and vibestack
./ycoder.sh agent                      # Show the rules for AI agents
./ycoder.sh help                       # Show the usage
./ycoder.sh version                    # Show the version of the script
```

`agent` prints the file map and the rules. Give this output to an AI agent, or
read it yourself.

The script first moves to its own folder. Therefore you can run it from any
folder. For example, `../ycoder.sh push vibestack` works in a template folder.

`sync` and `validate` act on every managed folder when you give no name. A
managed folder has the banner in its `main.tf`. The tool skips `vibestack/` and
every folder with a hand-written `main.tf`.

**Caution:** With no name, `sync` writes into each managed folder. Give the name
of the template.

### sync

The command writes five files: `main.tf`, `startup.sh`, `Makefile`,
`.env.example` and `README.md`. It puts a banner in each file. It writes the
name of the template folder in the `Makefile`.

`vibestack/` is the source. A sync into it does nothing.

### validate

The command makes a temporary folder. It copies your `custom.tf` and
`startup.custom.sh` there. Then it writes the **current** `vibestack/` files
next to them. It runs `terraform init -backend=false` and `terraform validate`
in that folder.

Therefore the command tests the source, not the generated files of the
template. A template that is not in sync is still valid. It also keeps a
`.terraform/` folder out of this repository.

The Terraform plugins stay in `$TF_PLUGIN_CACHE_DIR`. The default value is
`~/.terraform.d/plugin-cache`.

### push

The command syncs the template first. A push of `vibestack` syncs nothing,
because `vibestack` is the source.

If the folder has a `Makefile` with a `push` target, the command runs
`make -C <template> push`. This target reads `.env`. It sends each secret value
as a `--variable` flag.

If not, the command runs `coder templates push <template> -d <template>` with
your arguments.

## Development

Change the workspace for every template in `vibestack/`. Then copy the files
into the templates:

```bash
./ycoder.sh sync myapp
./ycoder.sh validate myapp
```

Give the name of each template. `AGENTS.md` holds the conventions.  
[vibestack/README.md](vibestack/README.md) tells you how to change the version  
of the image.