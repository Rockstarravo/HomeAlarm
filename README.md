# KinRemind

Cross-device family reminder app. One person (the **owner**) sets
reminders — take medicine, daily routines, one-off occasions — that ring
as loud, full-screen, alarm-style notifications directly on a family
member's phone, straight through silent mode and DND, synced in real time.

The full product spec — problem statement, locked architectural decisions,
data model, edge cases, and the exact build order this codebase follows —
lives in [`PROJECT_SPEC.md`](./PROJECT_SPEC.md). Read that first if you're
contributing; this README is just the "how do I run it" half.

## Why self-hosted, not a hosted service

This is meant to be cloned and run by each family on their own free
Firebase project, not signed into as a shared service. No account of
yours ever touches anyone else's data, because there's no shared backend
at all — see `PROJECT_SPEC.md` section 2 for the full reasoning. The
trade-off is that spinning up your own instance takes the technical setup
below instead of an app-store install; a more turnkey onboarding flow is
on the roadmap (`PROJECT_SPEC.md` section 14).

## MVP scope

- **Android only.** iOS needs a paid Apple Developer account for
  distribution and is roadmap, not MVP.
- **Sideloaded APK**, no Play Store.
- **1 owner + 3–5 family members** per deployment, static login (pick your
  name, enter your PIN) — no Firebase Auth, no sign-up.
- **Firestore only**, free Spark tier — no Cloud Functions, no FCM. Sync is
  Firestore's own realtime listeners running inside the app.
- Every reminder behaves the same: full-screen alarm with **Dismiss** and
  **Snooze (10 min, repeats indefinitely)**.

## Setup — running your own instance

1. Clone this repo.
2. Create a new Firebase project on the free **Spark** plan.
3. Enable **Firestore** (Native mode) in the console.
4. Install the [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup)
   and run `flutterfire configure` from the repo root, selecting Android
   only. This writes `lib/firebase_options.dart` and
   `android/app/google-services.json` — both are gitignored on purpose,
   they're specific to your Firebase project.
5. Seed the `members` collection with your family's names and PINs — see
   [`firebase/seed_members.md`](./firebase/seed_members.md).
6. Deploy the provided rules and index:
   ```
   firebase deploy --only firestore
   ```
7. Get dependencies and build the release APK:
   ```
   flutter pub get
   flutter build apk --release
   ```
   The APK lands at `build/app/outputs/flutter-apk/app-release.apk`. Share
   it with your family (AirDrop-equivalent, a cloud drive link, USB —
   whatever's easiest) and have each of them enable "install unknown apps"
   for whichever app they use to open it.
8. Walk each member through the onboarding permission flow on first
   launch — notifications, exact alarms, battery optimization, and (on
   Xiaomi/Oppo/Vivo/Huawei/etc.) an extra autostart screen. All four are
   required before the app is considered "ready"; see `PROJECT_SPEC.md`
   section 9 for why each one matters.

### Building a release APK with your own signing key

Step 7 above signs with the Flutter debug key, which is fine for sideload
-only distribution among your own family. If you want your own key:
generate a keystore, add `android/key.properties` pointing at it (see the
[Flutter deployment docs](https://docs.flutter.dev/deployment/android)),
and update the `release` signing config in `android/app/build.gradle`
accordingly. Don't commit the keystore or `key.properties` — both are
gitignored already.

## Architecture, at a glance

```
Owner app (create/edit reminder)
        │  write
        ▼
Firestore "reminders" collection (free Spark tier)
        │  live push via open listener (websocket, not polling)
        ▼
Member device — foreground service holds the Firestore listener
        │
        ▼
AlarmManager — exact alarm on the STREAM_ALARM channel
        │
        ▼
Full-screen alarm notification — rings through silent/DND
        ├─ Dismiss → ack "done" written to Firestore, alarm cleared
        └─ Snooze (10m) → reschedules, repeats until dismissed
```

A 15-minute WorkManager task and a boot receiver exist purely as
reliability nets around that primary event-driven path — see
`PROJECT_SPEC.md` sections 4 and 10 for the full list of edge cases this
design accounts for (reboot, revoked permissions, OEM background killers,
missed alarms, etc.) and why they're handled this way.

## Repository layout

```
lib/
  main.dart              # app entry, permission/auth gating, home shell
  models/                # Member, Reminder, ReminderAck
  auth/                  # static member picker + PIN, session caching
  reminders/              # owner CRUD + member's read-only list
  sync/                  # Firestore listener, foreground service bridge,
                          #   headless sync isolate entry point
  alarms/                 # AlarmManager scheduling (cancel-and-reschedule)
  notifications/          # full-screen alarm notification + action handling
  onboarding/              # permission requests + OEM autostart deep links
  health/                 # 15-min WorkManager safety-net reconciliation
android/                  # native scaffolding: manifest, Gradle, the Kotlin
                          #   foreground service + boot receiver
firebase/                 # seed_members.md + seed script for the
                          #   `members` collection
firestore.rules
firestore.indexes.json
```

## Security note

There is no real authentication — see `PROJECT_SPEC.md` section 7. This is
an accepted trade-off for a private family tool, not an oversight. Don't
put anything you'd consider sensitive into reminder text.

## Contributing

See [`CONTRIBUTING.md`](./CONTRIBUTING.md).

## License

MIT — see [`LICENSE`](./LICENSE).
