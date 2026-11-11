# Two Claude desktop apps: quirks of this installation

Captured 2026-11-11. The main app was running. The second app was not, and was
last used 2026-10-07. No login file was opened during capture.
"Not recorded" means the owner should fill in the reason.

## 1. The second app is the same program started with a different profile folder

- **What:** Only one Claude Desktop is installed. The "Claude (Personal)"
  shortcut runs a hidden script that starts the same program with
  `--user-data-dir` pointing at `%APPDATA%\Claude-Personal`.
- **Why:** From the script's notes: so a different account can be used beside
  the main app.
- **Where:** Start menu shortcut `Claude (Personal).lnk`;
  `%LOCALAPPDATA%\ClaudePersonal\Launch-ClaudePersonal.ps1`.
- **Can cause:**
  - Both apps always have the same version. An update changes both at once.
  - The shortcut does nothing visible if PowerShell is blocked from running scripts.
  - A pop-up "Claude Desktop is not installed" if the main app is removed.
  - Anything that opens Claude without the shortcut (a web link, a file, a
    notification) opens the main app.
- **Rule it out:** Sign the same account in to the main app and repeat the
  problem there. If it happens in both, it is Claude Desktop, not this setup.

## 2. Signing in from the second window lands in the main app

- **What:** Sign-in finishes in the web browser, which hands the login back
  through a `claude://` link. Windows sends every such link to the main app's
  profile. `Login-Personal-Redirect.ps1` points that link at the second profile
  for the length of one sign-in, then puts it back.
- **Why:** From the script's notes: without this, the second account's login
  arrives in the main app.
- **Where:** Registry value `HKCU\Software\Classes\claude\shell\open\command`.
- **Can cause:**
  - After signing in from the second window: the second window stays signed out
    and the main app changes account, or nothing seems to happen.
  - If the script is stopped part-way, the link stays pointed at the second
    profile. Sign-ins and Claude links for the main app then open the second app.
  - Starting the main app during the sign-in rewrites the link and the login can
    land in the wrong place.
- **Rule it out:** Read the registry value. It must not contain
  `--user-data-dir`. At capture it was clean.

## 3. An older sign-in method swaps whole profile folders

- **What:** `Setup-Personal-Login-v4.ps1` moves the main profile aside, signs
  the second account in to the empty main slot, copies that login into the
  second profile, then moves the main profile back.
- **Why:** It came before the method in quirk 2 and is kept as a fallback.
- **Where:** `%LOCALAPPDATA%\ClaudePersonal\Setup-Personal-Login-v4.ps1`.
- **Can cause:**
  - The second app loses its local settings and its large virtual machine
    bundle, which then downloads again. The old profile is kept as
    `Claude-Personal.old-<date>`.
  - If run from a terminal inside Claude Desktop, it stops with "profile still
    in use", because that terminal lives inside the folder being moved.
  - If interrupted, the main profile sits in a backup folder and the main app
    opens signed out. Running the script again recovers it.
- **Rule it out:** Look in `%APPDATA%` for the stray folder names listed in the
  Doctor section of [recipe.md](recipe.md). None were present at capture.

## 4. The second app's login expires and needs the procedure above

- **What:** The second profile's log holds 74 `session_stale_relogin` entries.
- **Why:** Not established. The scripts exist because this keeps happening.
- **Where:** `%LOCALAPPDATA%\Claude-Personal\logs\main.log`.
- **Can cause:** The second window opens but Claude Code sessions will not
  start, or it asks to sign in again.
- **Rule it out:** Check the dates of the newest `session_stale_relogin` lines
  against the date the problem started.

## 5. Login snapshots only work if taken with both apps closed

- **What:** `Backup-ClaudeSessions.ps1` copies the login files of both profiles.
  `Restore-ClaudeSession.ps1` puts one back.
- **Why:** From the script's notes: so any sign-in attempt can be undone.
- **Where:** `%LOCALAPPDATA%\ClaudePersonal\session-backups`.
- **Can cause:**
  - A snapshot taken while Claude is open misses the one file that holds the
    login. The backup script warns in red; the restore script refuses to use it.
  - **Found at capture:** the snapshot folder is empty. There is nothing to
    restore from if a sign-in goes wrong.
  - Snapshots contain live logins. Anyone who copies one can use the account.
- **Rule it out:** Check a snapshot has a `Network\Cookies` file for each profile.

## 6. Each profile takes about 11 GB

- **What:** 11.7 GB for the main profile and 11.0 GB for the second. Most of it
  is a virtual machine bundle that each profile downloads separately.
- **Why:** This is how Claude Desktop stores its data. Two profiles double it.
- **Where:** `%APPDATA%\Claude` and `%APPDATA%\Claude-Personal`.
- **Can cause:** Low disk space; a long download the first time the second app
  uses a feature that needs the bundle.
- **Rule it out:** Not a fault.

## 7. Some things are shared by both apps

- **What:** Both apps use the same Claude Code settings folder (`~\.claude`:
  instructions, memory, skills, plugins), the same `claude://` link handler, and
  one browser-extension connection file.
- **Why:** These live outside the profile folder, so `--user-data-dir` does not
  separate them.
- **Where:** `~\.claude`; `%APPDATA%\Claude-NativeHost`; the registry value in quirk 2.
- **Can cause:**
  - A setting, instruction or plugin changed under one account appears under
    the other.
  - Claude Code memory written under one account is read by the other.
- **Rule it out:** Check whether the thing that changed lives under `~\.claude`.

## 8. The second app's logs are in two places

- **What:** Current logs are in `%LOCALAPPDATA%\Claude-Personal\logs` (newest
  2026-10-07). An older set stops in August 2026 in
  `%APPDATA%\Claude-Personal\logs`.
- **Why:** Not established. Probably a change in a Claude Desktop update.
- **Where:** Both folders above.
- **Can cause:** Reading the old folder and concluding nothing has happened
  since August.
- **Rule it out:** Sort both folders by date and read the newer one.

## 9. Removing Claude Desktop leaves the second app's parts behind

- **What:** The shortcut, the scripts and the second profile were made by hand,
  so the Windows uninstaller does not know about them.
- **Why:** A side effect of quirk 1.
- **Where:** The three locations in the Uninstall section of [recipe.md](recipe.md).
- **Can cause:** About 11 GB left on disk and a dead shortcut after an uninstall.
- **Rule it out:** Not a fault. Follow the recipe's uninstall steps.

## Not established by this capture

See `unconfirmed` in [recipe.md](recipe.md).
