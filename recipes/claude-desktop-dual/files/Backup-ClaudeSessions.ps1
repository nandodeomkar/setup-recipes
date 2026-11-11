# =====================================================================
#  Backup-ClaudeSessions.ps1
#  Snapshots the login state of BOTH Claude Desktop profiles so any
#  re-login attempt is instantly reversible. Copies only session-bearing
#  files (~100 MB), NOT the ~10 GB VM bundles or caches.
#  Safe to run with the apps open, but a copy taken while they are
#  CLOSED is cleaner (cookie DBs are not mid-write).
# =====================================================================
$ErrorActionPreference = 'Stop'
$ts   = Get-Date -Format 'yyyyMMdd-HHmmss'
$root = Join-Path $env:LOCALAPPDATA "ClaudePersonal\session-backups\$ts"

$script:incomplete = @()
$items = @('config.json','Local State','ant-did','ant-device-registry.json','buddy-tokens.json')
$dirs  = @('Network','Local Storage','Session Storage','Partitions')

foreach ($p in @('Claude','Claude-Personal')) {
    $src = Join-Path $env:APPDATA $p
    if (-not (Test-Path $src)) { Write-Host "SKIP $p (not present)" -ForegroundColor DarkGray; continue }
    $dst = Join-Path $root $p
    New-Item -ItemType Directory -Force -Path $dst | Out-Null
    foreach ($i in $items) {
        $f = Join-Path $src $i
        if (Test-Path $f) { Copy-Item $f -Destination $dst -Force -ErrorAction SilentlyContinue }
    }
    foreach ($d in $dirs) {
        $f = Join-Path $src $d
        if (Test-Path $f) { & robocopy $f (Join-Path $dst $d) /E /R:0 /W:0 /XJ /NFL /NDL /NP /NS /NC /NJH /NJS | Out-Null }
    }
    # The claude.ai sessionKey lives in Network\Cookies. Chromium holds that file
    # open exclusively while Claude runs, so a live copy silently omits it - which
    # would make this snapshot look fine but be unrestorable. Check explicitly.
    if (-not (Test-Path (Join-Path $dst 'Network\Cookies'))) {
        $script:incomplete += $p
        Write-Host ("  !! Cookies DB was LOCKED for {0} - not captured" -f $p) -ForegroundColor Red
    }
    $mb = [math]::Round(((Get-ChildItem $dst -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum)/1MB,1)
    Write-Host ("Backed up {0,-16} -> {1}  ({2} MB)" -f $p, $dst, $mb) -ForegroundColor Green
}

Write-Host ""
Write-Host "Snapshot written to: $root" -ForegroundColor Cyan
Write-Host "To roll a profile back, CLOSE both Claude windows, then run:" -ForegroundColor DarkGray
Write-Host "  & '$PSScriptRoot\Restore-ClaudeSession.ps1' -Snapshot '$ts' -ProfileName Claude" -ForegroundColor DarkGray

if ($script:incomplete.Count) {
    Write-Host ""
    Write-Host "INCOMPLETE SNAPSHOT" -ForegroundColor Red
    Write-Host "  The Cookies database could not be copied for: $($script:incomplete -join ', ')" -ForegroundColor Red
    Write-Host "  Chromium holds it open exclusively while Claude is running, and that file" -ForegroundColor Red
    Write-Host "  holds the claude.ai sessionKey - i.e. the actual login." -ForegroundColor Red
    Write-Host "  CLOSE BOTH Claude windows (tray included) and run this script again for a" -ForegroundColor Red
    Write-Host "  snapshot you can actually restore from." -ForegroundColor Red
} else {
    Write-Host ""
    Write-Host "Complete - Cookies DB captured for every profile. This snapshot is restorable." -ForegroundColor Green
}
