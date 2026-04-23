// Seed a demo mission offer so the Volunteer tab has data to display
// Run: node seed-volunteer-demo.mjs
import { initializeApp } from 'firebase/app';
import { getFirestore, collection, addDoc, doc, setDoc } from 'firebase/firestore';
import { readFileSync } from 'fs';

// Read env file
const envFile = readFileSync('.env', 'utf8');
const env = Object.fromEntries(envFile.split('\n').filter(l => l.includes('=')).map(l => l.split('=').map(s => s.trim())));

const app = initializeApp({
  apiKey: env.FIREBASE_API_KEY,
  authDomain: `${env.FIREBASE_PROJECT_ID}.firebaseapp.com`,
  projectId: env.FIREBASE_PROJECT_ID,
  storageBucket: `${env.FIREBASE_PROJECT_ID}.firebasestorage.app`,
  messagingSenderId: '42185468764',
  appId: '1:42185468764:web:63eddd829a43591821ef99',
});

const db = getFirestore(app);

// 1. Seed demo volunteer profile
await setDoc(doc(db, 'volunteers', 'VOL_DEMO_001'), {
  name: 'Ahmad Farid Demo',
  phone: '+60123456789',
  skills: ['boat_operator', 'first_aid_L1', 'malay', 'english'],
  vehicle_type: 'boat',
  vehicle_capacity: 8,
  standing_consent: true,
  status: 'AVAILABLE',
  apm_verified: false,
});

// 2. Seed a demo mission offer
const missionRef = await addDoc(collection(db, 'mission_offers'), {
  volunteer_id: 'VOL_DEMO_001',
  sos_id: 'SOS-DEMO-001',
  status: 'OFFERED',
  address: 'No 47 Jalan Meranti, Kampung Baru, KL',
  distance_km: 2.3,
  head_count: 5,
  vulnerable: ['infant', 'elderly'],
  volunteer_name: 'Ahmad Farid Demo',
  created_at: new Date().toISOString(),
});

console.log(`✅ Demo volunteer created: VOL_DEMO_001`);
console.log(`✅ Demo mission offer created: ${missionRef.id}`);
console.log('\nRun the Flutter app and check the Sukarela tab!');
process.exit(0);
