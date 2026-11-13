---
name: release
description: "Prepare, publish and verify a complete Macro Assist Forever release. Use for /release or cutting a release, including data, README and store copy, screenshots, both stores and client installation."
---

# Release Macro Assist Forever

Run from the repository root. Read `AGENTS.md`, then the suite skills in `cjber/forever-core`
(`.agents/skills/wow-forever-addon` and `.agents/skills/wow-addon-publish`).
Also read the `copywriting` skill for README, store, release-note and UI copy, and
`wow-mock-screenshots` for images. These supply the shared standards and store procedures;
this checklist supplies the release completion criteria. Use the user's existing
authorization. A preparation-only request ends before tags or uploads.

## Prepare main

1. Fetch origin and tags. Inventory open PRs, local branches, worktrees and
   unpushed changes. Land only authorized, reviewed PRs with all checks green on
   their current heads. Preserve unfinished work and list anything excluded.
2. Regenerate the bundled data and confirm it matches its pins. There is no data-refresh
   workflow: `python3 tools/gen_commands.py --check` reproduces `Data/Commands.lua` from
   the pinned client extraction in `tools/data/`, `python3 tools/gen_icon_names.py --check`
   reproduces `Data/IconNames.lua` from the pinned icon list, and
   `python3 tools/forever_tools/credits.py --check` reproduces `Data/Credits.lua` and both
   thanks blocks from `THIRD_PARTY.md`. A failure means regenerate, never hand edit. Confirm
   `tools/forever-core.txt` and the `.pkgmeta` ForeverCore external name the same core
   release, and run `python3 -m tools.forever_tools.core_pin --latest`. `Data/Conditions.lua`
   and `Data/Recipes.lua` are hand-maintained: compare them with the behaviour being released.
3. Prepare release changes on a branch from fresh main. Choose a new version from
   the changes since the last tag. Retain `[Unreleased]` and move shipped notes
   into `## [X.Y.Z] - YYYY-MM-DD` using the UTC release date. Keep the TOC version
   as `@project-version@`. Run `python3 tools/changelog.py --check X.Y.Z` and
   `python3 tools/changelog.py --check`; inspect the extracted version notes.
   Public API changes go under an optional `### For addon authors` subsection after the
   player bullets; the release notes carry it as written.
   Every player-visible phrase lives in `Locales/enUS.lua` and no other locale ships here,
   so a new phrase needs its entry there before the release.

## Refresh every presentation surface

4. Compare `README.md`, `docs/curseforge.md`, linked documentation, defaults,
   commands and companion requirements with the behaviour being released. Remove
   stale claims and broken links. Run `python3 tools/check_copy.py README.md docs/curseforge.md`,
   `python3 tools/check_family.py` and `python3 tools/check_store_page.py`. Keep README/store
   copy within the shared length limits; each CurseForge gallery caption (a screenshot's alt
   text) stays at or under 128 characters.
5. Screenshots are rendered from source by `tools/screenshots.py` through the wowmock library
   in the ForeverCore checkout named by `FOREVER_CORE`. Run `python3 tools/screenshots.py`
   twice, requiring identical output bytes. Inspect the actual images at readable
   size, including the changed features and empty/error states. Then run
   `python3 tools/check_screenshots.py` and `python3 tools/visual_audit.py`. Commit the current
   images, `docs/screenshots/layout.json` and `docs/screenshots/scenes.sha256`; remove obsolete
   images and their references. Regenerate `media/icon-400.png` from `media/icon.svg` if the
   icon changed, and check README image links against the files that will exist on main.
6. Record the intended store summary, description, logo and gallery set with exact
   filenames, captions and order. Use current committed assets for GitHub,
   CurseForge and Wago. Gallery refresh includes replacing stale screenshots and
   duplicates, not merely appending the new set. Preserve any intentionally kept
   images; identify the exact stale images before deleting them. Use authorized
   browser/connector tooling for changes the packager does not perform.

## Verify and publish

7. Run the fast lint/type gate from `AGENTS.md`, focused checks for changed
   behaviour, the regenerated-data checks and
   `python3 tools/forever_sim/sync.py check`. Full suites run in CI. Agents test in game
   only through the headless client (`forever_client.py`); `/reload` checks in the user's
   own client are recorded separately.
8. Commit the release preparation with a signed commit and ship its reviewed,
   green PR. Merge only within the user's authorization. Wait for the complete
   `ci.yml` **push run on main at the exact commit to be tagged**. PR checks and
   workflow-dispatch runs do not satisfy `tools/release_check.py`. Confirm the
   primary checkout is clean main at that commit before proceeding.
9. Smoke that exact commit, because `tools/release_check.py` refuses a release without a
   green `headless-smoke` commit status. From the workspace, with `forever-core` beside this
   checkout:

   ```sh
   python3 ../forever-core/tools/headless/forever_client.py smoke --repo macro-assist-forever --ref <full sha>
   ```

   It builds that commit's dev archive, loads it in the headless client, runs `/forever
   selftest` and `errors --addon`, then posts the status on the commit.
   - Exit 3 means another session or the player holds the client: wait and retry, never start
     the game another way.
   - While launcher OCR misses Play (cjber/forever-core#547), pass `--manual-launcher`, run it
     in the background, take `forever_client.py shot` and click Play yourself after checking
     the account. If the game shows its own Email/Password form, stop the smoke with Ctrl-C
     (SIGINT to the python process) and ask the user to log in once through Faugus. Never type
     credentials.
   - A failed smoke is a release blocker: fix the errors it names before continuing.
10. Inspect `.github/workflows/release.yml`, `.pkgmeta` and `MacroAssistForever.toc`.
   Confirm `X-Curse-Project-ID` (1795141), `X-Wago-ID` (O67bypN3), interface 16001,
   `## Dependencies: ForeverCore`, the `X-Forever-Core` pin, `SavedVariables` and the
   ForeverCore external and move-folders are right. Check secret names with
   `gh secret list`: `CF_API_KEY` and `WAGO_API_TOKEN` must both be present; never print
   their values. A cloud session cannot push tags, so start the Release workflow on main
   with `version` (and `commit` for an older main commit); it tags that commit and publishes.
   Preserve existing tags.
11. Watch the tag's release workflow through completion. Inspect its log for both
    store IDs with `[token set]` and successful uploads to each provider. A green
    workflow can silently skip a provider with a missing token. Download and
    inspect the GitHub release zip: substituted version, TOC/XML load graph,
    runtime files, media, the bundled JetBrains Mono font and `Data/` tables must be present,
    and `ForeverCore/` must ship at the external's release with `Core/ForeverRequire.lua`;
    development files, `tools`, `tests`, `docs`, `.agents` and the `forever-core` checkout
    must remain excluded.
12. Apply the prepared summary, description, logo and gallery to both stores.
    Save, reopen and verify each surface, including captions/order and removed
    duplicates. Check GitHub's rendered README, release notes and image links too.
    An upload does not update store descriptions or galleries automatically.
13. Verify the public CurseForge files page and Wago version page show this version
    for the intended client, with the correct notes and downloadable artifact.
    Report moderation or an unavailable surface as pending, with its URL; uploaded
    or workflow-green does not mean publicly live. Retry without creating another
    version or tag to mask a failed upload.
14. If installation was requested, update every authorized client copy/symlink to
    the released version or verified main commit, preserve saved variables and
    backups, include the ForeverCore folder `move-folders` places beside the addon, and verify
    targets and the load graph. Retire named obsolete addon folders/links outside AddOns
    so old packaging cannot remain enabled. Tell the user to `/reload`.
    Report version/tag and commit, CI/release links, package verification, each
    store's public status, copy/gallery verification and any remaining client
    checks. The release is complete only when every requested surface is verified.

## Addon checks

- Review the generated `Data/Commands.lua`, `Data/IconNames.lua` and `Data/Credits.lua` with
  their sources. `Data/Conditions.lua` keeps `verified = false` until an in-game probe
  confirms a condition on this client; record that probe separately. Every recipe in
  `Data/Recipes.lua` is checked by `tests/recipes_spec.lua` before it ships.
- Review the macro window, editor, completions, conditions, icon picker and history against
  the actual feature registrations. Check default settings in `Core/Core.lua`.
- User checks: `/macro`, `/m`, the game menu, the keybind and the addon compartment open the
  window; General and character tabs, search, completions, live condition values, problems
  and their fix, the status line, rename/new/save/cancel/delete, import, shorten, history
  and restore all work; every write is off in combat; no Lua errors or blocked actions.
  Paste `/macroassist report` into the report box when checking the report path.

## Command discovery

`.agents/skills/release/SKILL.md` is the canonical file for Codex. Claude and
Pi load it through `.claude/skills/release` and `.pi/skills/release` symlinks;
`/skill:release` also works. Reload agent commands after adding it.
