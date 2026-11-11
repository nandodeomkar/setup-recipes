---
name: claude-desktop-dual
captured_on: 2026-11-11
captured_from: Windows 11 Home (10.0.26300)
app_version: Claude Desktop 5.1231.0 (Windows app package, family name Claude_pzs8sxrjxfjjc)
source: https://claude.ai/download   # official installer; the app updates itself
needs:
  - Two Claude accounts
  - Windows PowerShell 5.1 (built into Windows)
  - About 11 GB of free disk space per profile
secrets:
  - None stored. Each account is signed in by hand, in a browser.
state_not_in_recipe:
  - "%APPDATA%\\Claude": the main app's profile (login, settings, a large virtual machine bundle). 11.7 GB at capture.
  - "%APPDATA%\\Claude-Personal": the second app's profile. 11.0 GB at capture.
  - "%LOCALAPPDATA%\\ClaudePersonal\\session-backups": login snapshots. Empty at capture.
unconfirmed:
  - Whether the second app's login was valid at capture. It was last used 2026-10-07 and was not running.
  - What created the empty folders `%LOCALAPPDATA%\Claude-Data` and `%LOCALAPPDATA%\Claude-3p`, and the small leftover `%APPDATA%\Claude-Personal.loggedout-20260601-174356`.
  - Which of the two apps the Claude browser extension talks to. There is one connection file for both.
  - Whether the two windows group under one taskbar button.
  - The helper scripts in `files/` had personal wording replaced with neutral wording. They still pass a syntax check but have not been run since.
---

# Two Claude desktop apps, two accounts

One copy of Claude Desktop is installed. A shortcut starts a second window of it
with a separate profile folder, so a second account can stay signed in beside the
first. See [QUIRKS.md](QUIRKS.md).

Names used here: the **main app** is the normal Claude tile. The **second app**
is the "Claude (Personal)" shortcut.

## Install

1. Install Claude Desktop from the official download page. Open it and sign in
   with the first account. This is the main app.
2. Create the folder `%LOCALAPPDATA%\ClaudePersonal` and copy everything from
   `files/` into it.
3. Create a Start menu shortcut at
   `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Claude (Personal).lnk` with:

   | Field | Value |
   |---|---|
   | Target | `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe` |
   | Arguments | `-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\ClaudePersonal\Launch-ClaudePersonal.ps1"` with the folder written out in full |
   | Start in | `%LOCALAPPDATA%\ClaudePersonal` written out in full |
   | Icon | Optional. See the note below |
   | Run | Minimized |

   The original setup uses a file `claude.ico` in that folder as the shortcut's
   icon. It is the app's own logo, so it is not included in this recipe. To
   match the original, save the icon from your installed copy of the app under
   that name. Do not point the shortcut's icon at the app's install folder: that
   folder's name changes with every update.

4. Start the second app from that shortcut. It opens at a sign-in screen.
5. Sign the second account in using the procedure under **Maintain**. A plain
   sign-in from the second window lands in the main app instead (quirk 2).

## Verify

| Check | Expected |
|---|---|
| Start "Claude" and "Claude (Personal)" | Two windows open at the same time |
| Account shown in each window's settings | Two different accounts |
| `Get-CimInstance Win32_Process -Filter "Name='claude.exe'"`, then look at the command lines | One main process has `--user-data-dir=...\Claude-Personal`; one has none |
| `(Get-ItemProperty 'HKCU:\Software\Classes\claude\shell\open\command').'(default)'` | Ends in `claude.exe" "%1"` with **no** `--user-data-dir` |
| `%LOCALAPPDATA%\ClaudePersonal\claude-handler-original.txt` | Does not exist, or the check above passes |
| Start a Claude Code session in the second window | It starts without a sign-in error |

## Maintain

The second app's login expires from time to time. To sign it in again:

1. Close both Claude windows, including the icon near the clock. Run
   `Backup-ClaudeSessions.ps1` to save both logins.
2. Run `Login-Personal-Redirect.ps1` from a normal PowerShell window and follow
   its prompts. Keep the main app closed until it finishes.
3. If that fails, `Setup-Personal-Login-v4.ps1` is the older method. It replaces
   the second app's whole profile. Run it only from a PowerShell window opened
   outside Claude Desktop, and take a snapshot first.
4. To undo, close both windows and run `Restore-ClaudeSession.ps1` with the
   snapshot name and the profile name.

## Uninstall

To remove only the second app and keep Claude Desktop:

1. Close the second app.
2. Delete the shortcut `Claude (Personal).lnk` from the Start menu.
3. **Destroys data.** Delete `%APPDATA%\Claude-Personal` and
   `%LOCALAPPDATA%\Claude-Personal`. This removes the second account's login,
   local settings and about 11 GB. Confirm with the user first.
4. Delete `%LOCALAPPDATA%\ClaudePersonal` (scripts and login snapshots).
5. Run the link-handler check from **Verify**. If the value contains
   `--user-data-dir`, start the main app once; it rewrites the value.

Uninstalling Claude Desktop itself through Windows does **not** do steps 2-4.

Leave alone: `%APPDATA%\Claude` (the main app's profile), `~\.claude` (Claude
Code settings shared by both apps), `%APPDATA%\Claude-NativeHost`.

## Doctor

1. Run every check in **Verify** and report which fail.
2. Compare the scripts in `%LOCALAPPDATA%\ClaudePersonal` with `files/`. Report
   differences as drift, ignoring the neutral wording noted under `unconfirmed`
   and the icon file, which the recipe leaves out.
3. Read the second app's log at `%LOCALAPPDATA%\Claude-Personal\logs\main.log`.
   Recent `session_stale_relogin` lines mean its login has expired.
4. Check for folders in `%APPDATA%` named `Claude.*-backup-*`,
   `*.mylogin-bak-*`, `*.mylogin-stray-*` or
   `Claude-Personal.old-*`. Any of these means a sign-in script was interrupted.
5. For the reported symptom, go through [QUIRKS.md](QUIRKS.md) and run the
   "Rule it out" test of each quirk that lists a matching symptom.
6. Give one of the standard verdicts, with the evidence.
