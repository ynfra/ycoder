# Coder Templates

## Tooling

```bash
./ycoder.sh sync     [template...]     # vendor vibestack into template folders
./ycoder.sh create   <template>        # scaffold custom.tf + startup.custom.sh
./ycoder.sh validate [template...]     # terraform validate (temp dir)
./ycoder.sh push     <template> [args] # sync, then push (make push if present)
./ycoder.sh download                   # fetch latest ycoder.sh + vibestack into CWD
./ycoder.sh version
```

## Download

`download` uses the GitHub CLI (`gh`) against `ynfra/ycoder` (`YCODER_REPO` /
`YCODER_REF` override). Preserves an existing `vibestack/.env`.

## Sync

`vibestack/` is the shared source. Every other sibling directory is a template.
`sync` (with no args) vendors into all of them; pass names to limit the set.

## Pushing

Templates that need secrets ship a `Makefile` `push` target (loads `.env` and
passes `--variable` flags). Then:

```bash
./ycoder.sh push vibestack
```

Without a Makefile, `push` runs bare `coder templates push` — pass any extra
args yourself. 

## Coder CLI

Session auth comes from `CODER_URL` / `CODER_SESSION_TOKEN` via envrc.
