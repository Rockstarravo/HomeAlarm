# Quick start — running your own instance

This walks through setting up KinRemind for your own family, start to
finish. It assumes no prior Firebase or Flutter experience. Budget about
30–45 minutes the first time; it's mostly clicking through the Firebase
console.

## Step 1 — Install the tools

You need two things on your computer:

- **Flutter** ([install guide](https://docs.flutter.dev/get-started/install)) — run `flutter doctor` afterward and make sure Android tooling shows a checkmark.
- **The FlutterFire CLI** — once Flutter is installed: `dart pub global activate flutterfire_cli`.

## Step 2 — Get the code

```
git clone <your fork's URL>
cd kinremind
```

## Step 3 — Create your Firebase project

1. Go to the [Firebase console](https://console.firebase.google.com) → **Add project**.
2. Give it any name (e.g. "Our Family Reminders"). Google Analytics is not needed — turn it off.
3. Pick the free **Spark** plan (it's the default — you don't need to do anything to get it).
4. Once created, open **Build → Firestore Database → Create database**. Start in **production mode**. Pick any region close to your family.

## Step 4 — Connect the app to your project

From the repo root:

```
flutterfire configure
```

- Pick the Firebase project you just made.
- When asked which platforms, select **Android only**.
- This writes two files: `lib/firebase_options.dart` and `android/app/google-services.json`. Both are specific to your project and already excluded from git — don't worry about accidentally committing them.

## Step 5 — Add your family

Every person needs an entry in Firestore before they can log in — there's
no sign-up screen. See **[firebase/seed_members.md](../firebase/seed_members.md)**
for two ways to do this (console, or a script). Takes about 5 minutes for
a family of 5. Make sure exactly one person is marked `"owner"`.

## Step 6 — Deploy the security rules

Still from the repo root:

```
firebase deploy --only firestore
```

(If this is your first time using the `firebase` CLI: `npm install -g firebase-tools`, then `firebase login`.)

## Step 7 — Build the APK

```
flutter pub get
flutter build apk --release
```

The finished file is at `build/app/outputs/flutter-apk/app-release.apk`.
This is a normal Android APK — this build is signed with Flutter's debug
key, which is fine for sharing privately with your own family. See
**[03-modules.md](./03-modules.md)** if you want your own signing key later.

## Step 8 — Get it onto everyone's phone

Share the APK file however is easiest — a cloud drive link, USB cable,
messaging app. On each phone, they'll need to allow "install unknown
apps" for whatever app they open the file with (Android will prompt for
this automatically the first time).

## Step 9 — Walk through onboarding together

The first time the app opens, it asks for a few permissions and ends with
a **"Send test alarm"** button — have each person tap it and confirm they
actually hear/see the alarm, including with the phone on silent. This is
the single most important step: it catches OEM-specific quirks
(Xiaomi/Oppo/Vivo/etc. background restrictions) immediately, rather than
someone discovering their phone never rings weeks later.

## You're done

The owner can now create reminders from any device; a bell icon in the
top-right of the app lets anyone re-send themselves a test alarm any time
— useful if a reminder mysteriously stops ringing after a phone update.

**Something not working?** See **[04-troubleshooting.md](./04-troubleshooting.md)**.
