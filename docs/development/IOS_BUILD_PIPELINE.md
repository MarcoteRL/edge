# iOS build pipeline (Windows → GitHub Actions → Sideloadly)

## Investigation (2026-11-09)

| Question | Finding |
|---|---|
| Existing iOS workflow? | Yes: the `ios` job in `build.yml` builds an unsigned IPA, but only on `v*` tags, after a `preflight` version guard, with upstream secrets |
| Works in a personal repo? | **No** (TECHNICAL_AUDIT F-01): its Firebase step overwrites `lib/firebase_options.dart` with an empty file when the secret is unset, so the Dart compile fails |
| Unsigned build supported by Xcode config? | Yes: `flutter build ios --release --no-codesign` is upstream's own release command. Signing values default to placeholders in `ios/Config/Signing.defaults.xcconfig` |
| Firebase without secrets? | Yes: dummy `firebase_options.dart` is committed, the "Ensure GoogleService-Info.plist" build phase writes an inert placeholder, the Crashlytics upload phase ends in `|| true`, and `main()` catches init failure |
| CocoaPods | Handled by `flutter build ios` (runs `pod install`). `Podfile.lock` committed, platform iOS 15.0 |
| GitHub-hosted macOS runner? | Yes, `macos-latest`, same as upstream |
| Packaging | `Payload/Runner.app` zipped with `-y` (keeps framework symlinks), same as upstream |
| Watch app | Must be stripped. Its `WKCompanionAppBundleIdentifier` breaks under any per-user resign |
| App Groups / widget / Live Activity | May not work after a free-account resign (team id changes). Expected, not fixable from CI |

## The workflow: `.github/workflows/ios-sideload.yml`

- **Triggers:** "Run workflow" button (`workflow_dispatch`), and pushes to `main`
  that touch more than docs/markdown.
- **Skips on upstream** (`github.repository != 'OpenStrap/edge'`).
- **No secrets, `contents: read`, `persist-credentials: false`.**
- **Build-time defines:** none passed. Companion/backend URLs default off, and
  health-data contribution is compiled out (defaults `false`).
- **Output:** artifact `openstrap-edge-<version>-<shortsha>-unsigned.ipa`,
  kept 14 days. A run summary shows the version and bundle id. Nothing is
  committed: the job has read-only repo permissions.
- **Lint:** actionlint 1.7.12 + shellcheck clean. **Not yet executed on a
  runner.** The first run is the real test.

## Your loop

1. One-time (done 2026-11-09, `MarcoteRL/edge`, private): create an empty GitHub repo (public = free macOS minutes;
   private = macOS minutes count 10× against the free quota, so prefer manual
   runs). Then from the clone:
   ```bash
   git remote add origin https://github.com/<you>/<repo>.git
   git push -u origin main
   ```
2. In the repo: Actions → enable workflows. Disable **star-history**, **soak**,
   **pr-agent** (TECHNICAL_AUDIT F-05).
3. Actions → **ios-sideload** → Run workflow (or just push to `main`).
4. When green, download the artifact zip from the run page and unzip it to get the `.ipa`.
5. Sideloadly: drag the `.ipa`, use **the same Apple ID every time**, start.
   First launch: Settings → General → VPN & Device Management → Trust.

## Limitations and data-safety notes

- **Free Apple ID: the app stops launching after 7 days.** Re-sign with
  Sideloadly before then. Reinstalling over the existing app keeps its data.
- **Never delete the app to "fix" something.** All health data lives in the
  app's local SQLite, and deleting the app deletes it. Turn on scheduled backups
  and export the DB before experiments.
- Re-signing with a *different* Apple ID can produce a different bundle id,
  so it installs as a new, empty app.
- Widgets/Live Activities: may not work (App Group team id). Watch: absent.
- Background sync on iOS is best-effort (OS-scheduled).
- WHOOP firmware: keep the official WHOOP app off your phone. 50.43+ requires
  a WHOOP-signed token (upstream #673).

## If the first run fails

Look at the failing step's log:
- `pub get` fails on a git dependency → the sibling SHA pin is unreachable
  (rare). Compare with upstream's latest `test.yml` run.
- Xcode asks for a development team → upstream hit this before on a Flutter
  bump. Keep `flutter-version` at 3.41.6.
- Swift compile error on a new Xcode on `macos-latest` → pin the runner (e.g.
  `macos-15`) and record it in PROGRESS.md.
