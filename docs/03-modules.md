# Modules — what's togglable, and how to pull one out

KinRemind is split into feature folders under `lib/` so that if one piece
misbehaves on a particular device, you can isolate or remove it without
tearing into the rest of the app. This page is the map: what each module
does, whether it has an on/off switch, and what to do if it doesn't.

## The three flags

Open [`lib/core/feature_flags.dart`](../lib/core/feature_flags.dart).
Flip any of these to `false`, hot-restart the app, and that layer is gone
— no other file needs to change:

| Flag | Module | What turning it off does |
|---|---|---|
| `healthCheckEnabled` | `lib/health/` | Removes the 15-minute WorkManager safety-net reconciliation. The live Firestore listener keeps scheduling alarms exactly as before — this only removes the backup. |
| `oemAutostartStepEnabled` | `lib/onboarding/oem_settings.dart` | Skips the manufacturer-specific "open autostart settings" onboarding step. Useful if a ROM update changes where that settings screen lives and the app starts opening the wrong thing. |
| `foregroundSyncEnabled` | `lib/sync/foreground_service.dart` | Reminders only sync while the app is open in the foreground, instead of via the background service. Useful for isolating whether the foreground service itself is what's crashing or draining battery. |

These three are genuinely optional — the app still does its one job
(reminders arrive and ring) without them, just with less redundancy.

**One nuance for `foregroundSyncEnabled`:** the native Android boot
receiver (`BootCompletedReceiver.kt`) still starts the foreground service
on reboot regardless of this Dart flag — it can't see it. The Dart code
it starts checks the flag immediately and does nothing if it's off, so
functionally the flag still holds, but you'll still see the persistent
"KinRemind is running" notification. To remove that too, comment out the
`<receiver android:name=".BootCompletedReceiver">` block in
`android/app/src/main/AndroidManifest.xml`.

## The core spine — not flagged, on purpose

These four are what the app *is*; making them toggleable would just be a
way to break the app, not triage it:

| Module | Folder | Job |
|---|---|---|
| Auth | `lib/auth/` | Pick your name, enter your PIN, cache the session |
| Reminders | `lib/reminders/` | Owner CRUD screens + member's list |
| Alarms | `lib/alarms/` | Schedule/cancel exact AlarmManager alarms |
| Notifications | `lib/notifications/` | The full-screen alarm itself, Dismiss/Snooze |

If one of these is the thing that's broken, the fix is a real code
change, not a flag flip. But each one is still self-contained — a bug in
`lib/reminders/reminder_form_screen.dart` can't reach into
`lib/alarms/alarm_scheduler.dart`'s internals, they only talk through the
small public methods each module exposes (`ReminderRepository`,
`AlarmScheduler.schedule()`/`.cancel()`, etc.). If you need to rip one out
entirely for a fork or an experiment, start from its folder and follow the
imports outward — every cross-module dependency is a plain `import
'../other_module/thing.dart'` at the top of the file, nothing hidden in
generated code or reflection.

## Shared, not a "module"

`lib/core/` isn't a feature — it's the plumbing every module leans on:

- `constants.dart` — every Firestore collection name, SharedPreferences
  key, platform-channel name, and duration, in one place. If you're
  hunting for "what's this collection called", it's here.
- `feature_flags.dart` — the three switches above.
- `theme/` — `AppColors`, `AppSpacing`, `AppTextStyles`, `AppIcons`,
  `AppTheme`. Change the app's color, icon set, or spacing scale from one
  file each instead of hunting through every screen.
- `widgets/` — small widgets shared across screens (currently just
  `ErrorStateView`, the "couldn't load, here's why" view every
  Firestore-backed screen uses).

## Verifying things actually work: the test-alarm button

Because most of what this app promises (full-screen alarms through
silent mode, background survival, OEM autostart) can't be verified by
`flutter analyze` or a unit test — it needs a real device — there's a
"Send test alarm" button built in for exactly this: the last step of
onboarding, and a bell icon in the app's top bar for re-checking any time
later. See `NotificationService.showTestAlarm()` in
`lib/notifications/notification_service.dart`. Reach for that first
before assuming a module is broken — half the time "it's not working" on
a new device just means one of the four onboarding permissions got
silently revoked, which the test alarm surfaces immediately.
