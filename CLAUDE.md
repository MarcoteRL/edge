# CLAUDE.md — personal fork of OpenStrap `edge`

@AGENTS.md

`AGENTS.md` is upstream's file and the source of truth for architecture and the
15 hard invariants. It is imported above and deliberately left unedited so
upstream merges stay clean. Everything fork-specific lives here and under
`docs/development/`.

## Before changing anything

1. Read `PROGRESS.md` (current state, last validation) and the task's entry in
   `docs/development/PLANNING.md`.
2. Read the relevant section of `docs/development/ARCHITECTURE.md` and
   `docs/development/TECHNICAL_AUDIT.md`.
3. Trace the real code path end to end. Doc line numbers drift: grep symbols.
4. For BLE/sync, DB, or metric changes, re-read AGENTS.md §3 (invariants) and §4.

## Skills

- Use `.claude/skills/ponytail` for all code writing/review in this repo
  (YAGNI ladder, root-cause fixes, `ponytail:` markers).
- No Anthropic skill covers Flutter/BLE/iOS. See
  `docs/development/SKILLS_AUDIT.md` before adding one.

## Subagents

Use them for read-only fan-out (finding every caller of a DB method, every
writer of a table). Keep edits in the main thread. For a change touching an
AGENTS.md §3 invariant, get an independent review pass before calling it done.

## Validation

- Local (Windows): `flutter analyze` and `flutter test --concurrency=1`
  (Flutter 3.41.6 exactly). `--concurrency=1` is required: tests share sqflite
  files.
- CI on your repo: `test.yml` is **disabled** (private repo, ~90 min/run of
  quota): tests run locally on the owner's PC. `ios-sideload.yml` builds the
  unsigned IPA. Re-enable `test` with
  `gh api -X PUT repos/MarcoteRL/edge/actions/workflows/test.yml/enable`. An iOS build cannot run on
  Windows. Say so instead of claiming it ran.
- Never claim hardware validation without a real band. Write "unit-tested,
  not hardware-validated".
- Separate pre-existing failures from regressions: record the baseline in
  `PROGRESS.md` before changing code.

## Scope discipline

- One task per change, smallest diff that fixes the root cause.
- No drive-by refactors, renames, formatting sweeps, or dependency bumps.
- Don't edit upstream files just to add fork notes. Fixes that upstream would
  want go in separate, focused commits so they can become PRs.
- Never bump `kAlgoVersion`, `schemaVersion`, or sibling pins without the
  matching AGENTS.md process (changelog entry, pin equality, migration test).

## Tracking progress

After meaningful work, append to `PROGRESS.md` (don't rewrite history) and
update the task's status in `PLANNING.md`. Mark a task done only with evidence:
a command output, CI run, or test name.

## Git

No commits, pushes, resets, or force-pushes unless asked. Remotes:
`upstream` = OpenStrap/edge. `origin` = your own repo, once you create it.
