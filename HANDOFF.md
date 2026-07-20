# Handoff notes

Open questions and unfinished work. Not a task list to execute blindly, read the context first.

Last updated 2026-07-20, after the work PC setup.

---

## INVESTIGATE: why does `wsg-client-projects` contain `mark/` and `skyhawk/` history?

**Raised 2026-07-20. Do not act on this yet, investigate first.**

The `thejdubb02/wsg-client-projects` monorepo has these top level directories:

```
_shared  clients  mark  skyhawk  tools  ventures
```

So `mark/` and `skyhawk/` are not separate repositories. They are directories inside the
client monorepo, and their full history lives in that repo's git objects.

**Why this matters:** the standing isolation rule treats Mark and Skyhawk work as a separate
session, on the assumption that they live in separate repos. That assumption is wrong. Anyone
who clones `wsg-client-projects` for client or venture work also receives the complete history
of `mark/` and `skyhawk/`, including every file ever committed there, whether or not those
directories are ever checked out.

**What was done on the work PC as a stopgap:** cloned with `--no-checkout`, then a cone mode
sparse checkout that excludes `mark/`, `skyhawk/`, and `clients/drd-signs/scrape/`. That is
**working tree isolation only**. The objects are still in `.git`. Confirmed acceptable for now,
but it is not true isolation.

**Questions to answer before deciding anything:**

1. Was the isolation rule written before or after `mark/` and `skyhawk/` were added to this repo?
   In other words, is this drift from the rule, or did the rule never match reality?
2. Does anything actually depend on those directories being in this repo? Shared tooling under
   `tools/` or `_shared/`, CI, deploy scripts?
3. Do Mark's own repos under the `duchampmark` account already duplicate this content? If so,
   the copies in `wsg-client-projects` may just be stale leftovers from before the debleed work
   in `project_mark_debleed_migration.md`.
4. If they should come out: is a plain deletion enough, given the history remains reachable, or
   does this need a history rewrite (`git filter-repo`) and a force push? A rewrite invalidates
   every existing clone, so it needs a deliberate window.

**Related memory:** `project_mark_debleed_migration.md` (the goal of zero Mark footprint on WSG
infrastructure), `project_skybox7_mark.md` (all Mark repos live under `duchampmark`, authed with
Mark's PAT, never Justin's), `feedback_github_token_thejdubb02_only.md`.

---

## Open from the work PC setup

See `SETUP-NEW-MACHINE.md` for the full runbook. Still outstanding on that machine:

| Item | State |
|---|---|
| bash-guard hooks | Paths fixed, inert until real Python is installed. `python3` is the Store stub. |
| statusline | Not wired. No `statusLine` key in `settings.json`, and `jq` is missing. |
| `install.sh` on Windows | Install once. `ln -s` silently copies, so re-runs update nothing. |
| `meridian` MCP server | Omitted from `settings.json` until SSH to that VPS is set up. |
| Nine other VPS1 memory folders | About 47 files, not pulled. Only `-root` (294 files) came across. |
| Nextcloud and Stripe connectors | Need re-auth in claude.ai connector settings. |
| `sam-sms`, `wsg-tiktok` | Exist only on VPS1 with no git remote. Cannot be cloned, only copied. |

---

## Repo coverage gap

The work PC was populated from what VPS1 actually had checked out, which is 15 repos. Memory
(`project_sam_oversight_agent.md`) says the `thejdubb02` account has roughly 57. The GitHub API
returns only the 2 public ones, so the private list could not be enumerated to place the
remainder into buckets.

If a repo is missing from a bucket on a new machine, that is why. The `unsorted/` bucket exists
for anything that does not have an obvious home.

---

## Secrets hygiene

`credentials.md` in the memory folder holds literal values, which conflicts with the standing
rule in `feedback_no_secrets_in_files.md`. Known, and covered by the pointer-ize task that is
blocked on credential rotation.

Separately, `dealophant-brand-marketplace.md` contains an inline Postgres connection string with
a live password. Flagged 2026-07-20, not yet confirmed whether it falls under the same task.
