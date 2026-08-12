---
name: mux
display_name: Mux
description: A Node workspace with code-server and the Mux app
icon: /icon/terminal.svg
maintainer_github: f3l1x
tags: [docker, container, node]
---

# Mux

A Coder workspace in a Docker container. You get two apps. Open them from the
Coder dashboard.

- **code-server** — VS Code in your browser.
- **Mux** — from the Coder module `coder/mux`, version 1.3.1.

The image is `codercom/enterprise-node:ubuntu`. It has Node.

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
coder templates push mux -d .
```
