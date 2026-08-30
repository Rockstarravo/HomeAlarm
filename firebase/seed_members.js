#!/usr/bin/env node
/**
 * One-time seed script for the `members` collection (PROJECT_SPEC.md
 * section 7 — there is no sign-up flow, this is the only way members get
 * created). Run once per deployment after Firestore is enabled.
 *
 * Usage:
 *   npm install firebase-admin
 *   node firebase/seed_members.js path/to/serviceAccountKey.json firebase/members.json
 *
 * Where members.json is a copy of members.example.json edited with your
 * own family's names, PINs, and roles ("owner" | "member"). `id` becomes
 * the Firestore document id and what the app stores locally after login —
 * keep it a short, stable, lowercase slug (no spaces).
 */

const fs = require('fs');
const path = require('path');

const [, , serviceAccountPath, membersPath] = process.argv;

if (!serviceAccountPath || !membersPath) {
  console.error('Usage: node firebase/seed_members.js <serviceAccountKey.json> <members.json>');
  process.exit(1);
}

const admin = require('firebase-admin');

const serviceAccount = JSON.parse(fs.readFileSync(path.resolve(serviceAccountPath), 'utf8'));
const members = JSON.parse(fs.readFileSync(path.resolve(membersPath), 'utf8'));

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

async function seed() {
  const owners = members.filter((m) => m.role === 'owner');
  if (owners.length !== 1) {
    throw new Error(`Expected exactly one member with role "owner", found ${owners.length}.`);
  }

  const batch = db.batch();
  for (const member of members) {
    if (!member.id || !member.name || !member.pin || !member.role) {
      throw new Error(`Member entry missing a required field: ${JSON.stringify(member)}`);
    }
    const ref = db.collection('members').doc(member.id);
    batch.set(ref, { name: member.name, pin: String(member.pin), role: member.role });
  }
  await batch.commit();
  console.log(`Seeded ${members.length} member(s) into Firestore.`);
}

seed().catch((err) => {
  console.error(err);
  process.exit(1);
});
