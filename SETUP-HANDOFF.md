# Handoff notes

Open questions and unfinished work. Not a task list to execute blindly, read the context first.

Last updated 2026-07-20, after the work PC setup.

---

## TASK: one deliberate git-history rewrite pass

**Raised 2026-07-20. Scoped session, not casual. Do not start this incidentally.**

Two separate problems share one solution, so do them in a single planned pass rather than
twice. Both are history-level: the working trees are already clean.

### What needs rewriting

**1. Client references pruned from `claude-kit` (done in the working tree, still in history).**

Commits `f5cb9b8` and `d157dfd` removed 12 allowlist entries from
`claude-config/settings.json`. They are gone from `HEAD` but fully recoverable from history and
from any existing clone:

| What | Detail |
|---|---|
| Third-party PII | A real person's display name and email address, passed to an `occ user:add` one-off. The most sensitive item here. |
| Partner infrastructure identifier | 5 entries. Behind the same isolation boundary as the `mark` and `skyhawk` buckets. |
| Partner client identifier | 5 entries, including a token filename. |
| A named WSG client | 2 entries with paths into that client's site directory. |

The exact strings are deliberately not written out here, because this file lives in the same
repo that seeds every machine, which is the problem being fixed. Read them from the two commits
named above: `git show f5cb9b8` and `git show d157dfd`. The rewrite session will be working
through history regardless.

**2. `mark/` and `skyhawk/` inside `wsg-client-projects`.** See the investigation section below.
If the answer there is that they should not be in that repo, removing them from `HEAD` is not
enough either, for the same reason. Their full history stays reachable in the objects, which is
exactly what the current sparse checkout does not solve.

### Why this needs planning

`git filter-repo` plus a force push **invalidates every existing clone**. Both machines need a
re-sync afterwards, and any clone that is not re-synced can push the old history straight back.
Concretely:

- Every commit SHA after the rewrite point changes. Anything referencing a SHA breaks, including
  notes in `ESTATE.md`, memory files, and the two commit hashes named above.
- The work PC and the home PC both need a fresh clone or a hard reset onto the rewritten history.
  A stale clone is not a passive risk, it is an active one.
- For `wsg-client-projects`, everything with a deploy key or CI against it needs checking first.
  Memory `project_skybox7_mark.md` documents per-repo ed25519 deploy keys.
- GitHub keeps unreachable objects accessible by SHA for a while after a force push. If the PII
  is the driver, the rewrite alone is not sufficient. It needs GitHub support contacted to purge
  the cached refs, or the repo recreated.

### Suggested order when the session happens

1. Decide the `wsg-client-projects` question first. It changes whether that repo is even in scope.
2. Inventory every clone of both repos across both machines and both VPS boxes.
3. Take a full mirror backup of each repo before touching anything.
4. Run `filter-repo` on a fresh mirror clone, never on a working clone.
5. Verify the target strings are gone from all refs, not just `main`.
6. Force push, then immediately re-sync every clone identified in step 2.
7. Rotate anything that was exposed, on the assumption the old history was already fetched.

Item 7 matters most for the PII, which cannot be rotated. Consider whether that alone justifies
the disruption, or whether it is better handled by contacting GitHub.

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

## Repo coverage

Resolved 2026-07-20. The account has **68 repos**, 66 private and 2 public.

The GitHub MCP connector only ever returned the 2 public ones, which is why an earlier pass
undercounted. `gh` is not installed on the work PC, so the full list came from the REST API
using the token out of Git Credential Manager, passed to curl through a config file so it never
appeared in argv. That config file was overwritten and deleted immediately afterwards. **Do not
write that token into any file, note, or commit.**

Bucket assignments come from `ESTATE.md` in the `wsg-platform` repo. Note that ESTATE.md lists
**services**, not repos, so only 24 of the 68 matched by name. `/root/HANDOFF.md` on VPS1
contains no bucket assignments at all despite being 408 lines.

Placed on the work PC: platform 27, ventures 11, personal 11, clients 1, unsorted 13.

**Deliberately absent:**

| Repo | Why |
|---|---|
| `adams-glass`, `jonny-sanchez`, `mistah-seamless-gutters` | Described as Skyhawk partnership work. Not in ESTATE.md, excluded to honour the isolation rule. |
| `partners` | ESTATE.md assigns it to the `skyhawk` bucket. |
| `spice-strategy` | ESTATE.md assigns it to `decommission`. |
| `sam-sms`, `wsg-tiktok` | Exist only on VPS1 with no git remote. Cannot be cloned, only copied. |

**Still in `unsorted/` (13),** with no assignment found in ESTATE.md or the VPS1 workspace
files. Not guessed at, waiting to be sorted: `b-oss-partnership`, `cinder`,
`creator-discovery`, `dealophant-church-affiliate`, `event-roster`, `itsjustin-site`,
`justin-tools`, `letta-tools`, `realm-of-the-arcs`, `tasks`, `thejdubb02`, `trackio`,
`webdesign-inbox-agent`.

**Folder name that differs from its repo name:** `personal/tax-dash` is the repo
`thejdubb02/quartermaster`. VPS1 uses `/root/tax-dash` and `project_quartermaster_tax.md`
documents that path, so the work PC matches. This was inferred from VPS1 and memory, **not**
verified against the home PC, which is not reachable for filesystem inspection.

---

## Secrets hygiene

`credentials.md` in the memory folder holds literal values, which conflicts with the standing
rule in `feedback_no_secrets_in_files.md`. Known, and covered by the pointer-ize task that is
blocked on credential rotation.

Separately, `dealophant-brand-marketplace.md` contains an inline Postgres connection string with
a live password. Flagged 2026-07-20, not yet confirmed whether it falls under the same task.
