#requires -Version 5.1
<#
.SYNOPSIS
    One-time setup for persistent Bitwarden unlock on Windows.

.DESCRIPTION
    Reads your Bitwarden master password interactively, verifies it against the
    vault, then stores it DPAPI-encrypted at ~/.bw-key and locks the file to your
    Windows account.

    The password is held only in a SecureString and, briefly, in a process-scoped
    environment variable that is removed in a finally block. It is never echoed,
    never written in plaintext, and never passed as a command-line argument
    (argv is visible to other processes; --passwordenv is not).

    MUST be run in a real interactive console. Read-Host cannot work in a
    non-interactive host.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$keyFile  = Join-Path $HOME '.bw-key'
$sessFile = Join-Path $HOME '.bw-session'
$me       = ([Security.Principal.WindowsIdentity]::GetCurrent()).Name

$bw = Get-Command bw -ErrorAction SilentlyContinue
if (-not $bw) { throw "bw CLI not found on PATH. Install it or add its directory to PATH." }

# Refuse to run without a real console, rather than silently capturing an empty password.
if ($Host.UI.RawUI -eq $null -or [Console]::IsInputRedirected) {
    throw "This script requires an interactive console (stdin is redirected). Run it directly in PowerShell."
}

$status = & $bw.Source status --raw 2>$null | ConvertFrom-Json
Write-Host ""
Write-Host "Bitwarden persistent unlock setup" -ForegroundColor Cyan
Write-Host "  vault : $($status.serverUrl)"
Write-Host "  user  : $($status.userEmail)"
Write-Host "  state : $($status.status)"
Write-Host ""
Write-Host "Your master password will be read into a SecureString." -ForegroundColor DarkGray
Write-Host "It is never echoed, never stored in plaintext, never placed on a command line." -ForegroundColor DarkGray
Write-Host ""

$sec = Read-Host -AsSecureString 'Master password'
if (-not $sec -or $sec.Length -eq 0) { throw "No password entered; nothing was written." }

# --- Verify BEFORE storing, so we never persist a wrong password --------------
Write-Host ""
Write-Host "Verifying against vault ... " -NoNewline
$session = $null
try {
    $env:BW_MASTERPW = [Net.NetworkCredential]::new('', $sec).Password
    $session = & $bw.Source unlock --passwordenv BW_MASTERPW --raw 2>$null
} finally {
    Remove-Item Env:\BW_MASTERPW -ErrorAction SilentlyContinue
}

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($session)) {
    Write-Host "FAILED" -ForegroundColor Red
    throw "Vault rejected that password (or the server is unreachable). Nothing was written."
}
Write-Host "OK" -ForegroundColor Green

# --- Store the master password, DPAPI-encrypted to this user + this machine ---
# ConvertFrom-SecureString with no -Key uses DPAPI, CurrentUser scope.
# The ciphertext is undecryptable by any other account, even a local admin.
ConvertFrom-SecureString -SecureString $sec |
    Set-Content -Path $keyFile -Encoding ascii -NoNewline

# --- Cache the session key the same way, so new terminals don't re-unlock -----
ConvertFrom-SecureString -SecureString (ConvertTo-SecureString $session -AsPlainText -Force) |
    Set-Content -Path $sessFile -Encoding ascii -NoNewline

# --- Lock both files to this user only ----------------------------------------
foreach ($f in @($keyFile, $sessFile)) {
    & icacls $f /inheritance:r /grant:r "${me}:(R,W)" | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Warning "icacls failed to harden $f - check its permissions manually." }
}

$env:BW_SESSION = $session

Write-Host ""
Write-Host "Stored:" -ForegroundColor Green
Write-Host "  $keyFile   (DPAPI, $me only)"
Write-Host "  $sessFile  (DPAPI, $me only)"
Write-Host ""
Write-Host "Verifying end to end ..." -ForegroundColor Cyan
& $bw.Source status --raw | ConvertFrom-Json | Select-Object serverUrl, userEmail, status | Format-List
Write-Host "Open a NEW terminal and run 'bw status' - it should report unlocked." -ForegroundColor Cyan
Write-Host ""
