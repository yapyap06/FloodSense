// Firebase client config for Next.js (browser-side)
// Safe to run without keys — dashboard falls back to demo data
import { initializeApp, getApps, type FirebaseApp } from "firebase/app";
import { getFirestore, type Firestore } from "firebase/firestore";

const apiKey = process.env.NEXT_PUBLIC_FIREBASE_API_KEY;

// Only init Firebase if keys are provided — otherwise return null safely
function createApp(): FirebaseApp | null {
  if (!apiKey || apiKey === "your_firebase_api_key") return null;
  if (getApps().length > 0) return getApps()[0];
  return initializeApp({
    apiKey,
    authDomain:        process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
    projectId:         process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
    storageBucket:     process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
    messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
    appId:             process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
  });
}

const app = createApp();
export const db: Firestore | null = app ? getFirestore(app) : null;

// Connect to Firestore emulator in dev
if (
  typeof window !== "undefined" &&
  db &&
  process.env.NEXT_PUBLIC_USE_EMULATOR === "true"
) {
  import("firebase/firestore").then(({ connectFirestoreEmulator }) => {
    try {
      connectFirestoreEmulator(db as Firestore, "localhost", 8080);
    } catch (_) {}
  });
}

export default app;

