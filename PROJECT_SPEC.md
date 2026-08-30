# KinRemind — Cross-Device Family Reminder App
*(working name — rename freely; referenced as KinRemind throughout this doc)*

## 1. Problem Statement

People who live away from family — especially remote workers, or anyone whose parents/relatives live elsewhere — struggle to reliably remind loved ones about recurring things: taking medicine, daily routines, or one-off occasions. A note or a phone call doesn't scale daily, and generic reminder apps only remind *you*, not someone else, and don't survive silent mode or a locked phone.

KinRemind lets one person (the owner) set reminders that fire as loud, alarm-style notifications directly on a family member's phone — regardless of silent mode — with real-time sync so reminders can be created or edited from anywhere.

## 2. Vision — Open Source

This is being built as an open-source project because the problem is common to nearly every family with a remote member. The goal is for **any family to clone the repo, spin up their own free Firebase backend, and run their own private instance** — not a single shared hosted service.

**Locked decision:** This is a self-hosted, per-family deployment model, not a multi-tenant SaaS.
- Each family/deployer creates their own Firebase project (free Spark tier).
- Data is fully isolated per deployment — no shared backend, no cross-family data exposure.
- Cost stays at zero regardless of how many families adopt the project, since each runs independently.
- Trade-off accepted: onboarding a new family requires some technical setup (Firebase project creation, `flutterfire configure`, editing a members config). This is acceptable for v1; a more turnkey setup experience is a roadmap item (Section 13).

## 3. Locked MVP Scope

- **Platform:** Android only for MVP. iOS is roadmap (requires paid Apple Developer account for sideload/Ad Hoc distribution — out of scope for zero-cost phase).
- **Distribution:** Direct APK sideload (`flutter build apk --release`), no Play Store.
- **Users per deployment:** 1 owner + 3–5 non-owner family members (configurable, not hardcoded to a number).
- **Auth:** Static, config-based. No Firebase Auth, no sign-up flow, no OTP. Each deployment seeds a `members` collection (name + PIN) during setup; users pick their name and enter their PIN on first launch.
- **Backend:** Firebase Firestore only (Spark/free tier). No Cloud Functions, no FCM. Real-time sync handled entirely by Firestore listeners running inside the app on each device.
- **Notification delivery:** Requires the app to be running (foreground service) on each member's device — not relying on server-push. This is a deliberate trade-off for zero infrastructure cost.
- **Reminder behavior:** All reminders behave identically — full-screen alarm-style notification with Dismiss / Snooze (10 min, infinite, no cap) actions. No per-reminder configuration of this behavior in MVP.

## 4. Architecture Overview

```
Owner app (create/edit reminder)
        │  write
        ▼
Firestore "reminders" collection (realtime sync, free Spark tier)
        │  live push via open listener (websocket, NOT polling)
        ▼
Member device — foreground service holds Firestore listener
        │  on new/changed reminder assigned to this member
        ▼
AlarmManager — schedules exact OS-level alarm (STREAM_ALARM channel)
        │  at scheduled time
        ▼
Full-screen alarm notification — rings through silent/DND mode
        │
        ├─ [Dismiss] → write ack {status: "done"} to Firestore, alarm cleared
        └─ [Snooze 10m] → cancel current alarm, reschedule +10 min, repeat indefinitely until dismissed
```

Supplementary event-triggered flows (not part of the main loop, but required for reliability):
- **Boot receiver:** on `BOOT_COMPLETED`, re-pull all active reminders assigned to this member from Firestore and re-register alarms (AlarmManager alarms don't survive reboot).
- **Permission self-check:** on every app open/resume, verify `SCHEDULE_EXACT_ALARM` and battery-optimization exemption are still granted; re-prompt if revoked.
- **WorkManager health-check (polling — the only true polling in this system):** every 15 minutes (Android's enforced floor for periodic work) while the app is alive, verify the foreground service/listener is still active and that every active reminder has a corresponding scheduled alarm. Safety net only — the primary sync path is event-driven, not polled.

## 5. Tech Stack

- **Flutter** (Android target for MVP)
- `cloud_firestore` — database + realtime listeners
- `firebase_core` — Firebase bootstrap
- `android_alarm_manager_plus` — exact alarm scheduling
- `flutter_local_notifications` — full-screen notification + action buttons + background response handling
- `shared_preferences` — local session (selected memberId after static login)
- `workmanager` — periodic health-check safety net
- **No** Firebase Auth, **no** Cloud Functions, **no** FCM, **no** paid Firebase tier

## 6. Data Model (Firestore)

```
members/{memberId}
  name: string
  pin: string
  role: "owner" | "member"

reminders/{reminderId}
  title: string
  notes: string
  scheduleTime: string        // "HH:mm"
  recurrence: string          // "daily" | "one_time" | RRULE-style string
  targetMemberIds: [memberId, ...]
  createdBy: memberId
  isActive: boolean

reminders/{reminderId}/ack/{memberId}
  status: "pending" | "done"
  timestamp: server timestamp
```

## 7. Authentication Approach

- No dynamic sign-up. `members` collection is seeded manually per deployment (via Firebase console or a one-time seed script provided in the repo).
- First launch: user picks their name from the seeded list, enters their PIN, memberId is cached locally via `shared_preferences`.
- **Locked security trade-off:** Firestore security rules cannot cryptographically verify identity without real Auth. Rules will restrict reads/writes to the `members` and `reminders` collections structurally (valid memberId required in requests), but a technically motivated user with the APK could reverse-engineer the Firebase config (not secret by design) and access the family's own Firestore data. Acceptable for a private family tool; **do not store sensitive medical details in reminder text** if this is a concern. Real Auth is a roadmap item if broader trust boundaries are needed later.

## 8. Notification & Alarm Pipeline

- Alarms use `STREAM_ALARM` audio attributes (same mechanism real alarm-clock apps use) to ring through silent/DND mode.
- Every alarm notification shows two actions: **Dismiss** and **Snooze (10 min)**.
- **Dismiss:** cancels any pending alarm for that `reminderId`, writes `ack.status = "done"` to Firestore.
- **Snooze:** cancels the current notification, schedules a new one-time alarm at `now + 10 minutes`, same `reminderId`. No ack written — reminder stays "pending" in the owner's view.
- **Snooze repeats indefinitely** until Dismiss is tapped — no cap, no escalation, uniform behavior for all reminder types (locked decision — accepted trade-off that an unattended reminder will ring every 10 minutes indefinitely, including overnight).
- Button taps must work even if the app process is fully killed — implemented via `flutter_local_notifications`' background notification response callback (runs in a separate isolate, doesn't require the main app UI alive).
- On reminder edit (time changed by owner), the old alarm must be explicitly cancelled before scheduling the new one — never leave both active.

## 9. Permissions & OEM Handling

Required onboarding flow on first launch, before the app is considered "ready":
- Request `POST_NOTIFICATIONS` (Android 13+)
- Request `SCHEDULE_EXACT_ALARM` (Android 12+)
- Request battery-optimization exemption
- Detect device manufacturer (Xiaomi/Oppo/Vivo/Samsung/etc.) and deep-link to the OEM-specific autostart/background-permission settings screen, since stock Android's battery exemption is insufficient on these OEM skins
- Re-verify all of the above on every app resume, not just at first launch (permissions can be silently revoked by the OS or user later)

## 10. Known Edge Cases & Mitigations (locked)

| Edge case | Mitigation |
|---|---|
| Device reboot clears scheduled alarms | Boot receiver re-registers all active reminders from Firestore |
| Exact alarm permission silently revoked | Re-check on every app resume, re-prompt if missing |
| OEM background killers (MIUI, ColorOS, etc.) | Manufacturer detection + deep-link to OEM autostart settings during onboarding |
| Foreground service silently dies | 15-min WorkManager health-check reschedules/restarts as needed |
| Same member logged in on 2 devices | Store a `deviceId` alongside `memberId` locally; both devices independently listen and schedule — duplicate alarms are an accepted MVP trade-off, not solved in v1 |
| Reminder timezone ambiguity (owner travels) | `scheduleTime` stored and interpreted as the **target member's local device time**, not the owner's location — locked decision, avoids timezone conversion complexity |
| Missed alarm (phone off during scheduled time) | On next boot/app-open, if scheduled time has passed and reminder is recurring, schedule the *next* occurrence — does not fire immediately as catch-up (locked decision, avoids notification spam on phone power-on) |

## 11. Suggested Repository Structure

```
kinremind/
├── android/
├── lib/
│   ├── main.dart
│   ├── auth/                 # static member picker + PIN
│   ├── reminders/            # CRUD screens (owner) + list view (member)
│   ├── sync/                 # Firestore listener + foreground service
│   ├── alarms/               # AlarmManager scheduling logic
│   ├── notifications/        # full-screen notification + action handlers
│   └── onboarding/           # permission + OEM setup flow
├── firebase/
│   └── seed_members.md       # instructions/script to seed initial members collection
├── firestore.rules
├── pubspec.yaml
├── README.md
├── LICENSE                   # MIT (suggested default for open-source adoption)
└── CONTRIBUTING.md
```

## 12. Per-Deployer Setup Instructions (for README)

1. Fork/clone the repo.
2. Create a new Firebase project (free Spark plan).
3. Enable Firestore in the console.
4. Run `flutterfire configure` to generate `firebase_options.dart` for your project.
5. Seed the `members` collection with your family's names + PINs (script/instructions in `firebase/seed_members.md`).
6. Deploy the provided `firestore.rules`.
7. `flutter build apk --release`, share the APK with family members, enable "install unknown apps" on each device.
8. Walk each member through the onboarding permission flow on first launch.

## 13. Build Plan (execution order for coding agent)

1. Set up Firebase project (Firestore, Spark plan, no Auth/Functions)
2. Scaffold Flutter project + add all dependencies from Section 5
3. Build static login (member picker + PIN)
4. Build reminder CRUD screens (owner view)
5. Build Firestore listener + foreground service (member device)
6. Implement alarm scheduling (AlarmManager, cancel-and-reschedule on edit)
7. Build full-screen alarm notification with Dismiss/Snooze actions + background response callback
8. Handle boot receiver + permission/OEM onboarding flow
9. Add 15-min WorkManager health-check
10. Build, sideload, and test end-to-end across multiple physical devices

## 14. Roadmap (post-MVP, not part of current locked scope)

- iOS support via Ad Hoc distribution or TestFlight (requires paid Apple Developer account)
- Self-serve family onboarding (invite codes) to reduce technical setup barrier for open-source adopters
- Real Firebase Auth if broader trust/security boundaries are needed
- Per-reminder snooze/escalation configuration (if community requests it)
- Attachment support (voice notes/images) via Firebase Storage
- Optional migration path to Cloud Functions + FCM for true server-push (would require Blaze plan — opt-in per deployment, not default)

## 15. License & Contribution

- **Suggested license: MIT** — permissive, encourages the widest possible family adoption and forking. Can be changed by the repo owner before publishing.
- `CONTRIBUTING.md` should cover: how to seed a test Firebase project for local development, code style, and how to submit PRs against the roadmap items above.
