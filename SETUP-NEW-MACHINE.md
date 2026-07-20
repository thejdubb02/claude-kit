# Setting up a fresh Windows machine

Clone-and-follow runbook. Work top to bottom. Each phase assumes the previous one finished.

Written 2026-07-20 from a real setup of the work PC. Every "Gotcha" below cost real time on
that machine, so do not skip them.

Two halves to the setup:

- **This repo** is the portable, non-secret half. Zero credentials by design.
- **The memory folder and all secrets** move machine to machine, never through git. Phase 9.

If you only read one thing: `claude-config/RESTORE.md` has the per-file detail. This document
is the ordering and the traps.

---

## Phase 0. Before you start

You need a browser and admin rights on the box. Nothing else is assumed.

> **Gotcha: `winget` does not exist on these machines.**
> Every "just run winget install ..." instruction you find online is dead on arrival here.
> Download each installer manually from the vendor site and run it. Budget time for this.

Downloads you will need, in the order you will need them:

| Tool | Why | Source |
|---|---|---|
| Git for Windows | Nothing clones without it. Phase 1. | https://git-scm.com/download/win |
| Claude Code | The point of the exercise. Phase 2. | https://claude.com/claude-code |
| Bitwarden CLI (`bw.exe`) | Unlocks every other credential. Phase 8. | https://bitwarden.com/help/cli/ |
| Python 3 | The bash-guard hooks are Python. Phase 6. | https://www.python.org/downloads/windows/ |
| jq | Only if you want the statusline. Phase 6. | https://jqlang.github.io/jq/download/ |

> **Gotcha: run `mkdir` and every other shell command in an actual terminal.**
> Pasting a command into the Claude Code chat box does not execute it. It just sends text to the
> model. When this runbook shows a command, open PowerShell or Git Bash and run it there.

---

## Phase 1. Git for Windows, first

Install it before anything else. Nothing in this runbook works without it, because everything
starts with a clone.

Accept the defaults. Confirm:

```powershell
git --version
```

If that errors, restart the terminal and try again before troubleshooting anything else.

---

## Phase 2. Claude Code, and its PATH problem

Install Claude Code.

> **Gotcha: Claude Code does not add itself to PATH on Windows.**
> The installer completes, and `claude` is still not a command. You have to add it yourself.

Find where `claude.exe` actually landed, then append that directory to your **User** PATH:

```powershell
# Substitute the real install directory.
$claudeDir = "$env:LOCALAPPDATA\Programs\claude-code"

$userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
if ($userPath -notlike "*$claudeDir*") {
    [Environment]::SetEnvironmentVariable('PATH', "$userPath;$claudeDir", 'User')
}
```

> **Gotcha: restart VS Code completely. Not just the terminal.**
> A new integrated terminal inherits its environment from the running VS Code process, so it
> keeps the stale PATH. Closing the terminal and opening another one looks like it should work
> and does not. Quit VS Code entirely and relaunch it.

Confirm in a fresh terminal after the restart:

```powershell
claude --version
```

---

## Phase 3. Clone the kit

```powershell
mkdir -Force "$HOME\dev\platform"
cd "$HOME\dev\platform"
git clone --recurse-submodules https://github.com/thejdubb02/claude-kit.git
```

`--recurse-submodules` matters. Without it `vendor/` clones empty and `install.sh` later reports
`skip vendor (no SKILL.md found)`.

> **Gotcha: `RESTORE.md` is in `claude-config/`, not the repo root.**
> It is `claude-kit/claude-config/RESTORE.md`. Looking for it at the top level and concluding it
> is missing wastes a few minutes. Same for `settings.json`, the hooks, and the skills: they all
> live under `claude-config/`, not at the root. Only `vendor/`, `snippets/`, `install.sh`, and
> this file sit at the top level.

---

## Phase 4. PowerShell execution policy

Scripts in this repo are `.ps1` files, and Windows refuses to run them by default.

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
Get-ExecutionPolicy -Scope CurrentUser   # expect: RemoteSigned
```

`RemoteSigned` permits locally authored scripts and still blocks unsigned downloaded ones. That
is the right level. Do this before Phase 8 or the Bitwarden setup script will not run.

> **Gotcha: a scary error here is usually not a failure.**
> If you see `SecurityException` with "the setting is overridden by a policy defined at a more
> specific scope", read it carefully. It means the write succeeded but some *other* scope wins
> for the current effective policy. Check `Get-ExecutionPolicy -List`. A `Process` scope of
> `Bypass` is normal inside tooling that launched PowerShell with `-ExecutionPolicy Bypass`, and
> it does not affect your own terminals.

> **Gotcha: if a `.ps1` still refuses to run**, it may carry mark-of-the-web from being
> downloaded. Clear it with `Unblock-File .\script.ps1`. Scripts you wrote locally do not have
> this.

---

## Phase 5. Restore `settings.json`

Source is `claude-config/settings.json`. Destination is `~\.claude\settings.json`.

There is only **one** `settings.json` in this repo. There is no Windows variant. You are porting
the Linux one and fixing its paths.

### 5a. Scan it for secrets first

This file held plaintext credentials on VPS1 at one point. Before copying, grep for token shapes
(`re_`, `sk-`, `ghp_`, `xox`, `AKIA`, `AIza`, long base64) and for `password=` / `token=` with a
real value after the equals sign. Hits on `<REDACTED>` markers are fine, that is prior scrubbing.
Service names containing "auth" and grep *patterns* like `RESEND_API_KEY` are false positives.

### 5b. Merge, do not overwrite

A fresh Claude Code install writes its own `settings.json` with local preferences such as `theme`
and `tui`. Those keys are **not** in the repo file. A straight copy silently loses them. Read the
existing file first and carry those keys across.

### 5c. Fix the paths

The repo file uses absolute paths that were correct on VPS1. Rewrite them:

| Key | Change |
|---|---|
| `hooks.PreToolUse[].command` | `/usr/bin/python3 /root/.claude/hooks/bash-guard.py` becomes `python C:/Users/<you>/.claude/hooks/bash-guard.py` |
| `hooks.PostToolUse[].command` | same treatment for `bash-guard-learn.py` |
| `permissions.additionalDirectories` | Drop the dead `/root/...` entries. Add your real hooks dir and memory dir. |
| `permissions.allow` | Prune entries referencing `/root`, `/opt`, `/var/www`, `/etc`, or old VPS IPs. RESTORE.md section 5 calls these safe to prune. Keep generic ones such as `Bash(ssh -o *)`, `Bash(bw *)`, git, and docker. |
| `mcpServers.meridian` | SSHes to a VPS. Omit until SSH to that box is set up, then add it back. |

> **Gotcha: the hook scripts hardcode their own log paths internally.**
> RESTORE.md does not mention this. Fixing only `settings.json` is not enough. Open both
> `claude-config/hooks/bash-guard.py` and `bash-guard-learn.py` and rewrite the `/root/.claude/`
> prefixes in `LOG`, `LEARNED`, and the docstrings.

> **Gotcha: dead allowlist entries containing `<REDACTED>`.**
> Entries like `sshpass -p '<REDACTED>' ssh ...` can never match a real command, because the
> password was scrubbed. They are clutter. Prune them.

### 5d. Copy the rest

`claude-config/hooks/`, `claude-config/commands/`, and `claude-config/skills/` go to the matching
directories under `~\.claude\`. `statusline.sh` goes to `~\.claude\statusline.sh`.

> **Gotcha: RESTORE.md tells you to fix "the statusline reference" in `settings.json`. There is
> no `statusLine` key.** The script ships but nothing points at it, and it needs `jq`, which is
> probably not installed. Statusline is inert unless you wire it up deliberately.

---

## Phase 6. Run `install.sh`

```bash
cd ~/dev/platform/claude-kit
bash install.sh
```

It symlinks skills, commands, and hooks into `~/.claude/`.

> **Gotcha: on Windows this is effectively install-once.**
> Git Bash has no native symlink support unless `MSYS=winsymlinks:nativestrict` is set and
> Developer Mode is on. Without that, `ln -s` silently **copies** and reports success. The
> copies do not track the source. Worse, `install.sh` skips any target that is not a symlink, so
> **every later run updates nothing**. After you pull kit changes, either delete the stale items
> under `~\.claude\` and re-run, or copy the changed files across by hand.

> **Gotcha: Python is required for the hooks, and `python3` on a bare Windows box is a fake.**
> `python3.exe` in `WindowsApps` is the Microsoft Store stub. It prints "Python was not found"
> and exits 9009. Install real Python from python.org. Until then the hooks are configured but
> inert, which is harmless.

---

## Phase 7. Git identity

Set it globally or every repo prompts you.

```powershell
git config --global user.name  "Justin Willhite"
git config --global user.email "jdubb@consumerquest.online"
```

Mark and Duchamp and Skybox7 work lives under Mark's GitHub account `duchampmark` and must not
be attributed to the WSG identity. Use a conditional include so it switches automatically by
directory instead of per repo:

```powershell
# ~/.gitconfig-mark
@"
[user]
	name = duchampmark
	email = duchampmark@users.noreply.github.com
"@ | Set-Content "$HOME\.gitconfig-mark"

git config --global --add includeIf."gitdir/i:C:/Users/<you>/dev/mark/".path "$HOME/.gitconfig-mark"
```

Use `gitdir/i:` (case insensitive). Plain `gitdir:` misses drive-letter and casing mismatches on
Windows. Verify by running `git config user.email` inside a repo in each location.

Identity is not authentication. Mark's repos authenticate with Mark's PAT or per-repo ed25519
deploy keys, never with the WSG token. See `project_skybox7_mark.md` in the memory folder.

---

## Phase 8. Bitwarden

### 8a. Put `bw.exe` somewhere sane

> **Gotcha: downloaded CLIs land in `~\Downloads` and are not on PATH.**
> Move `bw.exe` to `~\.local\bin\` and make sure that directory is on your User PATH.

```powershell
mkdir -Force "$HOME\.local\bin"
Move-Item "$HOME\Downloads\bw.exe" "$HOME\.local\bin\bw.exe"

$userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
if ($userPath -notlike "*\.local\bin*") {
    [Environment]::SetEnvironmentVariable('PATH', "$userPath;$HOME\.local\bin", 'User')
}
```

Open a new terminal, then `bw --version` and `bw login`.

### 8b. Persistent unlock

```powershell
& "$HOME\dev\platform\claude-kit\claude-config\scripts\setup-bw-unlock.ps1"
```

> **Gotcha: run this yourself, in a real terminal. Never through Claude Code.**
> It prompts for your master password via `Read-Host -AsSecureString`. Claude Code's tool layer
> runs `-NonInteractive` with stdin on the null device, so the prompt gets EOF, not a password.
> More importantly, anything pasted into chat is written verbatim into the session transcript at
> `~\.claude\projects\<project>\<id>.jsonl` and stays there. A leaked session key can be killed
> with `bw lock`. A leaked master password cannot: it needs a full rotation and vault
> re-encryption. Never paste either one into chat.

The script verifies against the vault before storing anything, writes the password
DPAPI-encrypted to `~\.bw-key`, caches a session key at `~\.bw-session`, and locks both files to
your account. Add the auto-unlock block from `claude-config/scripts/` to your PowerShell profile
so new terminals populate `$env:BW_SESSION`.

> **Gotcha: `bw unlock` invalidates all previous session keys.**
> A naive "unlock on every new terminal" profile block means opening terminal 2 silently breaks
> terminal 1. That is why the setup caches a session key and reuses it while it is still valid.

Verify in a new terminal:

```powershell
bw status    # expect: "status": "unlocked"
```

---

## Phase 9. The memory folder

This is the important one. Roughly 294 fact files: people, projects, standing rules, live state.
`PROJECT_STATE.md` is the source of truth, `MEMORY.md` is the index.

> **It is deliberately excluded from this repo because it is full of live plaintext secrets.
> It is not a git clone. Never commit it, never put it in cloud storage.**

### 9a. Find your project directory name

Claude Code derives it from the working directory. For `C:\Users\JDubb` it is `C--Users-JDubb`.

```powershell
Get-ChildItem "$HOME\.claude\projects"
```

### 9b. Pull it

`rsync` is not installed on Windows and Git for Windows does not bundle it. Use tar over ssh,
which is the native equivalent and supports the same exclude:

```bash
ssh root@187.77.19.181 \
  "tar czf - -C /root/.claude/projects/-root --exclude='__pycache__' memory" \
  | tar xzf - -C "/c/Users/<you>/.claude/projects/<PROJECT-DIR>"
```

> **Gotcha: there are ten `memory` folders on VPS1, not one. Pull `-root` only.**
> `-root/memory` is the 294 file store and the only one with a clean home-directory analog on a
> new machine. The other nine hold about 47 files between them and map to per-project working
> directories that will not exist yet. Leave them until you actually need them.

### 9c. Verify the transfer

Do not trust a file count alone. Compare content hashes:

```bash
# on VPS1
cd /root/.claude/projects/-root/memory && \
  find . -type f ! -path "*__pycache__*" -print0 | sort -z | xargs -0 md5sum | sed 's/ \+\*\?/ /' | sort

# locally, same command in the destination, then diff the two outputs
```

Expect 294 files and an empty diff.

A raw `du -sb` comparison will differ by roughly 19 KB. That is ext4 directory inode overhead on
the source, which NTFS reports as zero. Compare the sum of *file* sizes, not `du`.

### 9d. Lock the folder down

```powershell
$d  = "$HOME\.claude\projects\<PROJECT-DIR>\memory"
$me = ([Security.Principal.WindowsIdentity]::GetCurrent()).Name
icacls $d /inheritance:r /grant:r "${me}:(OI)(CI)(F)"
```

> **Gotcha: do NOT add `/T` to that command. It will lock you out of every file.**
> `(OI)(CI)` are inheritance flags, meaningless on leaf files. Applying them to files with `/T`
> writes a protected ACL with **zero** ACEs on each one: no inheritance and nothing granted.
> Every file becomes unreadable. Set the ACE on the **folder only** and let files inherit.
>
> Recovery if you already did it:
> ```powershell
> icacls $d /reset /T /C          # restores inherited ACLs
> icacls $d /inheritance:r /grant:r "${me}:(OI)(CI)(F)"   # folder only, no /T
> ```

> **Gotcha: Git Bash's `[ -r file ]` test lies about NTFS ACLs.**
> It cheerfully reported all 294 files readable while every actual read returned
> "Permission denied". Verify with a real read, for example `md5sum` or PowerShell
> `Get-Content`, not with `-r`.

---

## Phase 10. MCP servers

Not in this repo, they hold tokens.

- **claude.ai connectors** (GitHub, Gmail, Drive, Calendar, Slack, Stripe, Nextcloud,
  OmniSocials, YouTube Analytics) follow your Claude account and reappear on sign-in. Nextcloud
  and Stripe usually need re-authorizing in claude.ai connector settings. That is an interactive
  browser flow, so it cannot be done from a headless session.
- **Local stdio servers** get recreated in `~\.claude\mcp.json`, pulling each token from
  Bitwarden. See `claude-config/RESTORE.md` section 2 for the list.

---

## Appendix A. Windows shell traps

Hit while automating the setup. They cost real debugging time.

- **Git Bash mangles Windows-style switches into paths.** `icacls "$D" /T` becomes `T:/` and
  errors with `Invalid parameter`. Run such commands from PowerShell, or set
  `MSYS_NO_PATHCONV=1`.
- **PowerShell errors from `-EncodedCommand` come back as CLIXML on stderr.** If you filter
  CLIXML out of the output, you filter out the error text too, and a failed script looks like a
  silent success. This turned one broken ACL repair into two.
- **Double quotes get stripped passing `-Command` strings between shells.** Use
  `-EncodedCommand` with base64 UTF-16LE for anything non-trivial.
- **`whoami` in Git Bash returns the bare username**, not `DOMAIN\user`. `icacls` wants the
  qualified form. Use
  `([Security.Principal.WindowsIdentity]::GetCurrent()).Name`.
- **Git may report a file modified purely from line-ending normalization.** Check
  `git diff --stat` before assuming you changed content, and `git checkout --` to restore.

---

## Appendix B. Known broken or deferred

State as of 2026-07-20 on the work PC. Update as these get resolved.

| Item | Status |
|---|---|
| bash-guard hooks | Configured with correct paths, inert until real Python is installed |
| statusline | Not wired. No `statusLine` key in `settings.json`, and `jq` is missing |
| `install.sh` on Windows | Install-once. Symlinks silently copy. See Phase 6 |
| `meridian` MCP server | Omitted from `settings.json` until SSH to that VPS is configured |
| Other nine memory folders | About 47 files still on VPS1, not pulled |
| Nextcloud and Stripe connectors | Need re-auth in claude.ai connector settings |

---

## Appendix C. Standing rules worth knowing before you write anything

These live in the memory folder and apply to all output, including commit messages and docs.

- **No em dashes. Anywhere.** Emails, code comments, commit messages, UI copy, chat replies.
  Use a comma, a period, a colon, or parentheses. En dashes and hyphens are fine.
  See `feedback_no_em_dashes.md`.
- **Plain URLs in chat, not markdown link syntax.** See `feedback_plain_url_links.md`.
- **No secrets as literal values in files.** They should be `<Bitwarden: name>` pointers. If you
  find a literal, that is a bug: stop and fix it. See `feedback_no_secrets_in_files.md` and
  `RESTORE.md` section 4.
