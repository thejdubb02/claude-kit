$ErrorActionPreference = 'Stop'

$dev = 'C:\Users\JDubb\dev'
$out = "$dev\workspaces"
New-Item -ItemType Directory -Force -Path $out | Out-Null

$colors = @{
    platform = '#1857A4'; ventures = '#157A3F'; personal = '#6C3FA4'
    clients  = '#0F6E6E'; mark     = '#C25100'; skyhawk  = '#B02A2A'
    unsorted = '#4A5568'
}

# ---------------------------------------------------------------------------
# ISOLATED BUCKETS. Do not remove, do not make configurable.
#
# Mark/Duchamp/Skybox7 and Skyhawk are separate isolated sessions. Their repo
# names are client information and must never be enumerated into a workspace
# file, because those files get committed to claude-kit as a seed.
#
# This is hardcoded rather than passed in, because the failure is silent: the
# generator reads whatever happens to be on disk, so if an isolated session has
# repos checked out while this runs, their names land in a commit. That already
# happened once, on 2026-07-20.
#
# These buckets always emit a single bucket-level folder entry. An assertion at
# the end of this script enforces it and throws if it is ever violated.
# ---------------------------------------------------------------------------
$IsolatedBuckets = @('mark', 'skyhawk')

function New-Peacock([string]$hex) {
    [ordered]@{
        'peacock.color'                 = $hex
        'workbench.colorCustomizations' = [ordered]@{
            'activityBar.background'         = $hex
            'activityBar.foreground'         = '#e7e7e7'
            'activityBar.inactiveForeground' = '#e7e7e799'
            'activityBarBadge.background'    = '#e7e7e7'
            'activityBarBadge.foreground'    = $hex
            'statusBar.background'           = $hex
            'statusBar.foreground'           = '#e7e7e7'
            'titleBar.activeBackground'      = $hex
            'titleBar.activeForeground'      = '#e7e7e7'
            'titleBar.inactiveBackground'    = "${hex}99"
            'titleBar.inactiveForeground'    = '#e7e7e799'
        }
    }
}

$watcherExclude = [ordered]@{
    '**/node_modules/**' = $true; '**/venv/**' = $true; '**/.venv/**' = $true
    '**/dist/**' = $true; '**/data/**' = $true; '**/.git/**' = $true
}

# Per-bucket workspaces: one folder entry per cloned repo, so each repo is its
# own VS Code root with independent git integration.
foreach ($b in @('platform','ventures','personal','clients','unsorted','mark','skyhawk')) {

    if ($IsolatedBuckets -contains $b) {
        # Isolated: never look at the directory at all. Not "enumerate then
        # discard", because that risks a future edit keeping the enumeration.
        $folders = @( [ordered]@{ path = "../$b"; name = "$b (isolated)" } )
        $note    = 'ISOLATED, contents not enumerated'
    }
    else {
        $bucketPath = Join-Path $dev $b
        $repos = @()
        if (Test-Path $bucketPath) {
            $repos = Get-ChildItem $bucketPath -Directory | Sort-Object Name
        }

        $folders = @()
        foreach ($r in $repos) { $folders += [ordered]@{ path = "../$b/$($r.Name)"; name = $r.Name } }
        # If a bucket is empty, fall back to the bucket dir so the workspace still opens.
        if ($folders.Count -eq 0) { $folders = @( [ordered]@{ path = "../$b"; name = "$b (empty)" } ) }
        $note = ''
    }

    $settings = New-Peacock $colors[$b]
    $settings['window.title']         = "$($b.ToUpper()): `${activeEditorShort}"
    $settings['files.watcherExclude'] = $watcherExclude

    $ws = [ordered]@{ folders = $folders; settings = $settings }
    $p = "$out\$b.code-workspace"
    $ws | ConvertTo-Json -Depth 12 | Set-Content -Path $p -Encoding utf8
    "{0,-28} {1} folder(s)  {2}" -f "$b.code-workspace", $folders.Count, $note
}

# Combined workspace stays at bucket level: the five own-work buckets, not mark/skyhawk.
$cs = New-Peacock '#1857A4'
$cs['window.title']         = 'JUSTIN: ${activeEditorShort}'
$cs['files.watcherExclude'] = $watcherExclude

$combined = [ordered]@{
    folders = @(
        [ordered]@{ path = '../platform'; name = 'platform' }
        [ordered]@{ path = '../ventures'; name = 'ventures' }
        [ordered]@{ path = '../personal'; name = 'personal' }
        [ordered]@{ path = '../clients';  name = 'clients'  }
        [ordered]@{ path = '../unsorted'; name = 'unsorted' }
    )
    settings = $cs
}
$combined | ConvertTo-Json -Depth 12 | Set-Content -Path "$out\justin.code-workspace" -Encoding utf8
"{0,-28} {1} folder(s)" -f 'justin.code-workspace', $combined.folders.Count

# ---------------------------------------------------------------------------
# Post-write assertion. Reads back what was actually written, rather than
# trusting the in-memory objects, so a future refactor cannot quietly bypass it.
# Throws instead of warning: a silent leak into a committed file is the whole
# failure mode being guarded against.
# ---------------------------------------------------------------------------
$violations = @()

foreach ($b in $IsolatedBuckets) {
    $p = "$out\$b.code-workspace"
    if (-not (Test-Path $p)) { continue }
    $w = Get-Content $p -Raw | ConvertFrom-Json
    foreach ($f in $w.folders) {
        # Anything deeper than ../<bucket> means a repo name was enumerated.
        if ($f.path -ne "../$b") {
            $violations += "$b.code-workspace exposes '$($f.path)'"
        }
    }
}

# justin.code-workspace must never reference an isolated bucket at all.
$jp = "$out\justin.code-workspace"
if (Test-Path $jp) {
    $jw = Get-Content $jp -Raw | ConvertFrom-Json
    foreach ($f in $jw.folders) {
        foreach ($b in $IsolatedBuckets) {
            if ($f.path -match "(^|/)$b(/|$)") {
                $violations += "justin.code-workspace references isolated bucket '$b' via '$($f.path)'"
            }
        }
    }
}

if ($violations.Count -gt 0) {
    $violations | ForEach-Object { Write-Host "ISOLATION VIOLATION: $_" -ForegroundColor Red }
    throw "Isolation assertion failed. Isolated buckets ($($IsolatedBuckets -join ', ')) must emit a single bucket-level entry and must not appear in the combined workspace. Do not commit these files."
}

Write-Host ""
Write-Host "Isolation assertion passed: $($IsolatedBuckets -join ', ') emit bucket-level entries only." -ForegroundColor Green
