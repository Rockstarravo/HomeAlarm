# Seeding the `members` collection

KinRemind has no sign-up flow (PROJECT_SPEC.md section 7). Every family
member who will use the app has to already exist as a document in the
`members` collection before anyone can log in. This is a one-time step
per deployment, done by whoever set up the Firebase project.

Each member document looks like:

```
members/{memberId}
  name: string
  pin:  string   // whatever length/format you like, just don't reuse a real password
  role: "owner" | "member"   // exactly one member must be "owner"
```

`{memberId}` is the Firestore document id — pick a short, stable, lowercase
slug (`mom`, `dad`, `grandma-may`). It's what gets cached on each phone
after login and what reminders reference in `targetMemberIds`, so avoid
renaming it later.

## Option A — Firebase console (fastest for 1–5 people)

1. Open your project in the [Firebase console](https://console.firebase.google.com) → Firestore Database.
2. Create a collection named `members`.
3. For each family member, add a document with the id you chose and the
   three fields above.
4. Make sure exactly one document has `role: "owner"`.

## Option B — seed script (faster if you're re-seeding a test project often)

1. Generate a service account key: Firebase console → Project settings →
   Service accounts → **Generate new private key**. Keep this file out of
   git — it's a full-access credential for your project.
2. Copy `firebase/members.example.json` to `firebase/members.json` and
   edit it with your family's real names, PINs, and roles.
3. From the repo root:
   ```
   npm install firebase-admin
   node firebase/seed_members.js path/to/serviceAccountKey.json firebase/members.json
   ```

Either way, after seeding: deploy `firestore.rules` and
`firestore.indexes.json` (`firebase deploy --only firestore`) before
sideloading the app — the member query the app runs needs the composite
index in `firestore.indexes.json` to exist, and without deployed rules the
project falls back to Firestore's default deny-all rules.
