# KinRemind

Cross-device family reminder app. One person (the **owner**) sets
reminders — take medicine, daily routines, one-off occasions — that ring
as loud, full-screen, alarm-style notifications directly on a family
member's phone, straight through silent mode and DND, synced in real
time.

Self-hosted, not a shared service: each family clones this repo, spins up
their own free Firebase project, and runs their own private instance. No
account of yours ever touches anyone else's data — see
[`PROJECT_SPEC.md`](./PROJECT_SPEC.md) section 2 for why.

## Get started

New here? Read these in order:

1. **[docs/01-quick-start.md](./docs/01-quick-start.md)** — step by step, from zero to a working APK on your family's phones.
2. **[docs/02-architecture.md](./docs/02-architecture.md)** — how the pieces fit together, in one page.
3. **[docs/03-modules.md](./docs/03-modules.md)** — what's togglable if something breaks, and how to pull a module out.
4. **[docs/04-troubleshooting.md](./docs/04-troubleshooting.md)** — the app doesn't ring / a reminder didn't sync / etc.

The full spec — every locked decision and why — lives in
[`PROJECT_SPEC.md`](./PROJECT_SPEC.md). Read that before contributing;
see [`CONTRIBUTING.md`](./CONTRIBUTING.md) for how.

## MVP scope, in short

- Android only, sideloaded APK, no Play Store.
- 1 owner + a handful of family members, static login (pick your name,
  enter your PIN) — no accounts, no sign-up.
- Firestore only, free tier — no servers, no Cloud Functions, no FCM.
- Every reminder rings the same way: full-screen alarm, Dismiss or
  Snooze (10 min, repeats until dismissed).

## Security note

There is no real authentication (see `PROJECT_SPEC.md` section 7) — an
accepted trade-off for a private family tool, not an oversight. Don't put
anything sensitive into reminder text.

## License

MIT — see [`LICENSE`](./LICENSE).
