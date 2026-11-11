---
name: neko
captured_on: 2026-11-11
captured_from: Windows 11 Home (10.0.26300)
app_version: neko 3.1.5 (both images built 2026-08-05), Chrome 151.0.7922.75 inside
image_pins:   # both stacks ask for "latest"; these are the exact images captured
  - ghcr.io/m1k1o/neko/google-chrome@sha256:65813e48cc16b5f93e79b1a16e8f02791274c055d7be0812eeeebb015c2cfc0e
  - ghcr.io/m1k1o/neko/vlc@sha256:5842e399d544ffd72b0dea3fb881fec66d7cca360c385f338311bf76e900ae34
source: https://github.com/m1k1o/neko   # images from ghcr.io/m1k1o/neko
components:
  - neko       # shared Chrome browser, always on, web port 8080
  - neko-vlc   # shared VLC player for film nights, started on demand, web port 8081
needs:
  - Docker Desktop (captured: 4.98.0, set to start with Windows)
  - Tailscale, signed in (captured: 1.104.1). Remote viewers connect over it.
  - For neko only: the "Yt Music Lyrics Extension" project folder on this machine
needs_admin:
  - Reserving UDP ports 56000-56100 in Windows (install step 2)
secrets:
  - NEKO_USER_PASSWORD
  - NEKO_ADMIN_PASSWORD
  - VLC_USER_PASSWORD
  - VLC_ADMIN_PASSWORD
placeholders:
  - "{{HOME}}"                       # the user's home folder
  - "{{TAILSCALE_IP}}"               # this machine's Tailscale address; `tailscale ip -4`
  - "{{YTM_LYRICS_EXTENSION_DIR}}"   # full path to the extension project folder
  - "{{MEDIA_DIR}}"                  # folder holding the film for neko-vlc
state_not_in_recipe:
  - Docker volume `neko-chrome`: the shared browser's profile (site logins, saved passwords, extension data).
  - "{{HOME}}\\neko\\chrome-profile-backup": a 262 MB copy of that profile from 2026-07-29. Contains logins. Never copy it into a recipe.
unconfirmed:
  - How the lyrics extension is meant to be loaded inside the shared Chrome. At capture it was not loaded: the profile held only the two forced extensions and one built into Chrome.
  - What the two force-installed extension IDs in policies.json are. They look like neko's stock pair (an ad blocker and SponsorBlock).
  - Whether a second reserved UDP range found on the machine (50000-50059) belongs to this setup.
  - Whether a Windows firewall rule is needed. None named "neko" was found.
  - The extension project folder is empty, and has been since 2026-08-14 as seen from inside the container. The owner says the extension is being rebuilt after a buggy first version.
  - Whether the newer codec setting name would work if both older-style names were removed (see quirk 1).
  - The media folder for neko-vlc ("VLC Neko" on the Desktop) did not exist at capture.
---

# neko

neko runs a browser or a video player inside Docker and streams its screen to
other people through a web page, so a group can watch together. This setup has
two separate stacks and several fixes. See [QUIRKS.md](QUIRKS.md).

`files/neko/policies.json` is a modified copy of the Chrome rules file from the
neko project (Apache 2.0 licence). The changes are listed in quirk 7.

## Install

Steps 1-3 are shared. Then install either stack or both.

1. Install the needs. Sign in to Tailscale and note the address from `tailscale ip -4`.
2. **Needs administrator rights.** Reserve the UDP ports for the Chrome stack so
   Windows cannot hand them to another program:

   ```powershell
   netsh int ipv4 add excludedportrange protocol=udp startport=56000 numberofports=101
   ```

   Skip this step if only neko-vlc is wanted.
3. Ask the user for the four passwords listed under `secrets`.

### neko (Chrome)

4. Create `{{HOME}}\neko`. Copy `files/neko/policies.json` into it.
5. Fill the placeholders in `files/neko/docker-compose.template.yml` and save it
   as `{{HOME}}\neko\docker-compose.yml`.
6. Create the profile volume. The stack refuses to start without it:

   ```powershell
   docker volume create neko-chrome
   ```

7. In `{{HOME}}\neko`, run `docker compose up -d`.
8. Open `http://localhost:8080`, log in with the admin password, and sign in to
   the sites the browser should remember. These logins cannot come from the recipe.
9. Load the lyrics extension inside the shared Chrome from
   `/home/neko/extensions/ytm-lyrics`. The exact method is unconfirmed: ask the user.

### neko-vlc

10. Create `{{HOME}}\neko-vlc` and the media folder. Put the film in the media folder.
11. Fill the placeholders in `files/neko-vlc/docker-compose.template.yml` and
    save it as `{{HOME}}\neko-vlc\docker-compose.yml`.
12. Start it only when needed: `docker compose up -d`. Stop it after: `docker compose down`.

## Verify

| Check | Expected |
|---|---|
| `netsh int ipv4 show excludedportrange protocol=udp` | A line `56000  56100` marked with `*` |
| `tailscale ip -4` | Matches `NEKO_WEBRTC_NAT1TO1` in both compose files |
| `docker volume ls` | Lists `neko-chrome` |
| `docker compose ps` in `{{HOME}}\neko` | Service `neko` is running |
| `http://localhost:8080` | neko login page; after login the browser screen shows, not a blank one |
| `docker compose logs neko` | Contains "legacy configuration is enabled"; no pipeline errors |
| From another device on Tailscale: `http://{{TAILSCALE_IP}}:8080` | Same page, with moving video |
| neko-vlc, when started: `http://localhost:8081` | VLC paused at 0:00 with the film loaded |

## Uninstall

1. In `{{HOME}}\neko-vlc`, run `docker compose down`.
2. In `{{HOME}}\neko`, run `docker compose down`.
3. **Destroys data.** `docker volume rm neko-chrome` deletes the shared browser's
   logins and saved passwords. Confirm with the user first, or skip to keep them.
4. Remove the images: `docker image rm ghcr.io/m1k1o/neko/google-chrome:latest ghcr.io/m1k1o/neko/vlc:latest`.
5. **Needs administrator rights.** Release the reserved ports:

   ```powershell
   netsh int ipv4 delete excludedportrange protocol=udp startport=56000 numberofports=101
   ```

6. Delete `{{HOME}}\neko` and `{{HOME}}\neko-vlc`. The first holds
   `chrome-profile-backup`, which contains logins: confirm with the user.

Leave alone: Docker Desktop, Tailscale, the extension project folder, the media
folder, and the other reserved UDP range (50000-50059).

## Doctor

1. Check that Docker Desktop is running and Tailscale is signed in. When this
   capture began both were off, and nothing below works without them.
2. Run `docker ps -a` and check no other container claims port 8080 or 8081.
3. Run every check in **Verify** and report which fail.
4. Compare the live compose files and `policies.json` with `files/`, ignoring
   the placeholder values. Report every other difference as drift.
5. Compare the running image with `image_pins`. A different image means neko
   itself was updated.
6. For the reported symptom, go through [QUIRKS.md](QUIRKS.md) and run the
   "Rule it out" test of each quirk that lists a matching symptom.
7. Conclude one of: neko itself, a named quirk, drift, or a missing need.
