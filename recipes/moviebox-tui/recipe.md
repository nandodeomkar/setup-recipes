---
name: moviebox-tui
captured_on: 2026-11-11
captured_from: Windows 11 Home (10.0.26300)
app_version: 0.1.24   # auto-update is on, so a fresh install may be newer
source: https://github.com/mesamirh/MovieBox-Tui   # official installer: install.ps1 on the main branch
needs:
  - Python 3.12 (runs the speed-cap helper; standard library only)
  - VLC media player (captured: 3.0.24 in "C:\Program Files (x86)\VideoLAN\VLC")
secrets:
  - PENGUPLAY_AUTH_TOKEN   # personal token inside the PenguPlay addon address
placeholders:
  - "{{HOME}}"         # the user's home folder, e.g. C:\Users\<name>
  - "{{PYTHON_EXE}}"   # full path to python.exe
unconfirmed:
  - Whether the app accepts a config.json that lacks `last_update_check`.
  - Whether video played in VLC is speed-capped, or only the app's own downloads.
---

# moviebox-tui

A terminal app for finding and streaming films and series. This setup adds five
streaming addons and a download speed cap. See [QUIRKS.md](QUIRKS.md) for the reasons.

## Install

1. Install the needs listed above if they are missing. Note the full path to `python.exe`.
2. Show the user the official installer script and, on their yes, run it in PowerShell:

   ```powershell
   irm https://raw.githubusercontent.com/mesamirh/MovieBox-Tui/main/install.ps1 | iex
   ```

   It downloads the latest release from GitHub, checks the download against the
   published checksum, and puts the app at
   `%LOCALAPPDATA%\Programs\MovieBox-Tui\bin\moviebox-tui.exe`.
   To install the captured version instead of the latest:

   ```powershell
   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/mesamirh/MovieBox-Tui/main/install.ps1))) -Version v0.1.24
   ```

3. Nothing to do: the installer adds `%LOCALAPPDATA%\Programs\MovieBox-Tui\bin`
   to the **end** of the user PATH. Confirm it is there.
4. Run the app once and close it, so it creates `%APPDATA%\moviebox-tui`.
5. Copy `files/config.json` to `%APPDATA%\moviebox-tui\config.json`.
6. Ask the user for `PENGUPLAY_AUTH_TOKEN`. Fill it into
   `files/addons_config.template.json` and save the result as
   `%APPDATA%\moviebox-tui\addons_config.json`. Do not save the filled copy in the recipe.
7. Copy `files/moviebox_cap.py` to `{{HOME}}\moviebox-cap\moviebox_cap.py`.
8. Fill the placeholders in `files/moviebox-tui.cmd.template` and save it as
   `{{HOME}}\.local\bin\moviebox-tui.cmd`.
9. Make sure `{{HOME}}\.local\bin` is on the user PATH **before** the folder from
   step 3. That order is what makes the speed cap the default.

## Verify

| Check | Expected |
|---|---|
| `moviebox-tui.exe --version` | Prints a version number |
| `Get-Command moviebox-tui` (PowerShell) | First result is `moviebox-tui.cmd` in `.local\bin` |
| Entries in `addons_config.json` | Five: Cinemeta, HdHub, PenguPlay, Dramayo, yastream |
| `default_player` in `config.json` | `vlc` |
| **(needs you)** Start the app with `moviebox-tui`, then read `{{HOME}}\moviebox-cap\speedcap.log` | A new line: `session start, cap 1.5 MB/s, proxy <number>` |
| **(needs you)** Download something and read the log again | `rate` lines stay at or below about 1.50 MB/s |

## Uninstall

1. Delete `{{HOME}}\.local\bin\moviebox-tui.cmd`.
2. Delete the folder `{{HOME}}\moviebox-cap`.
3. Run the official installer with its uninstall option. It removes
   `moviebox-tui.exe` and the app's PATH entry:

   ```powershell
   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/mesamirh/MovieBox-Tui/main/install.ps1))) -Uninstall
   ```

4. Delete the now-empty folder `%LOCALAPPDATA%\Programs\MovieBox-Tui`. The
   official uninstall leaves it, and leaves everything in steps 1, 2, 5 and 6.
5. Delete `%APPDATA%\moviebox-tui` (settings, addon list, watch history).
6. Delete `%LOCALAPPDATA%\moviebox-tui` (caches, posters, subtitles, logs).

Leave alone: `{{HOME}}\.local\bin` and its PATH entry (other tools live there),
Python, and VLC.

## Doctor

1. Run every check in **Verify** and report which fail.
2. Compare the live `config.json` and `addons_config.json` with `files/`. Ignore
   `last_update_check` and addon `version` fields, which change on their own.
   Report every other difference as drift.
3. For the reported symptom, go through [QUIRKS.md](QUIRKS.md) and run the
   "Rule it out" test of each quirk that lists a matching symptom.
4. Conclude one of: the app itself, a named quirk, or drift from the recipe.
