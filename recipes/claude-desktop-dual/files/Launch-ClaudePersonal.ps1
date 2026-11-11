# Launches a second, independent Claude Desktop instance with its own profile
# (separate login) so a different account can be used alongside the main app.
# The install path is resolved at runtime so this keeps working after updates.
$ErrorActionPreference = 'Stop'

$pkg = Get-AppxPackage -Name 'Claude' | Sort-Object Version -Descending | Select-Object -First 1
if (-not $pkg) {
    (New-Object -ComObject WScript.Shell).Popup('Claude Desktop is not installed.', 0, 'Claude (Personal)', 16) | Out-Null
    exit 1
}

$exe = Join-Path $pkg.InstallLocation 'app\Claude.exe'
$profileDir = Join-Path $env:APPDATA 'Claude-Personal'
New-Item -ItemType Directory -Force -Path $profileDir | Out-Null

Start-Process -FilePath $exe -ArgumentList "--user-data-dir=`"$profileDir`""
