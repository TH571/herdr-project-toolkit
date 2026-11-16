# herdr-project-toolkit

Project lifecycle tooling for AI coding agents: **process files stay in a work area, deliverables go straight to a store area**, and two machines can work in parallel without overwriting each other.

English | [简体中文](README.zh-CN.md)

Three commands plus two agent skills:

| Command | What it does |
|---|---|
| `new-project <name>` | create the work area, store area, `AGENTS.md`, write permission for the agent, and a Herdr space |
| `delete-project <name>` | delete a project: both directories into a trash folder, close the space, never `rm` |
| `skills-sync` | distribute the skills in `~/.agents/skills` to every agent's skill directory |

| Skill | Triggered by |
|---|---|
| `project-init` | "new project", "init a project", "where should this project live" |
| `project-delete` | "delete this project", "remove project" |

## What problem it solves

The usual mess when several agents and two computers work on the same thing: deliverables mixed with scratch files, cloud sync producing `..._conflict_2026-11-16.md` copies, and nobody sure what is safe to delete.

The toolkit separates three concerns:

```
work area (local disk, delete whenever)
  src/  tmp/  logs/        ← drafts, logs, caches, intermediate data
  AGENTS.md                ← rules: where deliverables go, how to classify them
  .claude/settings.json    ← pre-authorises the agent to write the store area

store area (can live on a synced disk, partitioned per machine)
  <project>@<machine-label>/   ← deliverables land here + OWNER
```

The key idea: **deliverables are written to the store area directly**, so there is no "write it in the work area, ask the user whether it counts, then copy" ritual.

## Install

```sh
git clone https://github.com/TH571/herdr-project-toolkit.git
cd herdr-project-toolkit
./install.sh
```

`install.sh`:

1. copies `bin/` into `~/.local/bin`
2. copies `skills/` into `~/.agents/skills`
3. creates `~/.config/new-project/config` on first run (never overwrites)
4. calls `skills-sync` to distribute the skills
5. prints a version self-check

Requirements: macOS (`scutil`, `md5`), `bash 3.2+`. Optional: `herdr-app` (creates/closes spaces), `python3` (JSON parsing).

## Quick start

```sh
# 1) set the two roots (defaults: ~/Projects and ~/Projects-archive)
$EDITOR ~/.config/new-project/config

# 2) set the machine label (matters when you use more than one machine)
$EDITOR ~/.config/new-project/machines.conf

# 3) see where it would create things
new-project my-project --dry-run

# 4) create it
new-project my-project --git
```

Then, inside the work area, tell the agent to write deliverables into the store area, and delete the work area whenever the project is done.

## Configuration

`~/.config/new-project/config`:

```
WORK_ROOT=/Users/you/Projects
STORE_ROOT=/Users/you/Projects-archive
```

`~/.config/new-project/machines.conf` (hostname → label used in directory names):

```
my-macbook=mac-a
mac-a=mac-a
imac-7=iMac-7
```

Why a map instead of the hostname directly: directory names should be short and stable, while hostnames are often long or carry a `.local` suffix.

## Design notes

[`docs/22-project-lifecycle.md`](docs/22-project-lifecycle.md) explains the reasoning: the three-zone model, why the store area is partitioned per machine, why classification is a written rule instead of a question, why deletion never uses `rm`, and the eight pitfalls hit along the way.

## Why it is built this way

**1. Separate work from store**
The work area can be deleted wholesale (deliverables are already in the store), so "can I delete this folder?" stops being a hard question.

**2. Partition the store per machine (`<project>@<machine>`)**
Two machines syncing one directory always produce conflict copies. Partitioning removes the collisions; the trade-off is that **syncing is not merging** — the same project worked on from two machines yields two sets of files, and combining them is manual.

**3. Classification as a written rule, not a question**
`AGENTS.md` contains the table: documents / reports / data tables / slides / charts / ship-ready pages / reusable tools are deliverables; drafts / logs / caches / intermediate data / one-off scripts are not. When unsure, write into `_pending/` in the store area — **storing too much beats interrupting the user**.

**4. Deletion never uses `rm`**
Both directories are `mv`-ed into `<WORK_ROOT>/.deleted/<timestamp>-<project>/` with a `META.md` holding the restore commands. On the same volume this is instant and costs no extra space.

**5. No symlinks**
Mapping the store area into the project via a symlink breaks when you change machine or username. One measured sync directory had 76 symlinks, 69 of them broken.

## Pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| The space points at the wrong directory and cannot be fixed | a Herdr space's `folder` is immutable (no `set_folder`) | pass `--folder` at creation; otherwise close and recreate |
| The delete command "ran" but nothing happened | it ran inside the project's own terminal: the cwd was moved and the space closed, killing the command | `cd ~` first, or use `--keep-space` |
| The store directory has a strange hostname suffix | `machines.conf` has no entry for this machine | add `<hostname>=<label>` |
| A script dies with `unbound variable: NAME�` | bash 3.2 swallows the bytes after `$VAR` when a CJK character follows | always write `${VAR}` (fixed in the scripts) |
| The agent ignores `SKILL.md` | Codex 0.169 has no skills mechanism | put the rules in `~/.codex/AGENTS.md` as well |

## Layout

```
bin/new-project       create a project (incl. AGENTS.md, .claude/settings.json, Herdr space)
bin/delete-project    delete a project (report → confirm → trash → close space → self-check)
bin/skills-sync       distribute skills and verify hashes
skills/project-init/  the init skill
skills/project-delete/the delete skill
config/               configuration templates
docs/                 design notes
```

## License

MIT
