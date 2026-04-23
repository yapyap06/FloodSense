/**
 * FloodSense Firestore Seed Script
 * Seeds real Firestore with demo data so the dashboard shows LIVE mode.
 * Run: node seed-firestore.js
 *
 * Uses the Firebase Web SDK (same config as dashboard — no service account needed).
 */

import { initializeApp } from "firebase/app";
import {
  getFirestore,
  collection,
  addDoc,
  serverTimestamp,
  Timestamp,
} from "firebase/firestore";

const firebaseConfig = {
  apiKey:            "YOUR_FIREBASE_API_KEY",
  authDomain:        "floodsense-app.firebaseapp.com",
  projectId:         "floodsense-app",
  storageBucket:     "floodsense-app.firebasestorage.app",
  messagingSenderId: "42185468764",
  appId:             "1:42185468764:web:63eddd829a43591821ef99",
};

const app = initializeApp(firebaseConfig);
const db  = getFirestore(app);

// Helper: timestamp N seconds ago
const ago = (s) => Timestamp.fromMillis(Date.now() - s * 1000);

async function seed() {
  console.log("🌊 FloodSense — Seeding Firestore...\n");

  // ── 1. Flood Alert ─────────────────────────────────────────────────────────
  const alertRef = await addDoc(collection(db, "alerts"), {
    alert_id:    "ALT-DEMO001",
    district_id: "Klang Valley",
    severity:    "DANGER",
    river_level_m:      5.8,
    predicted_depth_cm: 80,
    confidence:         0.91,
    time_to_impact_hours: 2.5,
    reasoning: "Sg Klang at Jalan Raja Laut gauge crossed 5.8m — 0.4m above alert threshold. Rising at 2cm/hr with 85mm rainfall recorded in last 6 hours.",
    recommended_actions: [
      "Activate PPS shelters in KL & Selangor",
      "Deploy Bomba boats to Sri Muda",
      "Issue SMS + WhatsApp alert to Klang Valley subscribers"
    ],
    kampung_ids: ["KG_SRI_MUDA", "KG_DATO_KERAMAT"],
    created_at: serverTimestamp(),
  });
  console.log(`✅ Alert created: ${alertRef.id}`);

  // ── 2. SOS Incidents ───────────────────────────────────────────────────────
  const incidents = [
    {
      sos_id:       "SOS-A3B7C1",
      urgency:      "CRITICAL",
      status:       "PENDING",
      head_count:   5,
      vulnerable:   ["infant", "wheelchair"],
      address_text: "No 47 Jalan Meranti, Kampung Baru, KL",
      location:     { lat: 3.1638, lng: 101.7010 },
      channel:      "APP",
      battery_pct:  5,
      language:     "ms",
      district_id:  "Kuala Lumpur",
      created_at:   ago(180),
    },
    {
      sos_id:       "SOS-D4E8F2",
      urgency:      "CRITICAL",
      status:       "DISPATCHED",
      head_count:   2,
      vulnerable:   ["elderly"],
      address_text: "Taman Sri Muda, Seksyen 25, Shah Alam",
      location:     { lat: 3.0734, lng: 101.5183 },
      channel:      "SMS",
      battery_pct:  44,
      language:     "ms",
      district_id:  "Selangor",
      assigned_unit_id: "VOL_001",
      created_at:   ago(540),
    },
    {
      sos_id:       "SOS-G9H1I3",
      urgency:      "HIGH",
      status:       "PENDING",
      head_count:   7,
      vulnerable:   [],
      address_text: "Taman Mawar, Klang",
      location:     { lat: 3.0449, lng: 101.4483 },
      channel:      "WHATSAPP",
      battery_pct:  78,
      language:     "en",
      district_id:  "Selangor",
      created_at:   ago(90),
    },
    {
      sos_id:       "SOS-J2K5L6",
      urgency:      "MEDIUM",
      status:       "RESCUED",
      head_count:   3,
      vulnerable:   [],
      address_text: "Brickfields, Kuala Lumpur",
      location:     { lat: 3.1313, lng: 101.6869 },
      channel:      "APP",
      battery_pct:  100,
      language:     "en",
      district_id:  "Kuala Lumpur",
      created_at:   ago(1800),
    },
  ];

  for (const inc of incidents) {
    const ref = await addDoc(collection(db, "incidents"), inc);
    console.log(`✅ Incident ${inc.sos_id} (${inc.urgency}) → ${ref.id}`);
  }

  // ── 3. Sitrep ──────────────────────────────────────────────────────────────
  const sitrepRef = await addDoc(collection(db, "sitreps"), {
    sitrep_id:       "SITREP-DEMO01",
    district_id:     "Klang Valley",
    severity:        "DANGER",
    active_sos:      2,
    dispatched:      1,
    resolved:        1,
    volunteers_active: 1,
    generated_at:    serverTimestamp(),
    content: `SITUATION
Water levels at Sg Klang (Jalan Raja Laut gauge) have risen to 5.8m — 0.4m above the alert threshold. Rising rate is 2cm/hour. Peak predicted at approximately 21:30 tonight.

RESCUE OPERATIONS
3 active SOS cases — 1 CRITICAL (infant + wheelchair in Kampung Baru). 1 rescue dispatched (Volunteer Ahmad Farid en route to Sri Muda). 1 case resolved (Brickfields). 2 unassigned CRITICAL cases require immediate Bomba deployment.

RESOURCE STATUS
Volunteers available: 2 of 3 registered. Power banks at 40 units — below 50-unit threshold. Food and water stocks sufficient for 48h. Baby formula stock critically low (15 cans).

RECOMMENDED ACTIONS
• Deploy Bomba Boat Unit 7 to No 47 Jalan Meranti (infant + wheelchair — CRITICAL)
• Open PPS Stadium Shah Alam — estimated need 400–600 displaced persons
• Request emergency power bank resupply from NADMA warehouse WH_SEL_001`,
  });
  console.log(`✅ Sitrep created: ${sitrepRef.id}`);

  // ── 4. Volunteers ──────────────────────────────────────────────────────────
  const volunteers = [
    {
      volunteer_id: "VOL_001",
      name: "Ahmad Farid bin Ismail",
      phone: "+60112345678",
      skills: ["boat", "first_aid", "malay", "english"],
      vehicle: "boat",
      readiness_toggle: true,
      standing_consent: true,
      status: "ON_MISSION",
      apm_verified: true,
      missions_completed: 12,
      current_mission: "SOS-D4E8F2",
      location: { lat: 3.0800, lng: 101.5300 },
    },
    {
      volunteer_id: "VOL_002",
      name: "Lim Wei Chen",
      phone: "+60123456789",
      skills: ["medic", "mandarin", "english", "driving"],
      vehicle: "4wd",
      readiness_toggle: true,
      standing_consent: true,
      status: "AVAILABLE",
      apm_verified: true,
      missions_completed: 8,
      location: { lat: 3.1500, lng: 101.7100 },
    },
  ];
  for (const v of volunteers) {
    const ref = await addDoc(collection(db, "volunteers"), v);
    console.log(`✅ Volunteer ${v.name} → ${ref.id}`);
  }

  // ── 5. Shelters ────────────────────────────────────────────────────────────
  const shelters = [
    { shelter_id: "PPS_001", name: "SK Kampung Baru, KL",      capacity: 500,  occupancy: 0,  is_open: true,  district_id: "Kuala Lumpur", location: { lat: 3.1638, lng: 101.7011 } },
    { shelter_id: "PPS_002", name: "Stadium Shah Alam",         capacity: 5000, occupancy: 0,  is_open: false, district_id: "Selangor",     location: { lat: 3.0634, lng: 101.5092 } },
    { shelter_id: "PPS_003", name: "Dewan Serbaguna Klang",     capacity: 1200, occupancy: 0,  is_open: false, district_id: "Selangor",     location: { lat: 3.0449, lng: 101.4483 } },
  ];
  for (const s of shelters) {
    const ref = await addDoc(collection(db, "shelters"), s);
    console.log(`✅ Shelter ${s.name} → ${ref.id}`);
  }

  console.log("\n🎉 Firestore seeded successfully! Refresh your dashboard to see LIVE data.");
  process.exit(0);
}

seed().catch((e) => {
  console.error("❌ Seed error:", e.message);
  process.exit(1);
});
