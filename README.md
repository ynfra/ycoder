# ycoder

This folder holds [Coder](https://coder.com) workspace templates. It also holds
`ycoder.sh`. This tool keeps all templates equal to one shared source.

The `vibestack/` folder is the **source**. Each other folder is a **template**.
A template holds a copy of the source files and adds its own files.

There is no Terraform module and there are no symbolic links. Coder removes
symbolic links to `.tf` files from a template upload. Therefore `ycoder.sh`
copies the shared files into each template.

```
ycoder/
├── ycoder.sh          # The tool
├── .envrc             # CODER_URL and CODER_SESSION_TOKEN, read by direnv
├── vibestack/         # The shared source template
│   ├── main.tf
│   ├── startup.sh
│   ├── Makefile
│   ├── .env.example
│   └── README.md
└── <template>/        # Each other folder is a template
    ├── main.tf        #   Generated  ─┐
    ├── startup.sh     #   Generated   │ Copied from vibestack/
    ├── Makefile       #   Generated   │ by ./ycoder.sh sync
    ├── .env.example   #   Generated   │
    ├── README.md      #   Generated  ─┘
    ├── custom.tf          # Yours. More Terraform
    ├── startup.custom.sh  # Yours. More startup commands
    └── .env               # Yours. Secret values. Git ignores this file
```

The `[vibestack/README.md](vibestack/README.md)` document tells you what the
workspace contains: code-server, opencode, Docker in Docker, `xclaude` and the
shared `~/.ai` folder.

## [ycoder.sh](http://ycoder.sh)

```bash
./ycoder.sh sync     [template...]     # Copy vibestack files into templates
./ycoder.sh create   <template>        # Make a new template
./ycoder.sh validate [template...]     # Run terraform validate in a temp folder
./ycoder.sh push     <template> [args] # Sync, then push to Coder
./ycoder.sh download                   # Get the newest ycoder.sh and vibestack
./ycoder.sh version                    # Show the version of the script
```

The script first moves to its own folder. Therefore you can run it from any
folder. For example, `../ycoder.sh push vibestack` works in a template folder.

### sync

The `sync` command copies five files from `vibestack/` into each template:
`main.tf`, `startup.sh`, `Makefile`, `.env.example` and `README.md`. The command
writes a banner in each generated file. The banner tells you to change the
source and to run `./ycoder.sh sync` again.

Two details are important:

- The `startup.sh` file keeps its shebang on line 1. The banner comes after the
shebang. Therefore the file stays correct for a linter, and you can run it.
- The `Makefile` contains the line `coder templates push vibestack`. The command
writes the name of the template folder in this line. Therefore `make push`
uses the correct name.

If you give no name, the command copies the files into **all** other folders.
Give one or more names to limit the command.

### create

The `create` command makes a new template folder. It writes a `custom.tf` file
and a `startup.custom.sh` file. It then copies the vibestack files into the
folder.

```bash
./ycoder.sh create myworkspace
```

Terraform reads `custom.tf` together with the generated `main.tf` as one
configuration. Use `custom.tf` for apps, volumes, modules and parameters. Use
`order = 3` or a higher value for your apps.

The `startup.custom.sh` file runs after the shared `startup.sh` script.
Therefore it can use the `log`, `ok`, `link_file`, `summary_lines` and `summary`
helpers. Set `WORKSPACE_LABEL`, do your setup, add your lines to
`summary_lines`, and call `summary` last.

The two files are optional. The `sync` command does not change them.

### validate

The `validate` command copies the template into a temporary folder. It then runs
`terraform init -backend=false` and `terraform validate` in that folder.
Therefore Terraform does not make a `.terraform/` folder in this repository. The
command keeps the Terraform plugins in `$TF_PLUGIN_CACHE_DIR`. The default value
is `~/.terraform.d/plugin-cache`.

```bash
./ycoder.sh validate            # All templates
./ycoder.sh validate myworkspace
```



### push

The `push` command first copies the vibestack files into the template. It then
pushes the template. If the folder has a `Makefile` with a `push` target, the
command runs `make -C <template> push`. This target reads `.env` and sends each
secret value as a `--variable` flag.

If the folder has no `Makefile`, the command runs `coder templates push`. The
command sends your other arguments to the `coder` CLI.

```bash
./ycoder.sh push vibestack
./ycoder.sh push myworkspace --yes
```

The `coder` CLI reads the `CODER_URL` and `CODER_SESSION_TOKEN` variables. Copy
`.env.example` to `.env` in this folder. [direnv](https://direnv.net) reads this
file. Make the token at the `<your-coder-url>/cli-auth` page.

## Use ycoder in your repository

You can copy `ycoder.sh` into the repository that holds your templates. The
`download` command replaces this script **and** the `vibestack/` folder with the
newest copies from GitHub. It writes both files next to `ycoder.sh`, not into
your current folder. Therefore `../ycoder.sh download` from a template folder
still updates the correct files.

```bash
cd /path/to/your-templates-repo
curl -fsSL https://raw.githubusercontent.com/ynfra/ycoder/master/ycoder.sh -o ycoder.sh
chmod +x ycoder.sh
./ycoder.sh download        # Replaces ycoder.sh and vibestack/ next to the script
```

The subsequent procedure is the same as in this repository:

```bash
./ycoder.sh create myapp    # Make your template
$EDITOR myapp/custom.tf myapp/startup.custom.sh
cp myapp/.env.example myapp/.env && $EDITOR myapp/.env
./ycoder.sh validate myapp
./ycoder.sh push myapp
```

To get subsequent changes, run `./ycoder.sh download` and then `./ycoder.sh
sync`. The download step updates `ycoder.sh` itself.

**Caution:** The `download` command replaces `ycoder.sh` and the full
`vibestack/` folder. It keeps only the `vibestack/.env` file. Therefore you must
not change your copy of vibestack. Keep your changes in `custom.tf` and
`startup.custom.sh`. If you must change the source, do not use the `download`
command again.

The `download` command needs the [GitHub CLI](https://cli.github.com) (`gh`) in
your `PATH`. Two variables control the source: `YCODER_REPO` (the default value
is `ynfra/ycoder`) and `YCODER_REF` (the default value is `master`). Use them
for a private fork:

```bash
YCODER_REPO=myorg/ycoder YCODER_REF=main ./ycoder.sh download
```



## Templates in this folder


| Folder       | Copied from vibestack | Notes                                  |
| ------------ | --------------------- | -------------------------------------- |
| `vibestack/` | *(the source)*        | General workspace. You can push it     |
| `docker/`    | No                    | Old template. It has its own `main.tf` |
| `mux/`       | No                    | Old template. It has its own `main.tf` |
| `ohmyfelix/` | No                    | Old template. It has its own `main.tf` |


The `docker/`, `mux/` and `ohmyfelix/` folders are older than the sync tool.
They have their own `main.tf` files.

**Caution:** The `sync` and `validate` commands read **all** folders when you
give no name. The `sync` command would replace the files of these three
templates. Therefore always give the names of the templates that you want.