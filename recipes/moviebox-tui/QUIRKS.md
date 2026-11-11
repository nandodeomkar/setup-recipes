# moviebox-tui: quirks of this installation

Captured 2026-11-11 from the live machine. "Not recorded" means the capture could
not know the reason and the owner should fill it in.

## 1. Typing `moviebox-tui` runs a speed-capped copy, not the app directly

- **What:** The command `moviebox-tui` starts a small launcher script. The script
  starts a helper program that limits download speed to 1.5 MB/s, then starts the
  real app and sends all its internet traffic through that helper. The helper
  stops when the app closes.
- **Why:** From the helper's own notes: the internet line gives 2.3–3.4 MB/s, so
  1.5 MB/s leaves room for everyone else on the connection.
- **Where:**
  - `~\.local\bin\moviebox-tui.cmd` (the launcher)
  - `~\moviebox-cap\moviebox_cap.py` (the helper)
  - `~\moviebox-cap\speedcap.log` (its log)
  - PATH order: `~\.local\bin` comes before the app's own folder, so the launcher wins.
- **Can cause:**
  - Downloads never go faster than about 1.5 MB/s in total. With four parallel
    connections each one shows roughly 0.36 MB/s. This is intended.
  - The app fails to start with "The system cannot find the path specified" if
    Python 3.12 is moved, removed or upgraded to a different folder. The launcher
    has the Python path written into it.
  - Connection errors inside the app if the helper has a problem. The log shows
    `connect failed` lines in that case.
  - A warning "speed cap proxy failed to start - running UNCAPPED" followed by a
    three-second pause at launch.
  - The cap silently stops applying if the PATH order changes. Reinstalling or
    updating with the official installer is safe: it adds the app's folder at
    the end of the PATH and does not touch the launcher.
  - The official uninstall does not remove the launcher or the helper. After it,
    typing `moviebox-tui` gives "moviebox-tui.exe not found" until they are deleted too.
- **Rule it out:** Run `moviebox-tui.exe` (with `.exe`). That starts the app
  directly with no cap. If the problem is still there, this quirk is not the cause.
- **Adjust:** Set the environment variable `MOVIEBOX_CAP` to a number in MB/s.
  `0` means no cap.

## 2. Five streaming addons are configured

- **What:** The app uses addons as its active source. Five are installed:
  Cinemeta (catalogue only), HdHub, PenguPlay, Dramayo and yastream.
- **Why:** From the owner: these are the ones that could be found by searching
  by hand. They were not chosen from a wider list.
- **Where:** `%APPDATA%\moviebox-tui\addons_config.json`; `addons_enabled: true`
  and `active_provider: "addons"` in `config.json`.
- **Can cause:**
  - Missing or failed streams when one addon's server is down. The app log on
    2026-10-29 shows Dramayo returning unreadable replies and one yastream
    request failing. Those are faults at the addon's end.
  - Different search results from a stock install, which has no addons.
- **Rule it out:** Read `%LOCALAPPDATA%\moviebox-tui\logs\moviebox-tui_rCURRENT.log`.
  A line `addon <name> failed` names the addon at fault. Switch that addon off in
  the app and try again.

## 3. The HdHub addon address carries its own settings

- **What:** The HdHub address contains an encoded settings block:
  qualities 2160p, 1080p and 720p; sorted highest first; no TorBox account.
- **Why:** From the owner: lower-quality video is not wanted.
- **Where:** The `manifest_url` of HdHub in `addons_config.json`.
- **Can cause:** No 480p or lower results from HdHub.
- **Rule it out:** Create a fresh address on the HdHub addon's settings page and
  compare results.

## 4. The PenguPlay addon address contains a personal token

- **What:** The PenguPlay address includes a login token tied to one account.
- **Why:** PenguPlay requires it.
- **Where:** The `manifest_url` of PenguPlay in `addons_config.json`. The recipe
  stores a placeholder, never the token.
- **Can cause:** PenguPlay stops returning results if the token expires or is
  revoked. Anyone who sees the full address can use the account.
- **Rule it out:** Get a fresh address from PenguPlay and replace the old one.

## 5. Two local-network sources are switched off

- **What:** `bdix_circleftp_enabled` and `bdix_dhakaflix_enabled` are `false`.
  Both were `true` until 2026-10-02.
- **Why:** From the owner: they serve Bangladesh and could not be used from
  this machine anyway.
- **Where:** `config.json`.
- **Can cause:** Nothing expected. These sources serve one country's local network.
- **Rule it out:** Not needed.

## 6. Addons were removed in the past, and the TV list is empty

- **What:** Backup files dated 2026-10-02 show a larger addon list that was cut
  down in five rounds (the backup names mention tvvoo, generic pengu, streamvix
  and a "5-addon removal"). `tv_config.json` was emptied the same day.
- **Why:** From the owner: whatever was removed was removed because it was not
  working. The reason for emptying the TV list is not remembered.
- **Where:** `%APPDATA%\moviebox-tui\*.backup-*`. These backups are not part of
  the recipe.
- **Can cause:** Confusion if an old guide or memory expects those addons.
- **Rule it out:** Not needed. If one is wanted again, restore from the matching backup.

## 7. Other settings that differ from a guess at "stock"

- **What:** Theme is `Mocha`. Player is `vlc`. No player path is set, so the app
  finds VLC by itself in `C:\Program Files (x86)\VideoLAN\VLC`. VLC is not on PATH.
  `auto_update` is on.
- **Why:** From the owner: personal preference.
- **Where:** `config.json`.
- **Can cause:**
  - "Player not found" if VLC is installed somewhere unusual on another machine.
    Fix by setting `vlc_path` in `config.json`.
  - The app version changing by itself, so a problem may start after an update
    with no change on your side. Check the version first when something new breaks.
- **Rule it out:** Run `moviebox-tui.exe --version` and compare with the version
  in `recipe.md`.

## Not established by this capture

- Whether video that plays in VLC is also speed-capped. The cap certainly covers
  the app's own downloads.
