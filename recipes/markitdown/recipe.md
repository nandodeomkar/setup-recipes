---
name: markitdown
captured_on: 2026-11-11
captured_from: Windows 11 Home (10.0.26300)
app_version: 0.1.5   # installed with the [all] extras; no version pin, so a fresh install gets the latest
source: https://pypi.org/project/markitdown/   # Microsoft's file-to-Markdown converter, installed as a uv "tool"
needs:
  - uv (captured: 0.10.3, at {{HOME}}\.local\bin\uv.exe)
  - A Python 3.13 that uv manages (captured: CPython 3.13.5 under %APPDATA%\uv\python). uv downloads it if missing.
  - ffmpeg on the PATH, only for audio files (captured: 8.0.1 "full_build" from gyan.dev, installed by winget as Gyan.FFmpeg)
needs_admin: []   # everything lives in the user's own folders
secrets: []   # none found; no Azure Document Intelligence or OpenAI keys are set for this setup
placeholders:
  - "{{HOME}}"          # the user's home folder, e.g. C:\Users\<name>
  - "{{UV_TOOL_DIR}}"   # where uv keeps tools; find it with `uv tool dir` (captured: %APPDATA%\uv\tools)
state_not_in_recipe: []   # the app keeps no settings, logins, caches or history of its own
unconfirmed:
  - Why the uv launcher was renamed to markitdown.uv-shim-broken.exe. Its name says it was broken, but on 2026-11-11 it runs and prints "markitdown 0.1.5".
  - Whether the owner relies on any optional part of [all] (audio, YouTube, Azure, Outlook), or only on ordinary documents.
  - Whether the owner wants a fixed version. Nothing pins 0.1.5.
  - Whether a fresh `uv tool install` on another machine gives a working markitdown.exe without the .cmd launcher.
---

# markitdown

A command-line program that turns documents (PDF, Word, PowerPoint, Excel, web
pages, images, audio and more) into Markdown text. This setup installs it with uv,
with every optional converter, and runs it through a small hand-written launcher
instead of uv's own one. See [QUIRKS.md](QUIRKS.md) for the details.

## Install

1. Check that `uv` works: `uv --version`. If it is missing, install it first as a
   separate approved step (it is not part of this recipe).
2. Install markitdown with all optional converters:

   ```powershell
   uv tool install "markitdown[all]"
   ```

   To get the captured version instead of the latest, use `"markitdown[all]==0.1.5"`.
   uv puts the program in `{{UV_TOOL_DIR}}\markitdown` and creates a launcher
   `{{HOME}}\.local\bin\markitdown.exe`.
3. Find `{{UV_TOOL_DIR}}` with `uv tool dir`. Fill it into
   `files/markitdown.cmd.template` and save the result as
   `{{HOME}}\.local\bin\markitdown.cmd`. Do not save the filled copy in the recipe.
4. Rename uv's launcher `{{HOME}}\.local\bin\markitdown.exe` to
   `markitdown.uv-shim-broken.exe`, as on the captured machine. While a file
   called `markitdown.exe` sits in the same folder, Windows runs it instead of
   the `.cmd` (see quirk 1). Ask the owner first whether this step is still
   wanted: on the captured machine uv's launcher works today.
5. Make sure `{{HOME}}\.local\bin` is on the user PATH. On the captured machine
   it is listed twice, which does no harm.
6. For audio files only: make sure `ffmpeg` is on the PATH
   (captured: `winget install Gyan.FFmpeg`).

## Verify

| Check | Expected |
|---|---|
| `Get-Command markitdown -All` (PowerShell) | One result: `markitdown.cmd` in `{{HOME}}\.local\bin` |
| `markitdown --version` | `markitdown 0.1.5` (or newer if not pinned) |
| `uv tool list` | A line `markitdown v0.1.5 [extras: all]` |
| Convert a small HTML file: `markitdown test.html` with `<h1>Hello</h1><p>A <b>test</b>.</p>` | Prints `# Hello` and `A **test**.` |
| `ffmpeg -version` | First line starts with `ffmpeg version` (only matters for audio) |

## Maintain

- **Upgrading:** `uv tool upgrade markitdown` re-creates `markitdown.exe` in
  `{{HOME}}\.local\bin`. After an upgrade, check `Get-Command markitdown -All`
  again and repeat Install step 4 if `markitdown.exe` came back.
- The `.cmd` launcher points into the tool folder, not at a Python version, so a
  Python update inside uv does not break it.

## Uninstall

1. Delete `{{HOME}}\.local\bin\markitdown.cmd`.
2. Delete `{{HOME}}\.local\bin\markitdown.uv-shim-broken.exe`. uv does not know
   about the renamed file and will not remove it.
3. Run `uv tool uninstall markitdown`. It removes `{{UV_TOOL_DIR}}\markitdown`.
   It may warn that `markitdown.exe` is already gone; that is expected.

Leave alone: `uv` itself and `{{HOME}}\.local\bin` with its PATH entry (other
tools live there: graphify, notebooklm, moviebox-tui, claude), the
uv-managed Pythons (other uv tools use them), and ffmpeg (other projects use it).

## Doctor

1. Run every check in **Verify** and report which fail.
2. Compare `{{HOME}}\.local\bin\markitdown.cmd` with `files/markitdown.cmd.template`,
   ignoring the placeholder. Any other difference is drift.
3. Check whether `{{HOME}}\.local\bin\markitdown.exe` exists. If it does, it is
   the program that runs, not the `.cmd` (quirk 1).
4. Compare the version from `uv tool list` with `app_version`. A difference means
   markitdown itself changed.
5. For the reported symptom, go through [QUIRKS.md](QUIRKS.md) and run the
   "Rule it out" test of each quirk that lists a matching symptom.
6. Give one of the standard verdicts, with the evidence.
