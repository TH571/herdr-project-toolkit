---
name: project-init
description: Scaffold a project with a separate work area and store area, and propose reasonable paths for both. Use when the user says "new project", "init a project", "create a project", "where should this project live", "set up a workspace", or asks how to separate code from deliverables. Probes the machine first and suggests paths, accepts user-supplied paths, and names the store dir with a machine label (e.g. my-project@work-mac) so multiple machines never overwrite each other.
---

# Initialize a project (work area / store area)

Settles "where does the project live, where do deliverables go, and how do two machines avoid stepping on each other" in one conversation.

## When to use

- The user wants to start a project but has not said where it should live
- The user asks "where should this project go" or "how do I separate code from deliverables"
- An existing folder may or may not belong inside a cloud sync directory

**Not for**: archiving or cleaning up an existing project; do not use it to restructure a project that already exists.

## Core model: three zones

| Zone | Purpose | Suggested location | Synced |
|---|---|---|---|
| Work area | code, drafts, logs, caches, intermediate data | `<WORK_ROOT>/<project>` on a local disk | **No** — two machines there produce conflict copies |
| Store area | the only home of deliverables, **agents write here directly** | `<STORE_ROOT>/<project>@<machine-label>` | Yes, one directory per machine |
| Herdr space | only decides where a terminal starts | created automatically by `new-project` | No |

In one line: **the work area can be deleted at any time (git is the safety net); the store area is the only home of deliverables, partitioned per machine.**

## Step 1: probe before suggesting

Do not open by asking "where do you want it". Gather facts first:

```sh
new-project --help | head -22          # defaults and current config
cat ~/.config/new-project/config       # WORK_ROOT / STORE_ROOT
scutil --get LocalHostName 2>/dev/null || hostname -s   # hostname
cat ~/.config/new-project/machines.conf                 # hostname -> machine label
ls -d <WORK_ROOT>/<project> 2>/dev/null                 # name already taken?
ls -d <STORE_ROOT>/<project>@* 2>/dev/null              # did another machine create it?
df -h ~ | tail -1
```

Suggestion rules:

1. **Work area**: use `WORK_ROOT` from the config; if the user's other projects all live somewhere else, suggest following that habit. **Never suggest putting the work area inside iCloud / Dropbox / OneDrive / Google Drive / Nextcloud.**
2. **Store area**: use `STORE_ROOT` from the config; directory name is `<project>@<machine-label>`.
3. **Machine label missing from the map** (first run on a new machine): run `scutil --get LocalHostName`, then add `<hostname>=<label>` to `machines.conf`. Otherwise the directory name falls back to the raw hostname.
4. **Name already exists**: report it and let the user choose rename or `--force`; never force automatically.
5. **A directory from another machine** (`<project>@<other-label>`): warn that it belongs to that machine; do not overwrite it and do not merge with `--no-machine-suffix`.

## Step 2: offer four options

| Option | Meaning |
|---|---|
| A. Use the suggested paths | work area + store area as configured |
| B. Change the work area only | user supplies a path, e.g. `/Volumes/SSD/proj` |
| C. Change the machine label or suffix style | different label, different separator, or no suffix |
| D. Specify both | user supplies both paths |

Accept user-supplied paths verbatim, validating only three things: writable, not a filesystem root, and the two areas neither equal nor nested. If a path fails, ask for another — do not silently substitute your own.

## Step 3: dry run first, then create

```sh
new-project "<project>" --dry-run
# restate both paths (the store one carries @<label>), then drop --dry-run
new-project "<project>" --git
```

Flags: `--git`, `--no-space` (skip the Herdr space), `--readonly` (store area read-only immediately), `--machine <label>`, `--suffix-sep <char>`, `--no-machine-suffix`.

Result:

```
<WORK_ROOT>/<project>/     src/ tmp/ logs/ AGENTS.md .gitignore PROGRESS.md .claude/settings.json
<STORE_ROOT>/<project>@<label>/   OWNER (machine / hostname / store_dir / note)
```

**A same-named Herdr space is created by default**, with `folder` pointing at the work area. If `herdr-app` is missing it only warns.

**Always verify the space afterwards** (the folder cannot be changed later, and a failure is only a warning):

```sh
herdr-app ls | grep -A4 "<project>"      # is folder the absolute work area path?
```

| What you see | What to do |
|---|---|
| folder matches the work area | done |
| "space already exists, skipped" and folder differs | an old same-named space owns the name; it can only be closed and recreated (this ends its terminals) — **ask the user first** |
| "herdr-app not found" or creation failed | directories are fine; hand the user the command the script printed |

## Step 4: tell the user three things

1. **Where deliverables go**: `<STORE_ROOT>/<project>@<label>/`. Agents write there directly; do not write into the work area and ask afterwards. Only `src/ tmp/ logs/` stay in the work area.
2. **Authorisation**: `.claude/settings.json` already lists the store area under `permissions.additionalDirectories`, so Claude needs no extra flags. Other agents use `--add-dir` (Qwen: `--include-directories`; Codex: sandbox writable roots).
3. **What the suffix means**: another machine uses `@<its label>`, so both directories coexist. Merging is manual — syncing is not merging.

## About Herdr spaces: the folder is fixed at creation

- There is no global "initial folder" setting; the directory belongs to the **space** (`spaces[].folder` in `docs.json`)
- The `+` dialog only asks for a name; the folder defaults to **the focused terminal's cwd**
- The command set is `space.new / rename / colors / move / select / next / prev / close` — there is **no `set_folder`**
- A space created from the CLI does not inherit the cwd (scripts land in the machine's home), so always pass `--folder`

```sh
herdr-app do space.new --name "<project>" --folder "<absolute work area>"
herdr-app do space.close --id <space-id> --confirmed true   # ends its terminals
```

## When the script is missing

If `command -v new-project` is empty, create the skeleton by hand and tell the user the script is not installed:

```sh
M="$(scutil --get LocalHostName 2>/dev/null || hostname -s)"
mkdir -p "<WORK_ROOT>/<project>"/{src,tmp,logs} "<STORE_ROOT>/<project>@$M"
printf 'machine: %s\nhostname: %s\ncreated: %s\n' "$M" "$(hostname -s)" "$(date +%F)" \
  > "<STORE_ROOT>/<project>@$M/OWNER"
```

## Hard constraints

1. **Never overwrite files**: `--force` only fills in what is missing.
2. **Keep work areas out of sync folders**: warn on iCloud / Dropbox / OneDrive / Google Drive / Nextcloud.
3. **Write only to your own label's store dir**; do not merge two machines' output.
4. **No symlinks** mapping the store area into the project — they break on machine or username changes.
5. **Do not move an existing project**: agent history is keyed by the absolute cwd, so `--continue` loses old sessions.
6. **Do not put `.git` inside a sync folder**: expect stale `index.lock` files and corrupted objects.
