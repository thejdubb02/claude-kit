$ErrorActionPreference = 'Stop'

$dev = 'C:\Users\JDubb\dev'
$out = "$dev\workspaces"
New-Item -ItemType Directory -Force -Path $out | Out-Null

$colors = @{
    platform = '#1857A4'; ventures = '#157A3F'; personal = '#6C3FA4'
    clients  = '#0F6E6E'; mark     = '#C25100'; skyhawk  = '#B02A2A'
    unsorted = '#4A5568'
}

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
    $bucketPath = Join-Path $dev $b
    $repos = @()
    if (Test-Path $bucketPath) {
        $repos = Get-ChildItem $bucketPath -Directory | Sort-Object Name
    }

    $folders = @()
    foreach ($r in $repos) { $folders += [ordered]@{ path = "../$b/$($r.Name)"; name = $r.Name } }
    # If a bucket is empty, fall back to the bucket dir so the workspace still opens.
    if ($folders.Count -eq 0) { $folders = @( [ordered]@{ path = "../$b"; name = "$b (empty)" } ) }

    $settings = New-Peacock $colors[$b]
    $settings['window.title']         = "$($b.ToUpper()): `${activeEditorShort}"
    $settings['files.watcherExclude'] = $watcherExclude

    $ws = [ordered]@{ folders = $folders; settings = $settings }
    $p = "$out\$b.code-workspace"
    $ws | ConvertTo-Json -Depth 12 | Set-Content -Path $p -Encoding utf8
    "{0,-28} {1} folder(s)" -f "$b.code-workspace", $folders.Count
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
