# Troubleshooting

## Build problems

**`flutter build apk` fails mentioning `google-services.json`**
You haven't run `flutterfire configure` yet, or it didn't complete — see
[01-quick-start.md, Step 4](./01-quick-start.md#step-4--connect-the-app-to-your-project).
This file is deployer-specific and deliberately not checked into git.

**Gradle fails on `local.properties` / `flutter.sdk not set`**
Run any `flutter` command once from the repo root (e.g. `flutter pub get`)
— the Flutter tool generates `android/local.properties` itself, pointing
at your local Flutter SDK. It's gitignored, so a fresh clone won't have
it yet.

**A plugin version conflict / dependency resolution error**
Run `flutter pub outdated` to see what's actually available, then bump
the specific package in `pubspec.yaml`. Don't run a blanket
`flutter pub upgrade --major-versions` without testing — some of the
plugins here (`android_alarm_manager_plus`, `flutter_local_notifications`)
have had breaking API changes across major versions that this codebase's
usage would need to follow.

## The app doesn't ring

Work through these in order — they're ordered by how often they're
actually the cause:

1. **Send a test alarm** (bell icon, top-right of the app) with the phone
   on silent. If this doesn't ring, it's a permission/OEM problem, not a
   bug in a specific reminder.
2. **Re-run onboarding's checks.** Reopen the app — it silently re-verifies
   all four permissions on every resume and will route back into
   onboarding if one was revoked (Android does this on its own sometimes,
   especially after a phone reboot or an OS update).
3. **OEM autostart.** On Xiaomi, Oppo, Vivo, Huawei, Samsung, OnePlus,
   Asus, or Letv phones specifically: the battery-optimization exemption
   alone is not enough — go to that manufacturer's own autostart/
   background-permission settings for KinRemind (onboarding tries to deep
   link there automatically, but ROM updates can move that screen; see
   `lib/onboarding/oem_settings.dart` for the full list of settings
   screens this app knows about).
4. **Check the reminder is actually assigned to that person** — open the
   owner's "Manage" tab and confirm their name is checked for that
   reminder, and the reminder's toggle is on.

## A reminder created by the owner never shows up on a member's phone

This means the Firestore listener isn't reaching that device. Check, in
order:

1. Is that phone's app fully onboarded (see above)?
2. Is `firestore.rules` actually deployed (`firebase deploy --only
   firestore`)? If not, Firestore falls back to deny-all and nothing
   syncs, silently.
3. Is the composite index in `firestore.indexes.json` deployed? Without
   it, the query the app runs (`targetMemberIds` contains X, `isActive` ==
   true) throws — check the Firebase console's Firestore → Indexes tab.

## Someone's PIN doesn't work

PINs are seeded manually — see
[`firebase/seed_members.md`](../firebase/seed_members.md). If someone
needs a new PIN, edit their document directly in the Firebase console
(Firestore Database → `members` → their document → edit the `pin`
field). There's no in-app way to change it in this MVP.

## Still stuck

Check [PROJECT_SPEC.md](../PROJECT_SPEC.md)'s edge-case table (section
10) — several rough edges (duplicate alarms on two devices for the same
person, a missed alarm not catching up immediately, timezone handling)
are documented, locked-in trade-offs for this MVP rather than bugs.
