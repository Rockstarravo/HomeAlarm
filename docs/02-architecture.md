# Architecture

The full rationale behind every decision here lives in
[`PROJECT_SPEC.md`](../PROJECT_SPEC.md) — this page is the short version,
for orienting yourself in the code.

## The main flow

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

Two reliability nets sit around that main flow rather than in it: a boot
receiver (re-arms alarms after a reboot) and a 15-minute WorkManager
health check (catches anything the live listener missed). Both are
described in [03-modules.md](./03-modules.md).

## Repository layout

```
lib/
  main.dart                 # app entry: wires modules together, permission/auth gating
  core/                     # shared, cross-module: constants, feature flags, design tokens
    constants.dart           #   Firestore names, prefs keys, channel names, durations
    feature_flags.dart       #   on/off switches for the optional modules
    theme/                   #   colors, spacing, text styles, icons
    widgets/                 #   small shared widgets (e.g. error states)
  models/                   # Member, Reminder, ReminderAck — plain data classes
  auth/                     # static member picker + PIN, session caching
  reminders/                # owner CRUD + member's read-only list
  sync/                     # Firestore listener, foreground service bridge,
                             #   headless sync isolate entry point
  alarms/                   # AlarmManager scheduling (cancel-and-reschedule)
  notifications/            # full-screen alarm notification + action handling
  onboarding/                # permission requests + OEM autostart deep links
  health/                    # 15-min WorkManager safety-net reconciliation
android/                    # native scaffolding: manifest, Gradle, the Kotlin
                             #   foreground service + boot receiver
firebase/                   # seed_members.md + seed script for the `members` collection
firestore.rules
firestore.indexes.json
```

## Why some things are "modules" and some aren't

Everything under `lib/` is organized by feature on purpose, and most of
those features can be turned off from one file
(`lib/core/feature_flags.dart`) without touching anything else — see
[03-modules.md](./03-modules.md) for exactly which ones, and why the core
flow (login, CRUD, alarm scheduling, the alarm notification itself) isn't
one of them.
