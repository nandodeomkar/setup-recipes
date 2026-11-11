# =====================================================================
#  Login-Personal-Redirect.ps1
#
#  Refreshes YOUR account's session in the "Claude (Personal)" instance
#  WITHOUT moving, opening, or otherwise touching the main account's profile.
#
#  WHY THIS WORKS
#  Google sign-in is handed to the system browser ("[Auth] Using system
#  browser for: /login/app-google-auth"). The browser returns the session
#  through the claude:// URL handler, which is a plain HKCU entry:
#      HKCU\Software\Classes\claude\shell\open\command
#      = "<install>\app\Claude.exe" "%1"
#  With no --user-data-dir it always resolves to the DEFAULT profile -
#  the main account's - which is the entire reason the old profile-swap dance
#  existed. This script appends --user-data-dir=<Claude-Personal> for the
#  duration of the login, so Electron's single-instance lock forwards the
#  callback into the already-running Personal window instead. Then it
#  puts the handler back exactly as it was.
#
#  Unlike Setup-Personal-Login-v4.ps1, this refreshes the session IN
#  PLACE: your Personal chats, settings and ~9.5 GB VM bundle all survive.
#
#  Run from a normal PowerShell window. Nothing here needs admin.
# =====================================================================
$ErrorActionPreference = 'Stop'

$key      = 'HKCU:\Software\Classes\claude\shell\open\command'
$personal = Join-Path $env:APPDATA 'Claude-Personal'
$stash    = Join-Path $env:LOCALAPPDATA 'ClaudePersonal\claude-handler-original.txt'

$pkg = Get-AppxPackage -Name 'Claude' | Sort-Object Version -Descending | Select-Object -First 1
if (-not $pkg) { Write-Host 'Claude Desktop is not installed.' -ForegroundColor Red; return }
$exe = Join-Path $pkg.InstallLocation 'app\Claude.exe'

if (-not (Test-Path $key)) { Write-Host "No claude:// handler at $key - open Claude Desktop once, then re-run." -ForegroundColor Red; return }
$orig = (Get-ItemProperty $key).'(default)'
if ($orig -notmatch 'Claude\.exe') { Write-Host "Unexpected handler value, aborting:`n  $orig" -ForegroundColor Red; return }
if ($orig -match '--user-data-dir') { Write-Host "Handler is ALREADY redirected - a previous run did not clean up:`n  $orig" -ForegroundColor Yellow }

Set-Content -Path $stash -Value $orig -Encoding utf8
Write-Host ""
Write-Host "Original claude:// handler saved to:" -ForegroundColor DarkGray
Write-Host "  $stash" -ForegroundColor DarkGray
Write-Host "  $orig" -ForegroundColor DarkGray

# The callback must land in a RUNNING Personal instance, so make sure one exists.
$mainPersonal = Get-CimInstance Win32_Process -Filter "Name='claude.exe'" |
    Where-Object { $_.CommandLine -like '*Claude-Personal*' -and $_.CommandLine -notlike '*--type=*' }
if (-not $mainPersonal) {
    Write-Host ""
    Write-Host "Personal instance not running - starting it..." -ForegroundColor Cyan
    Start-Process -FilePath $exe -ArgumentList "--user-data-dir=`"$personal`""
    Start-Sleep -Seconds 10
} else {
    Write-Host ""
    Write-Host "Personal instance is running (PID $($mainPersonal.ProcessId))." -ForegroundColor Green
}

try {
    $new = '"{0}" --user-data-dir="{1}" "%1"' -f $exe, $personal
    Set-ItemProperty -Path $key -Name '(default)' -Value $new
    Write-Host ""
    Write-Host "claude:// now points at the Personal profile." -ForegroundColor Green
    Write-Host ""
    Write-Host "  >>> In the CLAUDE (PERSONAL) window: sign out, then sign in as yourself." -ForegroundColor Yellow
    Write-Host "  >>> Your browser will open. Finish the Google sign-in there." -ForegroundColor Yellow
    Write-Host "  >>> The Personal window should come back logged in as you." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Do NOT open the main account's Claude window until this finishes." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter once the Personal window shows you signed in (or if it failed)"

    $now = (Get-ItemProperty $key).'(default)'
    if ($now -ne $new) {
        Write-Host ""
        Write-Host "NOTE: something rewrote the handler mid-flow (likely a Claude app launch)." -ForegroundColor Yellow
        Write-Host "  found: $now" -ForegroundColor Yellow
        Write-Host "  If the login landed in the wrong profile, restore from your snapshot." -ForegroundColor Yellow
    }
}
finally {
    Set-ItemProperty -Path $key -Name '(default)' -Value $orig
    Write-Host ""
    Write-Host "claude:// handler restored to its original value." -ForegroundColor Green
    Write-Host "  $((Get-ItemProperty $key).'(default)')" -ForegroundColor DarkGray
}

# ---- verdict straight from the Personal instance's own log ----
$log = Join-Path $env:LOCALAPPDATA 'Claude-Personal\logs\main.log'
Write-Host ""
if (Test-Path $log) {
    $tail  = Get-Content $log -Tail 400 -ErrorAction SilentlyContinue
    $stale = $tail | Select-String 'session_stale_relogin' | Select-Object -Last 1
    $good  = $tail | Select-String 'Login-state transition|using cached token|fresh /authorize' | Select-Object -Last 3
    if ($good)  { Write-Host "Recent auth activity in the Personal profile:" -ForegroundColor Cyan; $good | ForEach-Object { Write-Host "  $_" } }
    if ($stale) { Write-Host "STILL SEEING session_stale_relogin - the refresh did not take:" -ForegroundColor Red; Write-Host "  $stale" }
    else        { Write-Host "No session_stale_relogin in the recent log - looks good." -ForegroundColor Green }
} else { Write-Host "Personal log not found at $log" -ForegroundColor DarkGray }
Write-Host ""
Write-Host "Final check: open a Claude Code session in the Personal window. If it starts, you're done." -ForegroundColor Cyan
