# ycoder — Coder workspace templates

`ycoder.sh` manages Coder workspace templates. `vibestack/` is the source. Each
other folder is a template and holds a copy of the source files.

---

## What Coder is

[Coder](https://coder.com) gives you a development workspace on a server.

1. You push a **template** to the Coder server.
2. A user makes a **workspace** from the template.
3. The workspace runs on the server. The user opens it in a browser.

A template is a Terraform configuration. Coder runs Terraform on the server.

| Subject | Link |
| --- | --- |
| Coder documents | <https://coder.com/docs> |
| Templates | <https://coder.com/docs/admin/templates> |
| `coder templates push` | <https://coder.com/docs/reference/cli/templates_push> |
| Coder Terraform provider | <https://registry.terraform.io/providers/coder/coder/latest/docs> |
| Registry | <https://registry.coder.com> |

## Terraform

Terraform reads all `.tf` files in one folder as one configuration. Therefore
`main.tf` and `custom.tf` are one plan.

Do not run `terraform` yourself. Do not run `terraform apply`. The Coder server
applies the plan. Use the tool:

```bash
./ycoder.sh validate <template>
```

The command works in a temporary folder. Therefore this repository never gets a
`.terraform/` folder.

## The tool

Run the script with no argument. It shows every command:

```bash
./ycoder.sh
```

`README.md` tells you what each command does.

## Documents

| Document | Content |
| --- | --- |
| `README.md` | The tool, the commands and the procedure |
| `AGENTS.md` | This file. The conventions |
| `vibestack/README.md` | The workspace: the apps, the variables and the host |

Write a fact one time. A fact about the workspace goes in
`vibestack/README.md`. A fact about the tool goes in `README.md`.

The root `AGENTS.md` of the monorepo holds the rules for the split.

---

## Conventions

Run `./ycoder.sh agent` for these rules and the file map in one output.

- **Change the files in `vibestack/`.** Then run `./ycoder.sh sync`.
- **Do not change a generated file.** Each one has a banner. The next `sync`
  command removes your change.
- **Always give the name of the template.** With no name, `sync` and `validate`
  read every folder. Therefore they write into the old templates too.
- **Copy the files. Do not make symbolic links.** Coder removes a symbolic link
  to a `.tf` file from an upload.
- **Put your changes in `custom.tf` or `startup.custom.sh`.** The two files are
  optional. `sync` does not change them.
- **Read `CUSTOM.md` in a template folder first.** `create` writes it. It holds
  the rules of that folder for an AI agent.
- **Put a secret value in `.env`.** Do not put it in a `.tf` file. Do not put it
  in a document.
- **Run `./ycoder.sh validate <template>` before each push.**

## Git

Make small commits. Put one change in one commit.

Use this pattern for the subject line:

```
<Category>: <message>
```

The category is `Feat`, `Fix`, `Docs`, `Refactor` or `Chore`. The message is a
short summary in the imperative mood.

Write a basic bullet list in the description. Give one line for each change.

```
Docs: split the README by document type

- Move the command reference to the end
- Add a quickstart for vibestack
- Correct the description of the validate command
```

Do not add a co-author. Do not add the name of a tool.

In the ynfra monorepo, put `[ycoder]` before the category.

## How to write

Write all documents and all comments in **Simplified Technical English**
(ASD-STE100). Keep the comments short.

- Write short sentences. Use a maximum of 20 words in an instruction. Use a
  maximum of 25 words in a description.
- Write one instruction in one sentence.
- Use the active voice. Write "The command copies the files".
- Use the simple present tense.
- Use the imperative mood for an instruction. Write "Set the token".
- Use the same word for the same thing.
- Keep the articles. Write "the token", not "token".
- Do not use slang, idioms or jargon.
- Do not use more than three nouns together.
- Use "must" for a mandatory action. Use "can" for a permitted action.
- Give a warning or a caution before the instruction, not after it.
