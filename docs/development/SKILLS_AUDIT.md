# Skills audit

Date: 2026-11-09. Environment: Claude (cloud workspace + shell on the owner's
PC via the desktop app), not a local Claude Code CLI, so `/skills` was not
available. Skills were reviewed from the session's skill list, the repo, and
`github.com/anthropics/skills` (cloned at HEAD).

## Project skill: `.claude/skills/ponytail`

- **What it does:** "lazy senior dev" discipline. A YAGNI ladder (build it at
  all? reuse? stdlib? platform? existing dep? one line?), root-cause bug fixes
  at the shared function, `ponytail:` comment markers for deliberate
  simplifications, and one runnable check for non-trivial logic.
- **Repo-specific content:** points at the pure-policy files
  (`lib/ble/ble_state.dart`, `lib/sync/sync_policy.dart`), the single
  day-label/notification helpers, the already-installed deps to prefer, and the
  invariants a "simpler" version must not break (commit-before-ACK, ACK seq
  discipline, DST day windows, dangerous-opcode block, pin gates).
- **Verdict: USE** for all code work. It matches this fork's goals: small,
  upstreamable diffs.

## Anthropic skills (`anthropics/skills`)

| Skill | Relevant? | Verdict |
|---|---|---|
| skill-creator | Only if a project skill is ever justified | Use then, not now |
| webapp-testing (Playwright) | No: Flutter mobile app, not a web app | Ignore |
| mcp-builder | No | Ignore |
| doc-coauthoring | Marginal (docs are repo markdown) | Ignore |
| docx/pdf/pptx/xlsx | No | Ignore |
| frontend-design, canvas-design, theme-factory, algorithmic-art, brand-guidelines, web-artifacts-builder, slack-gif-creator, internal-comms, claude-api, academy-guide, discernment-nudge | No | Ignore |

Nothing in the official set covers Flutter/Dart, BLE, iOS/Xcode, security
review, or Git workflows. Install, if ever needed, with
`/plugin marketplace add anthropics/skills` then
`/plugin install example-skills@anthropic-agent-skills`. Not recommended now.

## Session environment findings

- Shell: available (cloud Linux + a Linux VM on the owner's PC). No Windows
  shell and no macOS/Xcode.
- Internet: allowlisted. GitHub is reachable. **pub.dev and Google's Flutter
  SDK storage are blocked in both shells**, so `flutter`/`dart` cannot be
  installed and `flutter analyze`/`flutter test` cannot run in-session.
- `gh` is installed in the cloud shell but not authenticated for the owner's
  account. Not installed on the PC-side shell.
- Subagents: available. MCP: artifacts, browser, past chats. Nothing
  Flutter-specific.
- Workflow lint: `actionlint` 1.7.12 + shellcheck installed via pip and used.

## Custom skills (Phase 6): decision

**None created yet.** Candidates and why they wait:

- *BLE/sync change review* (invariants 1, 2, 9, 12, 14, 15 as a checklist):
  real value, but AGENTS.md §3 already is that checklist. Create it only if
  reviews keep missing an invariant.
- *iOS sideload build*: a single workflow plus `IOS_BUILD_PIPELINE.md` covers it.
- *DB migration review*: covered by AGENTS.md invariant 11 and
  `test/db_migration_ladder_test.dart`.

Revisit after a few real fix cycles show a repeated multi-step procedure.
