---
name: docker
display_name: Docker
description: A Docker workspace with code-server
icon: /icon/docker.svg
maintainer_github: f3l1x
tags: [docker, container]
---

# Docker

A simple Coder workspace in a Docker container. You get **code-server**, VS Code
in your browser. Open it from the Coder dashboard.

The image is `dockette/coder:fx`. It has PHP, Composer, Node, Bun, Deno, Python
and Go.

## Home folder

Your home folder is a Docker volume. It stays after a restart. Files outside the
home folder go away. Put new tools in the image.

Coder also sets your name and your email for git commits.

## Variables

| Variable        | Default | What it does          |
| --------------- | ------- | --------------------- |
| `docker_socket` | `""`    | The Docker socket URI |

## How to push

**Caution:** This template has its own `main.tf`. Do not run `./ycoder.sh sync`
or `./ycoder.sh push` on it. Both commands copy the vibestack files over it.

```bash
coder templates push docker -d .
```
