# 🌊 FloodSense — Autonomous Flood Disaster Response
> **GovTech Malaysia 2026 | Track 2: Citizens First**

---

## 🔗 Live Deployment (Google Cloud Run)

| | URL |
|---|---|
| 🌐 **Web Application** | https://floodsense-app-653167130543.asia-southeast1.run.app |
| 📊 **Command Centre Dashboard** | https://floodsense-dashboard-653167130543.asia-southeast1.run.app |
| ☁️ **AI Backend API** | https://floodsense-agents-653167130543.asia-southeast1.run.app |

> All services are publicly accessible on Google Cloud Run — **no login required** for the main app.
> Government portal access code: **`9999`**

---

## 🎯 What is FloodSense?

FloodSense is an end-to-end autonomous disaster response system that transitions from reactive manual coordination into **fully autonomous AI execution**. It connects Citizens, Volunteers, and Government commanders in real-time during flood emergencies.

**Key capabilities:**
- **Autonomous SOS Triage** — Gemini 2.0 parses distress submissions and routes them to NADMA/APM instantly
- **AI Damage Claims** — Citizens file RM 5,000 BWI claims with AI-based evidence verification (no manual JKM review)
- **Live Volunteer Coordination** — Real-time GPS dispatch and mission tracking across all roles
- **AI Situation Reports** — Coordinator Agent auto-generates SitReps for government commanders
- **Bilingual Safety AI** — Grounded chat assistant (BM/EN) based on MKN Directive 20

---

## 🏗 Architecture

```
Flutter Web App (Cloud Run) ──┐
Next.js Dashboard (Cloud Run) ─┼──► Firebase Firestore ◄──► FastAPI AI Agents (Cloud Run)
                               │                              Gemini 2.0 Flash / Pro
```

**Stack:**
- **Frontend:** Flutter (Web), Next.js
- **Backend:** Python, FastAPI, Google GenAI SDK (Gemini 2.0)
- **Database:** Firebase Cloud Firestore
- **Hosting:** Google Cloud Run (3 independent services)

---

## 🎬 Testing the App (Judges)

Open the **[Web Application](https://floodsense-app-653167130543.asia-southeast1.run.app)** and select a role:

| Role | How to Access | What to Test |
|---|---|---|
| 🏠 **Citizen** | Tap "Warganegara" | Submit SOS with GPS, file a damage claim |
| 🤝 **Volunteer** | Tap "Sukarelawan" | Browse SOS map, accept & complete a mission |
| 🏛 **Government** | Tap "Pusat Arahan" → Code: `9999` | View live SOS cases, generate AI SitRep |

For the **Command Centre**, visit the [Dashboard](https://floodsense-dashboard-653167130543.asia-southeast1.run.app) directly.

---

## 🛠 Setup & Local Development

### Prerequisites
- Flutter SDK 3.24+
- Python 3.11+
- Node.js 18+
- Firebase project with Firestore enabled

### 1. Clone the repo
```bash
git clone https://github.com/yapyap06/FloodSense.git
cd FloodSense
```

### 2. AI Backend
```bash
cd agents
pip install -r requirements.txt
export GEMINI_API_KEY="your-key"
uvicorn agent_server:app --reload
```

### 3. Web App (Flutter)
```bash
cd mobile
flutter pub get
flutter run -d chrome
```

### 4. Dashboard (Next.js)
```bash
cd dashboard
npm install
cp .env.example .env.local   # fill in your Firebase & Gemini keys
npm run dev
```

> **Note:** Firebase config files (`google-services.json`, `firebase_options.dart`) are excluded for security. You will need to connect your own Firebase project for local development. The live Cloud Run deployments are fully configured.

---

## 🤖 Google AI Tools Used

| Tool | Purpose |
|---|---|
| **Gemini 2.0 Flash** | Citizen Agent (SOS triage), Resource Agent |
| **Gemini 2.0 Pro** | Coordinator Agent (SitRep generation) |
| **Google Cloud Run** | Hosts all 3 services (Web App, Dashboard, API) |
| **Firebase Firestore** | Real-time message bus across all user roles |
| **Antigravity (DeepMind)** | AI pair-programming assistant used in development |

---

## 📁 Repository Structure

```
FloodSense/
├── mobile/          # Flutter Web App (Citizen + Volunteer)
├── dashboard/       # Next.js Government Command Centre
├── agents/          # Python FastAPI Multi-Agent AI Backend
├── firestore.rules  # Database security rules
└── README.md
```

---

## 🤖 AI Disclosure

This project was developed using a human-AI pair programming workflow with **Google Gemini / Antigravity**. All architectural decisions, disaster response logic, and system integration were designed and validated by the human team.
