# Contributing to KinRemind

Thanks for considering it. Before anything else, read
[`PROJECT_SPEC.md`](./PROJECT_SPEC.md) — the scope, architecture, and a long
list of edge cases in it are **locked decisions**, not open questions. PRs
that reopen a locked decision (adding Firebase Auth, moving off Firestore
listeners onto polling, changing the snooze behavior, etc.) should start as
an issue discussing the trade-off, not a PR — see section 14 for what's
already recognized as roadmap rather than MVP scope.

## Setting up a local dev Firebase project

Don't develop against your real family's project. Spin up a second,
throwaway Firebase project the same way the README describes for a real
deployment (Spark plan, Firestore enabled, `flutterfire configure`, seed a
couple of fake members via `firebase/seed_members.md`). This keeps your
test reminders and alarms out of anyone's actual phone.

## Code style

- Standard `flutter_lints` rules (`analysis_options.yaml`) — run
  `flutter analyze` before opening a PR.
- Format with `dart format .`.
- Match the existing module boundaries (`lib/auth`, `lib/reminders`,
  `lib/sync`, `lib/alarms`, `lib/notifications`, `lib/onboarding`,
  `lib/health`) rather than reaching across them directly; go through the
  service/repository class a module already exposes.
- Comments explain *why*, not *what* — see the top of any existing file
  for the tone to match.

## Testing changes

Most of what this app does — exact alarms firing through silent mode,
foreground-service survival, OEM autostart screens, boot recovery — can
only really be verified on a physical device, not an emulator. If your
change touches `lib/alarms`, `lib/notifications`, `lib/sync`, or the native
`android/` code, test on at least one real device before opening a PR, and
say what you tested it on (device + Android version) in the PR
description.

## Submitting a PR

1. Fork, branch off `main`.
2. Keep PRs scoped to one thing — a bug fix, one roadmap item, etc.
3. Reference the `PROJECT_SPEC.md` section your change relates to, if any.
4. Describe what you tested and on what device/Android version.
