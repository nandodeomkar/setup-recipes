# Recipe format (draft 0.1)

A **recipe** records how one person installed one app: the steps, the settings,
and the quirks. An AI agent reads it to install, uninstall, or diagnose that setup.

Draft status: this format has been tried on three setups (moviebox-tui, neko and
a dual Claude Desktop install).
Expect it to change as more apps are captured.

## Layout

```
recipes/
  <app-name>/
    recipe.md      Install, verify and uninstall steps, written for an agent
    QUIRKS.md      What differs from a stock install, why, and what it can cause
    files/         Captured settings and helper scripts, with secrets removed
```

## recipe.md

Starts with a header block of facts, then up to five sections.

| Header field | Meaning |
|---|---|
| `name` | App name |
| `captured_on` | Date the recipe was captured |
| `captured_from` | Operating system it was captured on |
| `app_version` | Version at capture time |
| `source` | Where the app comes from |
| `components` | Optional. Separate parts of one setup, each with its own folder under `files/` |
| `needs` | Other software, accounts or folders that must already be present |
| `needs_admin` | Steps that change the operating system and need administrator rights |
| `secrets` | Values the user must supply by hand; never stored in the recipe |
| `placeholders` | Machine-specific values filled in at install time, with how to find each |
| `state_not_in_recipe` | Data the setup relies on that a recipe cannot hold, such as logins |
| `unconfirmed` | Things the capture could not establish and the owner must fill in |

Sections, in order:

1. **Install** – numbered steps. Each step says what to do and where files go.
2. **Verify** – checks with an expected result. Install is not done until these pass.
   Mark a check **(needs you)** when an agent cannot do it alone, for example
   because the app must be opened and used by a person.
3. **Maintain** – optional. Chores the setup needs again and again, such as
   signing in again when a login expires.
4. **Uninstall** – numbered steps, plus a list of things that must be left alone.
5. **Doctor** – how to compare a live machine against this recipe.

## QUIRKS.md

One entry per quirk. Every entry has the same five parts:

- **What** – the change, stated plainly.
- **Why** – the owner's reason. If the capture cannot know it, write `not recorded`.
- **Where** – the exact files or settings involved.
- **Can cause** – symptoms this quirk could produce.
- **Rule it out** – the quickest way to test whether this quirk is to blame.

"Rule it out" is the part that answers "is it the app, or my setup?".

## files/

- Copy settings files as they are, unless they hold a secret or a machine-specific path.
- Replace secrets and machine-specific paths with `{{PLACEHOLDER}}` names and add
  `.template` to the file name. List every placeholder in `recipe.md`.
- Leave out caches, logs, history and backups. They are state, not setup.

## Rules for agents

- Capture is read-only. Never change the machine while capturing.
- Never write a secret into a recipe. Stop and ask the user for it at install time.
- Before install or uninstall, show the user the steps and wait for a yes.
- Do not guess a missing fact. Put it under `unconfirmed`.
- Look outside the app's own folder. Quirks also live in operating-system
  settings, in other programs the setup leans on, and in other project folders.
- Read backup and old copies of settings files. Comparing them with the current
  file shows what was changed and when. Never copy them into the recipe.
- Mark every step that destroys data or needs administrator rights.
- Never open files that hold logins. List their folders under
  `state_not_in_recipe` by name only.
- Copied scripts can carry personal details in their notes, such as names or
  family members. Replace these with neutral wording, check the script is still
  valid, and say under `unconfirmed` that the edited copy has not been run.
- Record what the setup shares with a stock install, not only what it separates.
- If something the setup needs was switched off during capture, say so in
  `unconfirmed` and list what could not be checked.
