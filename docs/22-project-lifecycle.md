# Project lifecycle: create, deliver, delete

[English](22-project-lifecycle.md) | [简体中文](22-project-lifecycle.zh-CN.md)

> This started as a chapter in the author's local notes and is included here as the design rationale, with personal details removed.
> `<WORK_ROOT>`, `<STORE_ROOT>` and `<machine-label>` are placeholders; see the [README](../README.md#configuration).
> Pitfall ids (BB–BI) keep the numbering from the original notes, so gaps are expected.

## Three zones, three jobs

| Zone | Location | What lives there | Synced |
|---|---|---|---|
| **Work area** | `<WORK_ROOT>/<project>` | code, drafts, logs, caches, intermediate data | no, local disk |
| **Store area** | `<STORE_ROOT>/<project>@<machine-label>` | **all deliverables** | yes, backed up |
| **Herdr space** | `spaces[].folder` in `docs.json` | only "where does a terminal start" | no |

The responsibilities do not overlap: **the work area can be deleted wholesale** (deliverables are in the store), **the store area is the only home of deliverables**, and **the space merely tells you which project is running**. Mixing them produces accidents like "deleted the work area and lost the deliverables".

## `new-project`: six things in one command

```sh
new-project my-project --git
```

| Output | Purpose |
|---|---|
| `src/ tmp/ logs/` | home for process files — "nothing here goes to the store" |
| `AGENTS.md` | project conventions: zones, hard rules, classification table, wrap-up. **Rules travel with the project** |
| `.gitignore` | excludes `.claude/settings.local.json`, aider history, `node_modules`, `DONE` |
| `PROGRESS.md` | cross-session state: Done / Next / Blocked |
| `.claude/settings.json` | `permissions.additionalDirectories` lists the store area, so Claude stops asking for permission |
| store `OWNER` | records `machine`, `hostname`, `store_dir` — which machine owns this directory |
| Herdr space | same-named space with `folder` set to the work area; skipped if the name is taken |

Common flags: `--git`, `--no-space`, `--readonly` (store read-only right away), `--dry-run`, `--force` (fill in missing files only, never overwrite), `--machine` (override the label).

## Store naming: the machine label is not the hostname

Directory names look like `my-project@mac-a`. The suffix is a **machine label**, resolved through `~/.config/new-project/machines.conf`:

```
my-macbook=mac-a
mac-a=mac-a
imac-7.local=iMac-7
imac-7=iMac-7
```

Why not use the hostname directly: `my-macbook-pro.local` is long and noisy, while the store root already uses short names like `mac-a`, `iMac-7`, `mac-b`. The map separates "how the OS names this machine" from "how the directory is named", so directories stay readable and scripts stay simple.

> **Syncing is not merging.** Two machines write `@mac-a` and `@iMac-7`, so they stop fighting over one directory and conflict copies largely disappear. The cost: the same project worked on from both machines yields two sets of deliverables, and combining them is manual. Partitioning solves "overwriting", not "merging".

## Deliverable classification: a rule, not a question

An early version had the agent write into the work area and then ask "is this a deliverable?" — every single instruction needed a human decision, and the criteria drifted. The current model is **decide the rule once, then let the agent apply it**:

| Deliverable → write to the store area | Not a deliverable → keep in the work area |
|---|---|
| documents / reports (finished `.md`, `.docx`, `.pdf`) | drafts, discarded versions, experiments |
| data tables (`.xlsx`, `.csv` results, ledgers) | logs, caches, `__pycache__`, `node_modules` |
| slides / charts (`.pptx`, exported `.png`, `.svg`) | intermediate data, raw material, extracted temp dirs |
| ship-ready pages / programs, reusable tool scripts | one-off migration or debug scripts |

Three hard rules go into `AGENTS.md`: **① write deliverables to the store immediately**, never write-then-copy; **② never ask** "is this a deliverable"; **③ when unsure, write to `_pending/` in the store** — storing too much beats interrupting the user.

> **Measured evidence.** In project `proj-b` the agent produced `report.md` and it appeared **only in the store area** — no copy in the work area. In the earlier project `proj-a`, `notes.md` existed in both places with an identical mtime (the signature of `cp -p`), meaning it had been "written to the work area and copied afterwards". Comparing the two makes it obvious whether the rule is actually in effect.

**Why the automatic safety net was removed.** There used to be a `sync` command that scanned the work area by extension whitelist and copied matches to the store. It created a second judge — rules in one place, whitelist in another — and when they disagreed nobody knew which to trust. The heuristic also classified `notes.md` as a deliverable and missed `.numbers` entirely. With it gone there is one path, and a mistake is visible in `git status`.

## Herdr spaces: the folder is fixed at creation

> **There is no global "initial folder" setting.** The starting directory belongs to the **space**, stored as `spaces[].folder` in `~/.local/state/herdr-core/default/docs.json`. Clicking `+` in the app opens a dialog that **only asks for a name**; the folder defaults to *the folder its terminals start in (default: the focused terminal's)*.

Two rules to remember:

1. **The folder cannot be changed afterwards.** The command set is `space.new / rename / colors / move / select / next / prev / close` — there is **no `set_folder`**. Changing it means closing and recreating the space, which ends every terminal inside.
2. **A terminal's cwd is independent of the space folder.** `cd` inside a terminal only changes that terminal's `cwd` (recorded in `terminals.json`). So "create the space, then cd" does not move the space; the order must be "cd first, then create the space" — or create it from the CLI with an explicit path.

```sh
# create a space with an explicit folder (no cd needed)
herdr-app do space.new --name my-project --folder "$HOME/Projects/my-project"

# optional: start an agent, give it a first task, do not steal focus
herdr-app do space.new --name X --folder /abs/path --argv '["zsh"]' --focus false

# close a space (ends its terminals)
herdr-app do space.close --id <space-id> --confirmed true
```

**The CLI does not inherit the current directory.** Without `--folder`, a script-created space starts in that machine's home — *this computer for scripts … its terminals start in that machine's home unless folder* — so always pass an absolute path.

A practical pattern is "one incubator plus one space per project": an `init` space whose folder stays at `<WORK_ROOT>` is where new projects get created, and `new-project` then creates a same-named space pointing at the new work area.

## Deletion: three actions, four gates

`delete-project <project>` does three things at once: move the work area to trash, move the store area to trash, close the Herdr space. Four gates keep it safe:

| Gate | Behaviour |
|---|---|
| Read-only report | without `--yes` it only prints paths, sizes, file counts, terminal counts and risks |
| Risk pre-checks | uncommitted changes / zero commits / no `DONE` / live terminals |
| No `rm` | both directories `mv` into `<WORK_ROOT>/.deleted/<timestamp>-<project>/`, with a `META.md` holding the restore commands |
| Self-check | after moving, verifies both paths are gone and reports "deletion did not complete" otherwise |

> **Do not run it inside the project's own terminal.** This one was hit for real: running `delete-project proj-a --yes` from `proj-a`'s own terminal, the script moved the directory away and then closed the space it lived in — the terminal died mid-command and **nothing actually happened** (directories still present, space still present, trash empty), while the screen made it look executed.
> The current version refuses to run from inside the project (exit code 2) and prints two options: `cd` outside first, or `--keep-space` to delete directories only and close the space later. `--force-inside` overrides the check; nobody needs it.

## Skill distribution: one source, fourteen visible copies

Skills live in user-level directories, not in projects, so they can be triggered from any cwd. The source is `~/.agents/skills/<name>` (omp reads it directly); the other agents are populated by `skills-sync`: Claude gets a symlink, the rest get real copies, and every copy is hash-checked afterwards.

```sh
skills-sync                 # sync and verify everything
skills-sync project-init    # only the named skill(s)
```

> **One exception.** Codex 0.169 **does not read `SKILL.md`** — its subcommands are `plugin` / `marketplaces` and the binary contains no skills machinery — it reads the global instruction file `~/.codex/AGENTS.md`. The same rules have to be written there too, otherwise Codex sees nothing.

There is a trade-off in how you distribute: **never symlink into a synced folder.** One measured sync directory had 76 symlinks, 69 of them broken, because they pointed at another machine's absolute paths or differed by username case (`/Users/alice` vs `/Users/Alice`). Keeping the source in the local home directory and distributing real copies costs a few megabytes and saves a class of bugs.

## Pitfalls hit along the way (BB–BI)

| # | Pitfall | Fix |
|---|---|---|
| BB | **No folder field in the `+` dialog**: it only asks for a name; the directory comes from the focused terminal | `cd` first, or `herdr-app do space.new --name X --folder /abs/path` |
| BC | **Assuming a space folder can be changed**: there is no `set_folder` | set it correctly at creation; otherwise close and recreate (which ends terminals) |
| BD | **Deleting a project from its own terminal**: the cwd moves, the space closes, the command is killed, nothing happens | run from outside, or `--keep-space`; v1.2+ refuses to run inside |
| BE | **A renamed space is not found**, so deletion leaves it behind | match by name **or** folder path |
| BF | **bash 3.2 swallows the bytes after `$VAR`** when a CJK character follows, giving `unbound variable: NAME�` | always write `${VAR}` |
| BG | **Putting `-name *.md` in a variable** lets the shell glob it against the current directory, silently breaking the `find` expression | inline the pattern and quote it: `-name '*.md'` |
| BH | **Assuming Codex reads `SKILL.md`**: 0.169 has no skills mechanism | write the rules into `~/.codex/AGENTS.md` as well |
| BI | **Using `du` to judge whether a copy costs space**: under APFS copy-on-write, shared blocks are counted twice | use `df`: copying a 256 MB file with `cp -c` changed free space by 0 MB |

> **In one sentence.** The point of a project lifecycle is not more tooling but **exactly one owner per action**: directories are created by `new-project`, deliverables are written by the agent straight into the store, the space is defined by the folder given at creation, and deletion is a single `delete-project` run that never touches `rm`. Any action with two owners ends up with two judges, two copies and two versions of the truth.

Basis for this chapter: the actual behaviour and source of `new-project`, `delete-project` and `skills-sync`; the `space.*` command set reported by `herdr-app commands` (no `set_folder`), the seven arguments of `space.new`, and the `id` / `confirmed` arguments of `space.close`; the wording embedded in the Herdr binary ("the folder its terminals start in (default: the focused terminal's)", "its terminals start in that machine's home unless folder"); the split between `spaces[].folder` in `docs.json` and the independent `cwd` in `terminals.json`; the measured comparison between `proj-b` (`report.md` only in the store) and `proj-a` (`notes.md` in both, identical mtime); a session log whose last `run_shell_command` never returned; the 76-symlink / 69-broken statistic from one sync directory; and the AFPS copy-on-write measurement (256 MB file, `cp -c`, `df` unchanged, `du` reporting 512 MB).
