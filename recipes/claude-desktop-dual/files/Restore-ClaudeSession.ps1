# =====================================================================
#  Restore-ClaudeSession.ps1
#  Puts a profile's login state back from a Backup-ClaudeSessions.ps1
#  snapshot. Only touches session files - chats, settings, VM bundles
#  and caches in the live profile are left alone.
#    -Snapshot  timestamp folder name, e.g. 20260821-193000
#    -ProfileName   Claude   (the default/main app)   or   Claude-Personal
#  CLOSE BOTH Claude windows before running.
# =====================================================================
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Snapshot,
    [Parameter(Mandatory)][ValidateSet("Claude","Claude-Personal")][string]$ProfileName
)
$ErrorActionPreference = 'Stop'
$src = Join-Path $env:LOCALAPPDATA "ClaudePersonal\session-backups\$Snapshot\$ProfileName"
$dst = Join-Path $env:APPDATA $ProfileName
if (-not (Test-Path $src)) { throw "No snapshot at $src" }

# A snapshot taken while Claude was running silently lacks Network\Cookies (the
# file holding the claude.ai sessionKey). Restoring from one would not bring the
# login back - and previously, with /PURGE below, it would have DELETED the live
# cookie DB. Refuse outright.
if (-not (Test-Path (Join-Path $src 'Network\Cookies'))) {
    Write-Host "ABORTED - snapshot '$Snapshot' has no Network\Cookies for $ProfileName." -ForegroundColor Red
    Write-Host "  It was taken while Claude was running, so it cannot restore a login." -ForegroundColor Red
    Write-Host "  Use a snapshot captured with both Claude windows closed." -ForegroundColor Red
    return
}

$live = Get-Process claude -ErrorAction SilentlyContinue | Where-Object { $_.Path -like '*WindowsApps*' }
if ($live) {
    Write-Host "ABORTED - Claude Desktop is still running (PIDs: $($live.Id -join ', ')). Close both windows first." -ForegroundColor Red
    return
}

Write-Host "Restoring $ProfileName login state from $Snapshot ..." -ForegroundColor Cyan
foreach ($i in @('config.json','Local State','ant-did','ant-device-registry.json','buddy-tokens.json')) {
    $f = Join-Path $src $i
    if (Test-Path $f) { Copy-Item $f -Destination $dst -Force; Write-Host "  restored $i" }
}
foreach ($d in @('Network','Local Storage','Session Storage','Partitions')) {
    $f = Join-Path $src $d
    # No /PURGE: overwrite what the snapshot has, never delete what it lacks.
    if (Test-Path $f) { & robocopy $f (Join-Path $dst $d) /E /R:0 /W:0 /XJ /NFL /NDL /NP /NS /NC /NJH /NJS | Out-Null; Write-Host "  restored $d\" }
}
Write-Host "Done. Reopen Claude and confirm the account is back." -ForegroundColor Green
