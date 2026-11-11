# neko: quirks of this installation

Captured 2026-11-11 from the settings files, from Windows, and from the running
Chrome container. The VLC container was stopped (last run 2026-09-12), so its
entries come from its settings file only.
"Not recorded" means the owner should fill in the reason.

## 1. Video is forced to H.264 with a fixed bitrate

- **What:** Both stacks set `NEKO_VIDEO_CODEC: h264` and `NEKO_VIDEO_BITRATE: 3000`.
- **Why:** From the notes in the settings file. This image runs in an older
  settings mode, so the newer setting name for the codec is silently ignored.
  And H.264 without a bitrate makes the video encoder fail, which gives a blank screen.
- **Where:** `environment` in both `docker-compose.yml` files.
- **Can cause:**
  - A blank screen for everyone if the bitrate line is removed.
  - Settings copied from neko's current documentation having no effect.
  - Breakage after an image update, because both stacks follow `latest` and a
    newer image may leave the older settings mode.
- **Seen at capture (neko 3.1.5):** the log confirms the older mode is on and
  the video pipeline passes its check. But the log gives a different cause from
  the note above: "legacy configuration is enabled because at least one V2
  configuration was used". So the older mode may be switched on by these two
  settings themselves, and the newer names might work if both were removed.
  This was not tested. The log also shows video captured at 25 frames per
  second, although the screen is set to 30.
- **Rule it out:** Run `docker compose logs neko`. Look for
  "legacy configuration is enabled" and for pipeline errors. If the first line
  is gone, the image changed and these settings need revisiting.

## 2. Screen is 1280x720 at 30 frames per second

- **What:** Lowered from 1920x1080 at 60 on 2026-09-04.
- **Why:** From the owner: a remote viewer saw skipping and buffering while the
  host's own picture was smooth. The owner judged that a 30 Mbps home
  connection could not send a full HD stream to that viewer, and lowered it.
- **Where:** `NEKO_DESKTOP_SCREEN` in both compose files. The older file is kept
  as `docker-compose.yml.pre-720p`.
- **Can cause:** Softer picture and less smooth motion than a stock setup.
- **Rule it out:** Not a fault. To compare, set it back to `1920x1080@60` and recreate.

## 3. Viewers connect through Tailscale, at a fixed address

- **What:** `NEKO_WEBRTC_NAT1TO1` tells neko to announce one address to viewers:
  this machine's Tailscale address.
- **Why:** From the owner: the regular viewer is in another country, and the
  setup must not be reachable from the open internet. Tailscale lets that
  viewer in without opening ports on the router.
- **Where:** `NEKO_WEBRTC_NAT1TO1` in both compose files. Needs Tailscale signed in.
- **Can cause:**
  - The page loads and login works, but the video never appears. This happens
    when Tailscale is off, signed out, or has a new address, and for any viewer
    not on your Tailscale network. That includes a viewer on the same Wi-Fi.
  - The same failure on a new machine if the old address is copied over.
- **Rule it out:** Run `tailscale ip -4` and compare with the setting. Then test
  from a second device that is on Tailscale.

## 4. Windows has UDP ports 56000-56100 reserved for the Chrome stack

- **What:** A Windows-level reservation made with administrator rights. It lives
  outside Docker and outside the neko folder.
- **Why:** These ports sit in the range Windows hands out to programs at random.
  Without the reservation, another program can take one and the stack fails to
  start. The VLC stack avoids the problem by using 48000-48020, below that range.
- **Where:** `netsh int ipv4 show excludedportrange protocol=udp`.
- **Can cause:**
  - Without it: "ports are not available" or "bind: access denied" when starting
    the Chrome stack, often only after a reboot and only sometimes.
  - It survives uninstalling neko and Docker unless removed by hand.
- **Rule it out:** Run the command above and look for `56000  56100` with a `*`.

## 5. The Chrome container has a fixed name, `neko`

- **What:** `hostname: "neko"`.
- **Why:** From the notes in the settings file. Chrome locks its profile to the
  computer name. A recreated container gets a random name, and Chrome then
  refuses to start on the saved profile.
- **Where:** `{{HOME}}\neko\docker-compose.yml`.
- **Can cause:** If removed: Chrome does not open after an update or recreate,
  with a "profile in use" message.
- **Rule it out:** Check the line is present.

## 6. The browser profile lives in a volume created by hand

- **What:** The volume `neko-chrome` is marked `external`, so Docker neither
  creates nor deletes it with the stack.
- **Why:** From the owner, with some doubt ("yes I think"): so that
  `docker compose down -v` cannot wipe the logins by accident.
- **Where:** `volumes` in the Chrome compose file. A copy of the profile from
  2026-07-29 is in `{{HOME}}\neko\chrome-profile-backup`.
- **Can cause:**
  - On a new machine: "external volume neko-chrome not found" until it is created.
  - A fresh volume starts with no logins. Sites must be signed in to again.
- **Rule it out:** `docker volume ls` should list `neko-chrome`.

## 7. Chrome's rules were loosened to allow a home-made extension

- **What:** Compared with the earlier file (`policies.json.bak`, 2026-08-10),
  three rules changed: file-picker windows are allowed, developer mode for
  extensions is allowed, and the block on installing other extensions was
  removed. The "Yt Music Lyrics Extension" project folder is mounted into the
  container read-only.
- **Why:** From the owner: to load that extension by hand. An earlier version
  was buggy and the extension is being rebuilt, so it is still wanted.
- **Where:** `{{HOME}}\neko\policies.json`; the third `volumes` line in the Chrome
  compose file.
- **Can cause:**
  - The stack depends on a folder from another project. If that folder is moved
    or renamed, Docker mounts an empty folder and the extension vanishes.
  - **Found at capture:** the folder is empty, and from inside the container it
    has been since 2026-08-14. The extension is not loaded in the shared Chrome.
    The loosened rules are in force with nothing using them. The owner
    confirms this is expected until the rebuilt extension is ready.
  - Any viewer with control of the browser can install extensions.
  - Changes to the extension's files appear in neko only after reloading it.
- **Rule it out:** Open `chrome://extensions` inside the shared browser and check
  the extension is listed and switched on.

## 8. The VLC stack opens paused, using a side effect of the image

- **What:** `VLC_MEDIA: "--start-paused /media"`. The setting is meant to hold a
  file path. An extra option is slipped in before it.
- **Why:** From the notes in the settings file: so the film waits at 0:00
  instead of playing to an empty room.
- **Where:** `{{HOME}}\neko-vlc\docker-compose.yml`.
- **Can cause:**
  - "Nothing is playing" when the stack starts. That is intended: press play.
  - VLC failing to open the film after an image update, if the image starts
    quoting that value.
- **Rule it out:** Remove `--start-paused ` and recreate the stack.

## 9. The two stacks behave differently on purpose

- **What:** Chrome restarts by itself (`restart: always`) on port 8080. VLC
  never restarts by itself (`restart: no`) on port 8081 and is meant to be
  started for a film night and taken down after. They share nothing.
- **Why:** From the notes in the VLC settings file: so the VLC stack cannot
  touch the Chrome profile.
- **Where:** Both compose files.
- **Can cause:**
  - "The VLC page is down" after a reboot. That is intended.
  - The Chrome stack being down after a reboot if Docker Desktop did not start.
    Docker Desktop is set to start with Windows, yet it was not running when
    this capture began.
  - **Found at capture:** another container on this machine (a PDF tool, created
    2026-11-03, now stopped) is also set to use port 8080. Only one can hold the
    port. Whichever starts second fails with "port is already allocated".
- **Rule it out:** `docker compose ps` in each folder.

## 10. Passwords are kept as plain text, and differ between the stacks

- **What:** Each stack has a viewer password and an admin password written in
  its compose file. The Chrome stack's pair was changed on 2026-11-01 to short
  four-digit values. The VLC stack still has the earlier, longer pair. The
  backup files in `{{HOME}}\neko` also contain the earlier pair.
- **Why:** From the owner: the short passwords make logging in easier. The VLC
  stack is rarely used, so its older passwords were never changed.
- **Where:** Both compose files, `docker-compose.yml.bak`, `docker-compose.yml.pre-720p`.
- **Can cause:**
  - "Wrong password" when a viewer uses the VLC password on the Chrome page or
    the other way round.
  - Port 8080 is open to every device on the same Wi-Fi, not only to Tailscale.
    Anyone there who guesses a four-digit password gets in.
- **Rule it out:** Compare what the viewer typed with the right stack's file.

## Not established by this capture

See `unconfirmed` in [recipe.md](recipe.md).
