---
description: Full tooling review of CLIENT infrastructure (Mark / Skybox7 / Duchamp). Hard-isolated from Justin's own estate — separate box, separate Kuma, separate vault entries.
---

Full tooling review for **client infrastructure — Mark Luzaich / Skybox7 / Duchamp
Hotel**. Standalone maintenance session. Do not resume or interleave other work.

`$1`, if given, narrows the scope to one area (e.g. `duchamp`, `dealer-sites`,
`monitors`). No argument = everything below.

===========================================================
PHASE 0: SCOPE GATE — CLIENT SESSION. READ CAREFULLY.
===========================================================

This is client work. It stays fully isolated from Justin's own projects.

| | |
|---|---|
| Server | `mark` / `skybox7` — **2.25.76.180**, and nothing else |
| Kuma | **https://status.skybox7.com** — Uptime Kuma on the `mark` box, fronted by `edge-caddy` |
| GitHub | the **Duchamph** org |
| Code | `/root/mark` only — `skybox7`, `skybox7-platform`, `duchamp`, `dealer-sites`, `american-tank-company`, `foglamp`, `true-conviction` |
| Docs | `/root/mark/skybox7-platform` (the estate map) and `/root/mark/skybox7/skybox7-infrastructure` (the box) |
| Credentials | Mark's Vaultwarden entries only |
| Tasks | Mark's Nextcloud — **files.skybox7.com** |

**Hard boundaries for this session:**

- Nothing built here deploys to Justin's VPSes (`vps1`–`vps4`). Ever.
- Nothing here gets committed to `thejdubb02`.
- Nothing here writes to **status.willhitestrategy.org**.
- Do not use Justin's Vaultwarden entries, even where they would work.
- If anything of Justin's surfaces — WSG, Dealophant, my-glp-shot, Open Scoring,
  Swaypi, Sam, Sentinel, anything under `/root/platform` or `/root/ventures` — do
  not touch it and do not report on it beyond one line saying it surfaced.

**Confirm the target before touching Kuma.** Do not trust the URL alone — prove it:

```bash
ssh mark "sqlite3 -readonly -cmd '.timeout 5000' \
  /var/lib/docker/volumes/uptime-kuma_uptime-kuma/_data/kuma.db \
  'select name from monitor limit 8;'"
```

Mark's instance lives in the volume `uptime-kuma_uptime-kuma` on the `mark` box
and its monitors include *Duchamp Hotel*, *Komodo (control)*, *Homepage (dashboard)*
— roughly 18 in total. **Justin's** lives in `uptime-kuma-data` on **vps1** and is
reached at `status.willhitestrategy.org`. If you land there, **stop**. If you
cannot positively identify which instance you reached, **stop**. Never continue
against an unconfirmed target.

**The devbox is a workbench only.** No client code, credentials, exports, database
dumps or artifacts should be left sitting on it. Flag anything that is, and clean
it up before the session ends.

===========================================================
SESSION RULES
===========================================================

- **Verify by running things live.** Never report status from docs, comments, or
  memory. If you did not observe it working *this session*, say so in those words.
- **Never delete.** Propose removals and wait for approval. This is a client
  environment — bias hard toward caution.
- **No secrets in files.** Vaultwarden item *names* as pointers only.
- **Update the client's docs in this same session** for any change — do not defer.
  Use the conventions that already exist there rather than creating parallel files:
  - `skybox7-platform/map/platform.yaml` — the estate map. After editing:
    `python3 tools/validate.py && python3 tools/render.py`
  - `skybox7-platform/docs/MONITORING.md` — what is monitored and what a failure
    looks like. Create it if it does not exist.
  - `skybox7-infrastructure/CHANGELOG.md` and `STATE.md` — the box itself.
  - Anything wrong in the *connections* (DNS, certs, email, credentials, two
    services disagreeing) goes in `skybox7-platform/bugs/open/`.
- **Nothing client-facing sends itself.** Any email is drafted from
  `justin@skybox7.com` for Justin's review — never dispatched.
- **Plain English.** Say what a thing does before how it works.

===========================================================
PHASE 1: INVENTORY
===========================================================

List every **skill**, **slash command**, **CLI script**, **MCP server**, and
**scheduled job** in the client environment. For each: what it does in plain
English, when it last ran, where it lives, and whether it has a Kuma monitor.

Where to look, at minimum:

- `skybox7-platform/docs/MAP.md` and `map/platform.yaml` — start here, it is the
  index of ~50 services, sites, agents, jobs and outside providers
- `skybox7-platform/tools/`, `skybox7-infrastructure/` and each app repo's `tools/`
- On the box: `ssh mark` → `systemctl list-timers --all`, `crontab -l`,
  `docker ps -a`, and the Komodo control plane
- GitHub Actions in the **Duchamph** org
- Monitors — the Kuma DB query above

===========================================================
PHASE 2: VERIFY
===========================================================

Exercise each item **for real**. Hit health endpoints. Run scripts with a dry-run
flag where one exists — and say so where none does. Confirm each scheduled job's
**last successful run**. Confirm skill and command files exist, parse, and point at
real paths.

**Prioritise anything client-facing** — site availability, forms, booking flows,
email delivery, and anything Mark's guests or staff touch — **before** internal
convenience tooling.

**Flag anything running but doing the wrong thing.** A backup that completes while
writing somewhere nobody reads is a failure, not a pass. So is a booking form that
returns 200 while the notification email silently bounces.

===========================================================
PHASE 3: FIX
===========================================================

Fix what is broken. **Stop and ask first** before anything that could affect a live
client-facing service during business hours, anything destructive, and anything
needing a credential rotation.

===========================================================
PHASE 4: MONITORING COVERAGE
===========================================================

**Say out loud, before touching it:** "Writing to https://status.skybox7.com —
Mark's Uptime Kuma on the skybox7 box." If the target does not clearly resolve to
Mark's instance, **stop**.

Everything that can fail silently needs a monitor:

- **Services** — HTTP check against a health endpoint that reflects *real* health.
- **Scheduled jobs** — a **push** monitor with a window slightly longer than the
  expected interval, so a job that stops running entirely gets caught.

Add what is missing. Kuma has no usable REST API for creating monitors — do it
through the UI in BrowserOS neo (open your own tab, close it when done). If you
cannot reach it, **output the exact monitor config for Justin to paste in and state
plainly that it is not live yet.** Never report coverage you did not confirm.

**Audit the existing monitors for whether they check something real.** A monitor on
a page that returns 200 regardless is worse than none. Note that
`bugs/open/BUG-0011-hub-login-not-monitored.md` already records one known gap —
check whether it still stands.

**Confirm Mark's Kuma itself is watched from outside**, so his instance going dark
does not go unnoticed. Watching it from Justin's Kuma is the obvious way — that is
a read-only external check and is permitted, but say explicitly that you did it and
that it was the only cross-boundary action.

===========================================================
PHASE 5: BUILD CANDIDATES
===========================================================

Recommend anything worth turning into tooling for this client. Preference order —
**default to nothing**:

1. **Nothing.**
2. **CLI script** — deterministic, should run on a schedule.
3. **Skill** — you can already do it but need the same context repeated.
4. **Slash command** — a prompt Justin keeps retyping.
5. **MCP server** — only if you genuinely cannot reach a system and nothing
   existing covers it.

**Bias lower here than on Justin's own projects.** Every piece of client tooling is
something he has to keep alive, or hand off cleanly if the relationship changes.

For each: what it is in plain English, why that type, build time, maintenance cost,
how it would announce itself if it broke, and **whether it would transfer to Mark
or Skyhawk if the engagement ended**.

**Do not build yet.** Wait for him to pick.

===========================================================
PHASE 6: DEPRECATION CANDIDATES
===========================================================

Propose removal for anything unused 60+ days, superseded, or costing more upkeep
than it returns. For each: what breaks if it goes, and what needs cleanup —
monitors, cron entries, credentials, DNS, docs.

**Flag anything Mark may depend on without Justin knowing.** When in doubt on
client infrastructure, recommend keeping it.

For anything approved: **pause the Kuma monitor rather than deleting it, and archive
rather than delete.**

===========================================================
PHASE 7: REPORT
===========================================================

Open by confirming this covered **client infrastructure only** and naming the Kuma
instance you wrote to. Explicitly confirm that **nothing touched Justin's own
systems** and **nothing was left on the devbox**.

Then, short and plain: what is healthy · what you fixed · what is still broken and
why · what monitors you added · what to build · what to retire.

File anything outstanding as a Nextcloud task on **Mark's** server
(`files.skybox7.com` — `nc_tasks.py`, and never guess the list, ask). Say which
server it landed on, because writes there appear in Mark's audit log as Justin.

Close every BrowserOS neo tab you opened.
