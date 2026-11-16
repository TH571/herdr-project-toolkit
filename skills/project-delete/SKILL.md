---
name: project-delete
description: Delete every trace of a project — the work area directory, the store area deliverables, and the matching Herdr space. Use when the user says "delete this project", "remove project", "clean up project", or "I don't need this anymore". Always prints a report first (size, file count, uncommitted git changes, DONE marker, terminal count), requires explicit confirmation, and moves files into a local trash folder instead of deleting them.
---

# Delete a project (work area + store area + space)

This is a **destructive operation** and the only skill in this toolkit that must stop and wait for the human. Everything else: decide yourself, do not ask.

## When to use

- The user explicitly says "delete / remove / clean up / I don't need it anymore" about a project
- The project is archived and only the local and store copies remain

**Not for**:

- Archiving deliverables (they already live in the store area)
- Deleting a single file or subdirectory — just delete that file
- Closing a terminal — use `hc rm <address>`

## Procedure (six steps, none optional)

**Step 1: pin down the target**

If the user has not named one, list candidates instead of guessing:

```sh
ls -1 <WORK_ROOT>
herdr-app ls | python3 -c 'import json,sys;[print(s["name"],"|",s.get("folder")) for s in json.load(sys.stdin)["spaces"]]'
```

**Step 2: get the report (nothing is touched)**

```sh
delete-project "<project>"
```

Without `--yes` it only prints: paths, sizes, file counts, live terminals, and risk warnings.

**Step 3: restate the report and wait for confirmation**

Cover four things:

1. Work area path + size + file count
2. Store area path + size + file count
3. Whether the space will be closed, and how many terminals it holds (**closing ends them immediately**)
4. Every warning: uncommitted changes / no commits / no `DONE` / unpushed commits

Then **stop and wait**. This is the one place in this toolkit where asking is mandatory.

**Step 4: run it from outside the project**

**Never run it inside the project's own terminal.** The script moves that directory away and closes the space it lives in — the calling terminal is very likely killed mid-run, which looks like "the command ran but nothing happened".

```sh
# A. from anywhere outside the project (recommended)
cd ~ && delete-project "<project>" --yes

# B. if you must stay inside: delete directories only, close the space later
delete-project "<project>" --yes --keep-space
herdr-app do space.close --id <space-id> --confirmed true
```

The script refuses to run inside the project directory (exit code 2) and prints both options; `--force-inside` overrides, but nobody needs it.

**Step 5: verify, do not trust the exit code**

```sh
ls -d <WORK_ROOT>/.deleted/*"<project>"    # the trash entry must exist
herdr-app ls | grep "<project>"            # the space must be gone (allow 1-2s)
```

All three must hold: work area moved, store area moved, space gone. If any fails, report "deletion did not complete" with the reason — **never claim success**.

**Step 6: report the outcome**

```
Moved to <WORK_ROOT>/.deleted/<timestamp>-<project>/
Restore: mv .../work  <WORK_ROOT>/<project>
         mv .../store <STORE_ROOT>/<project>@<label>
```

## Safety mechanisms (enforced by delete-project, do not bypass)

| Mechanism | Behaviour |
|---|---|
| No `rm` | both directories are `mv`-ed into `<WORK_ROOT>/.deleted/<timestamp>-<project>/` (instant on the same volume) |
| `--yes` required | without it the script only prints a report |
| Risk pre-checks | uncommitted changes, zero commits, missing `DONE`, live terminals — each flagged |
| This machine only | touches `<project>@<this label>`; other machines' directories are left alone |
| Metadata | writes `META.md` (timestamp, machine, space id, original paths, risk items, restore commands) |
| Self-check | after moving, re-checks that both paths are gone and reports failure if not |

## Hard constraints

1. **Never use `rm -rf` / `trash` on a project directory** — always `delete-project`. Bypassing it leaves the space behind and leaves no trash record.
2. **Never skip confirmation**: no explicit "delete / yes / go ahead" from the user means no `--yes`.
3. **Closing a space ends its terminals** — say so plainly; do not hide it behind "clean up".
4. **List candidates when unsure**, never guess by name similarity.
5. **Never close the space without deleting the directories, or delete directories without closing the space.**
6. Do not empty the trash afterwards; that is the user's decision.

## Purging (only when the user explicitly asks)

```sh
rm -rf <WORK_ROOT>/.deleted/<timestamp>-<project>
```

Confirm again first and state that it cannot be undone.
