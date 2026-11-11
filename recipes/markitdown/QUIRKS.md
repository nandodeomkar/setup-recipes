# markitdown: quirks of this installation

Captured 2026-11-11 from the live machine. "Not recorded" means the capture could
not know the reason and the owner should fill it in. No notes from the owner about
markitdown were found on the machine.

## 1. Typing `markitdown` runs a hand-written launcher, not uv's own one

- **What:** uv normally puts a small launcher program, `markitdown.exe`, in
  `~\.local\bin`. Here that file was renamed to `markitdown.uv-shim-broken.exe`
  six minutes after the install (2026-05-24, 23:30 → 23:36), and a two-line
  script `markitdown.cmd` was put in its place. The script calls the real
  program inside uv's tool folder directly.
- **Why:** not recorded. The file name suggests uv's launcher did not work at
  the time. **Contradicting evidence:** on 2026-11-11 the renamed launcher runs
  normally and prints `markitdown 0.1.5`, the same as the script.
- **Where:**
  - `~\.local\bin\markitdown.cmd` (the launcher in use)
  - `~\.local\bin\markitdown.uv-shim-broken.exe` (uv's launcher, renamed)
  - `%APPDATA%\uv\tools\markitdown\uv-receipt.toml` still says uv's launcher is
    at `~\.local\bin\markitdown.exe`. uv does not know it was renamed.
- **Can cause:**
  - `uv tool upgrade markitdown` or a reinstall puts a new `markitdown.exe` back.
    Windows prefers `.exe` over `.cmd` in the same folder, so the launcher in use
    changes silently. If whatever broke uv's launcher returns, `markitdown`
    stops working after an upgrade.
  - `uv tool uninstall markitdown` leaves both the `.cmd` and the renamed
    `.exe` behind. Typing `markitdown` then gives "The system cannot find the
    path specified".
  - The `.cmd` has the full tool folder written in it. If uv's tool folder moves
    (for example by setting `UV_TOOL_DIR`), the command breaks.
- **Rule it out:** Run the real program directly:
  `& "$env:APPDATA\uv\tools\markitdown\Scripts\markitdown.exe" <file>`. If the
  problem is still there, the launcher is not the cause.

## 2. All optional converters are installed (`[all]` extras)

- **What:** markitdown was installed as `markitdown[all]`, which adds every
  optional converter: PDF, Word, PowerPoint, Excel (new and old), Outlook
  messages, audio transcription, YouTube transcripts and Azure Document
  Intelligence. A stock `pip install markitdown` has none of these.
- **Why:** not recorded.
- **Where:** `%APPDATA%\uv\tools\markitdown\uv-receipt.toml`
  (`extras = ["all"]`). The tool folder is large because of this (it includes
  numpy, pandas, onnxruntime and the magika file-type model).
- **Can cause:**
  - Nothing harmful. Without `[all]`, a PDF or Word file would give an error
    about a missing dependency; here it works.
  - Audio and YouTube conversion contact online services (Google speech
    recognition, YouTube). Azure features need keys, which are not set here.
- **Rule it out:** `uv tool list` should show `[extras: all]`. If a converter
  says a dependency is missing, this setting was lost on reinstall.

## 3. Audio conversion uses ffmpeg from winget

- **What:** markitdown's audio converter needs ffmpeg. It finds the one winget
  installed (Gyan.FFmpeg 8.0.1, "full build") through
  `%LOCALAPPDATA%\Microsoft\WinGet\Links\ffmpeg.exe`.
- **Why:** not recorded. The user PATH also lists an ffmpeg folder inside
  another project (`...\Libraries\FFmpeg\node_modules\ffmpeg-ffprobe-static`),
  earlier than winget's folder. That folder does not exist on 2026-11-11, so it
  is skipped today. If it is ever created with an `ffmpeg.exe` in it, markitdown
  would use that copy instead.
- **Where:** user PATH, `%LOCALAPPDATA%\Microsoft\WinGet\Links`
- **Can cause:** audio files give a warning about ffmpeg or an empty result if
  winget's ffmpeg is removed or upgraded to a broken build.
- **Rule it out:** `ffmpeg -version` works and documents other than audio
  convert normally.

## Normal behaviour worth knowing

### markitdown runs on its own Python 3.13, separate from the system Python

- **What:** uv built markitdown's private environment on a Python 3.13.5 that uv
  downloaded itself (`%APPDATA%\uv\python\cpython-3.13.5-…`). It does not use
  the Python 3.12 or 3.14 installed in `%LOCALAPPDATA%\Programs\Python`, and no
  copy of markitdown is installed in those.
- **Why:** not recorded. This is uv's normal behaviour, not a choice the owner
  had to make.
- **Where:** `%APPDATA%\uv\tools\markitdown\pyvenv.cfg`
- **Can cause:**
  - `python -m markitdown` or `import markitdown` in the system Python fails
    with "No module named markitdown". This is expected: only the command works.
  - Deleting `%APPDATA%\uv\python\cpython-3.13*` breaks markitdown.
- **Rule it out:** `& "$env:APPDATA\uv\tools\markitdown\Scripts\python.exe" -c "import markitdown"`
  gives no error when the private environment is healthy.

## Shared with a stock install

- markitdown keeps no settings file, no history, no cache and no login. Nothing
  is customised inside the app itself.
- No plugins are installed (`markitdown.plugin` entry points: none).
- No environment variables affect it. `PYTHONIOENCODING` and
  `PYTHONDONTWRITEBYTECODE` are set for the whole user account, not for markitdown.
- No shortcuts, right-click menu entries, file-type links or scheduled tasks.
