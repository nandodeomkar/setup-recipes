# =====================================================================
#  Setup-Personal-Login.ps1   (v4 - location-agnostic)
#  Re-logs YOUR Claude account into the second native instance,
#  "Claude (Personal)", when its session expires.
#  The main account's account in the main app is never logged out.
#
#  WHAT CHANGED FROM v3 (verified 2026-07-17, app v1.21459.1.0):
#   * v3 assumed the new session ALWAYS lands in the MSIX container
#     (%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\
#     Claude). That folder no longer exists, and claude:// is now a plain
#     HKCU handler invoking Claude.exe directly (no package activation),
#     so the session now lands in %APPDATA%\Claude instead.
#   * v3's restore guard (-not (Test-Path $main)) would therefore SKIP
#     restoring the main account's profile, orphaning it in a backup folder.
#     v4 finds the session in EITHER location and always restores it.
#
#  Run this from a STANDALONE PowerShell window (Win+R -> powershell),
#  never from a terminal hosted inside Claude Desktop: the Claude Code
#  CLI lives under %APPDATA%\Claude and locks the profile being moved.
# =====================================================================
$ErrorActionPreference = 'Stop'
$ts        = Get-Date -Format 'yyyyMMdd-HHmmss'
$startTime = Get-Date
$roaming   = $env:APPDATA
$main      = Join-Path $roaming 'Claude'
$personal  = Join-Path $roaming 'Claude-Personal'
$backup    = Join-Path $roaming "Claude.main-backup-$ts"
$pfn       = 'Claude_pzs8sxrjxfjjc!Claude'
$container = Join-Path $env:LOCALAPPDATA 'Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude'
$pkg       = Get-AppxPackage -Name 'Claude' | Sort-Object Version -Descending | Select-Object -First 1
if (-not $pkg) { Write-Host 'Claude Desktop not found.' -ForegroundColor Red; return }
$exe       = Join-Path $pkg.InstallLocation 'app\Claude.exe'
$skipDirs  = @('ChromeNativeHost','Cache','Code Cache','GPUCache','DawnGraphiteCache','DawnWebGPUCache','Service Worker','blob_storage','Shared Dictionary','Crashpad','sentry','Partitions','VideoDecodeStats')

function Stop-Lockers {
    Get-Process Claude -ErrorAction SilentlyContinue | Where-Object { $_.Path -like '*WindowsApps*' } | Stop-Process -Force -ErrorAction SilentlyContinue
    Get-Process chrome-native-host -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 400
}
function Move-Atomic($src, $dst) {
    Get-Process chrome-native-host -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 200
    [System.IO.Directory]::Move($src, $dst)
}

# Guard: a Claude Code CLI running from inside the profile will block the move.
# Do NOT kill it silently - the user may be mid-session in it.
$cliInProfile = Get-Process claude -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$main\*" }
if ($cliInProfile) {
    Write-Host "ABORTED - a Claude Code CLI is running from inside the profile:" -ForegroundColor Red
    $cliInProfile | ForEach-Object { Write-Host "    PID $($_.Id)  $($_.Path)" }
    Write-Host "Close that Claude Desktop session (and any terminal it hosts), then re-run." -ForegroundColor Red
    return
}

# Recovery from an interrupted previous run
$strays = Get-ChildItem $roaming -Directory -Filter 'Claude.main-backup-*' -ErrorAction SilentlyContinue
if ($strays -and -not (Test-Path $main)) {
    [System.IO.Directory]::Move(($strays | Sort-Object Name -Descending | Select-Object -First 1).FullName, $main)
    Write-Host "Recovered the main account's profile from an interrupted previous run." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Re-log YOUR account into the second native Claude app ===" -ForegroundColor Cyan
Write-Host "The main account's profile is moved aside and automatically restored. It is NOT logged out."
Write-Host ""
Write-Host "Please CLOSE both Claude windows (including the tray icon) AND your browser(s) first." -ForegroundColor Yellow
Read-Host "Press Enter when everything above is closed"
Stop-Lockers

# Pre-flight: prove the profile is movable, else abort with nothing changed
Write-Host "Checking the profile isn't locked..."
$probe = "$main.__movecheck-$ts"
try { Move-Atomic $main $probe; Move-Atomic $probe $main; Write-Host "Lock check passed." -ForegroundColor Green }
catch {
    if (Test-Path $probe) { try { [System.IO.Directory]::Move($probe, $main) } catch {} }
    Write-Host "ABORTED - profile still in use, nothing changed. Close Claude + ALL browsers and re-run." -ForegroundColor Red
    Write-Host $_.Exception.Message; return
}

try {
    Move-Atomic $main $backup                                                   # 1) main aside
    if (Test-Path $container) { Move-Atomic $container "$container.prev-$ts" }  # 2) clear container -> fresh login screen

    Start-Process "shell:AppsFolder\$pfn"                                       # 3) login screen
    Write-Host ""
    Write-Host ">>> A FRESH login window is opening. Sign in as YOURSELF, wait until logged in." -ForegroundColor Yellow
    Read-Host "Press Enter ONLY after you are logged in as yourself"

    Stop-Lockers                                                                # 4) release files

    # 5) Find where this build actually wrote the session: container (old
    #    behaviour) or %APPDATA%\Claude (v1.21459+). Require it to be FRESH.
    $src = $null
    foreach ($cand in @($container, $main)) {
        $ls = Join-Path $cand 'Local State'
        if ((Test-Path $ls) -and ((Get-Item $ls).LastWriteTime -gt $startTime)) { $src = $cand; break }
    }
    if (-not $src) {
        throw "Couldn't find a freshly-written session in either '$container' or '$main' - did the login complete?"
    }
    Write-Host "Found your new session in: $src" -ForegroundColor Green

    if (Test-Path $personal) { Move-Atomic $personal "$personal.old-$ts" }
    $rcArgs = @($src, $personal, '/E','/R:0','/W:0','/XJ','/NFL','/NDL','/NP','/NS','/NC','/XD') + $skipDirs
    & robocopy @rcArgs | Out-Null                                               # 6) copy session into personal profile
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE" }

    Move-Atomic $src "$src.mylogin-bak-$ts"                                     # 7) clear your login out of the shared slot
}
finally {
    # 8) ALWAYS restore main. If your login is still sitting in its slot
    #    (thrown/aborted before step 7), park it aside first - never delete it.
    if (Test-Path $backup) {
        if (Test-Path $main) {
            try { Move-Atomic $main "$main.mylogin-stray-$ts" }
            catch { Write-Host "WARNING: couldn't park stray profile at $main - resolve manually." -ForegroundColor Red }
        }
        if (-not (Test-Path $main)) {
            try { [System.IO.Directory]::Move($backup, $main); Write-Host "Main account's profile restored." -ForegroundColor Green }
            catch { Write-Host "WARNING: couldn't auto-restore main account's profile from $backup - close everything and re-run; it self-recovers." -ForegroundColor Red }
        }
    }
}

Start-Process "shell:AppsFolder\$pfn"                                           # main account
Start-Process -FilePath $exe -ArgumentList "--user-data-dir=`"$personal`""      # second account
Write-Host ""
Write-Host "Done. Main tile = the main account; 'Claude (Personal)' shortcut = you." -ForegroundColor Green
Write-Host "If the personal window shows you logged in, you're set."
Write-Host "Rollback if anything looks wrong: your old personal profile is at" -ForegroundColor DarkGray
Write-Host "  $personal.old-$ts" -ForegroundColor DarkGray
