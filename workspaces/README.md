# VS Code workspaces

One multi-root workspace per bucket, plus `justin.code-workspace` which opens the five
own-work buckets together.

## These files are a seed, not the live copy

**Deploy them to `~/dev/workspaces/`.** The folder paths inside are relative (`../platform`,
`../ventures/relay`, and so on) and only resolve correctly from that location. Opening them
from inside this repo gives broken roots, because this repo lives at
`~/dev/platform/claude-kit/`.

```powershell
mkdir -Force "$HOME\dev\workspaces"
Copy-Item "$HOME\dev\platform\claude-kit\workspaces\*.code-workspace" "$HOME\dev\workspaces\"
```

## Regenerating instead of copying

The per-bucket files list **one folder entry per repo**, so they go stale as soon as you clone,
move, or rename anything. Rather than hand-editing, regenerate:

```powershell
& "$HOME\dev\platform\claude-kit\claude-config\scripts\make-workspaces.ps1"
```

That script rewrites everything in `~/dev/workspaces/` from whatever is actually on disk. It is
the source of truth for the layout, colors, and watcher excludes. Re-run it after any bucket
change, then copy the results back here if you want the repo copy current.

## Buckets and colors

| Workspace | Peacock color | Contents |
|---|---|---|
| `platform.code-workspace` | blue `#1857A4` | one root per repo |
| `ventures.code-workspace` | green `#157A3F` | one root per repo |
| `personal.code-workspace` | purple `#6C3FA4` | one root per repo |
| `clients.code-workspace` | teal `#0F6E6E` | one root per repo |
| `unsorted.code-workspace` | slate `#4A5568` | one root per repo |
| `mark.code-workspace` | orange `#C25100` | isolated, populated separately |
| `skyhawk.code-workspace` | red `#B02A2A` | isolated, populated separately |
| `justin.code-workspace` | blue `#1857A4` | the five buckets above, bucket level |

`justin.code-workspace` deliberately excludes `mark` and `skyhawk`. Those are separate isolated
sessions and must not be opened alongside own work. See `SETUP-HANDOFF.md`.

Slate on `unsorted` was chosen as a neutral placeholder, no color was specified for that bucket.

## Empty buckets

`mark` and `skyhawk` have no repos on a fresh machine, so their workspaces point at the bucket
directory itself and are labelled `(empty)`. They start working once something is cloned in and
the generator is re-run.
