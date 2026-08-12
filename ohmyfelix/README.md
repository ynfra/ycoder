---
name: ohmyfelix
display_name: OhMyFelix
description: Felix's Docker workspace with code-server and a home folder on the host
icon: https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/svg/docker.svg
maintainer_github: f3l1x
tags: [docker, container]
---

# OhMyFelix

A Coder workspace in a Docker container. You get **code-server**, VS Code in
your browser. Open it from the Coder dashboard.

The image is `dockette/coder:fx`. It has PHP, Composer, Node, Bun, Deno, Python
and Go.

## Home folder

Your home folder is the host folder `/srv/coder/ohmyfelix`. It is not a Docker
volume.

**Caution:** Every workspace of this template uses the same host folder. Two
workspaces write the same files.

The folder must be on the host. Files outside the home folder go away after a
restart.

Coder also sets your name and your email for git commits.

## Variables

| Variable        | Default | What it does          |
| --------------- | ------- | --------------------- |
| `docker_socket` | `""`    | The Docker socket URI |

## How to push

**Caution:** This template has its own `main.tf`. Do not run `./ycoder.sh sync`
or `./ycoder.sh push` on it. Both commands copy the vibestack files over it.

```bash
coder templates push ohmyfelix -d .
```
