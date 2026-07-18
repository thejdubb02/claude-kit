# Restoring Justin's Claude Code setup on a fresh machine

This folder (`claude-config/`) is the **portable, non-secret** half of the setup. It contains
zero credentials by design. The other half — the memory folder and all actual secrets — is
transferred separately (see the last two sections). Follow this top to bottom.

Throughout, `~/.claude/` is Claude Code's config directory in your home folder. On this old
server that was `/root/.claude/`; on your PC it's under your own home directory. **Wherever a
file below contains an absolute path like `/root/.claude/...`, edit it to match the new
machine's home directory** (details in "Paths to fix" at the bottom).

---

## 1. Where each file goes

| From this repo | Copy to | Notes |
|---|---|---|
| `claude-config/settings.json` | `~/.claude/settings.json` | Your main config. **Redacted** — two stale allowlist entries that held secrets were scrubbed; harmless, they were one-off commands. |
| `claude-config/hooks/bash-guard.py` | `~/.claude/hooks/bash-guard.py` | The command-approval guard that keeps permission prompts sane. |
| `claude-config/hooks/bash-guard-learn.py` | `~/.claude/hooks/bash-guard-learn.py` | Its companion (learns which commands are safe). |
| `claude-config/statusline.sh` | `~/.claude/statusline.sh` | Then `chmod +x`. Needs `jq` installed. |
| `claude-config/commands/` (8 files) | `~/.claude/commands/` | Custom slash commands. |
| `claude-config/skills/` | `~/.claude/skills/` | Custom skills. |

After copying, the hooks and statusline only work if `settings.json` points at them with the
**correct absolute paths for the new machine** — see "Paths to fix."

---

## 2. MCP servers — recreate, don't copy

MCP config is **not** in this repo (it holds tokens). Two kinds:

- **claude.ai connectors** (GitHub, Gmail, Google Drive/Calendar, Slack, Stripe, Nextcloud,
  OmniSocials, YouTube Analytics, etc.) — these follow your Claude account. They reappear when
  you sign in. A few (Nextcloud, Stripe) will need re-authorizing in claude.ai connector
  settings.
- **Local stdio servers** — recreate `~/.claude/mcp.json` with these, pulling each token from
  Bitwarden:
  - `hostinger-mcp` — `npx hostinger-api-mcp` — token: `<Bitwarden: Hostinger API — main>`
  - `hostinger-wsg-com` — `npx hostinger-api-mcp` — token: `<Bitwarden: Hostinger API — wsg.com>`
  - `context7` — `npx @upstash/context7-mcp` — no token
  - `bitwarden` — `npx @bitwarden/mcp-server` — uses your Bitwarden CLI session
  - `omnisocials` — `npx @omnisocials/mcp-server` — token: `<Bitwarden: OmniSocials API>`
  - `meridian` (defined in settings.json) — SSHes to VPS2; only works with SSH access to that box.
  - `winchrome` / `winchrome-work` — point at the browser bridge on your Windows PC (Tailscale IPs); only reachable when that PC is up.

---

## 3. The memory folder — transferred directly, NOT through git

**This is the important one.** `~/.claude/projects/-root/memory/` on the old server holds
~150 fact-files (people, projects, standing rules, live state). It is **deliberately excluded
from this repo** because it is full of live plaintext secrets. Move it machine-to-machine:

```bash
# From the NEW machine, pull it straight off the old server over SSH:
rsync -av --exclude='__pycache__' \
  root@187.77.19.181:/root/.claude/projects/-root/memory/ \
  ~/.claude/projects/<your-project-dir>/memory/
```

(or make one encrypted archive on the old box, carry it over, and unpack — never upload it to
GitHub or any cloud share). `PROJECT_STATE.md` inside it is the living source of truth; read
it first every session. `MEMORY.md` is the index.

---

## 4. Credential index — what you'll need from Bitwarden (names only, no values)

Everything the memory files reference by pointer. Pull these from Bitwarden (**WSG collection**
unless noted) as you need them on the new machine. This is your checklist:

**Email / mailboxes (Hostinger, willhitestrategy.org):**
- WSG mailbox password — outreach@ / hello@ / claude@ (shared)
- WSG mailbox password — creators@ / connect@ / team@ (shared)
- Hostinger IMAP/SMTP settings (same passwords)

**App & dashboard logins:**
- WSG Memory app login (justin)
- wsg-cp admin panel login (admin)
- Dealophant admin login
- Umami analytics admin login
- WSG EXIF Remover login (justin)
- Uptime Kuma login (wsg-admin)
- NocoDB signin
- RackNerd IPTV admin login
- Trading-bot admin login (justin) + viewer login (Matt)
- Keila newsletter admin login
- OpnForm admin login

**Databases:**
- Dealophant prod Postgres password
- Listmonk DB password

**API keys / tokens / secrets:**
- Cloudflare API token (DNS management)
- Resend API key (WSG email sender)
- Stripe webhook signing secret
- BookStack API token
- Vexa admin API token
- LinkedIn Developer App client secret (Postiz app)
- Twilio Account SID + Auth Token (Sam SMS)
- Telegram alert bot token
- Google OAuth token for Gmail/Calendar/Drive (the `token.pickle` + `credentials.json` files)

**Media stack — Bitwarden entry "Media Stack — Master Reference":**
- Whatbox SSH password (falcon.whatbox.ca)
- Sonarr API key
- Radarr API key

**Bitwarden itself:**
- Bitwarden CLI account + unlock (bootstrap: everything else comes from here)

> If you ever find one of these written as a literal value in a file, that's a bug — it should
> be a `<Bitwarden: name>` pointer. Stop and fix it. (Standing rule.)

---

## 5. Paths to fix after copying

`settings.json` and the hooks use **absolute paths that were correct on the old server**
(`/root/.claude/...`). On the new machine, search-and-replace `/root/.claude/` with your
actual `~/.claude/` path in:
- `settings.json` → the two `hooks` command paths (`.../hooks/bash-guard.py` and
  `bash-guard-learn.py`) and the statusline reference.
- Anything in the allowlist referencing `/root/...` is a stale one-off; safe to prune.

Also install prerequisites the setup assumes: `jq` (statusline), `python3` (hooks),
`node`/`npx` (MCP servers), and the Bitwarden CLI (`bw`).

---

*Nothing in this folder contains a secret. The memory folder and all credentials are handled
out-of-band per sections 3 and 4.*
