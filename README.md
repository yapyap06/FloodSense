# 🌊 FloodSense — Autonomous Flood Disaster Response (GovTech Malaysia 2026)

> **Track 2: Citizens First (GovTech & Digital Services)**

---

## 🔗 Live Deployments (Google Cloud Run)

All components are hosted on **Google Cloud Run** — no installation required.

| Application | URL |
|---|---|
| 🌐 **Citizen & Volunteer Web App** | [https://floodsense-app-653167130543.asia-southeast1.run.app](https://floodsense-app-653167130543.asia-southeast1.run.app) |
| 📊 **Government Command Centre Dashboard** | [https://floodsense-dashboard-653167130543.asia-southeast1.run.app](https://floodsense-dashboard-653167130543.asia-southeast1.run.app) |
| ☁️ **Multi-Agent AI Backend API** | [https://floodsense-agents-653167130543.asia-southeast1.run.app](https://floodsense-agents-653167130543.asia-southeast1.run.app) |
| 📖 **Interactive API Docs (Swagger UI)** | [https://floodsense-agents-653167130543.asia-southeast1.run.app/docs](https://floodsense-agents-653167130543.asia-southeast1.run.app/docs) |
| 💻 **GitHub Repository** | [github.com/yapyap06/FloodSense](https://github.com/yapyap06/FloodSense) |

---

## 🎯 Problem Statement

Malaysia experiences devastating annual monsoon floods affecting millions of citizens. The current system suffers from:
- **Manual SOS processing** — rescue teams overwhelmed by unstructured distress messages
- **Bureaucratic aid claims** — JKM damage claim verification takes weeks
- **Zero real-time coordination** — volunteers and government agencies operate in silos
- **No proactive intelligence** — no system autonomously generates situational awareness for NADMA commanders

## 💡 Our Solution

FloodSense is an end-to-end autonomous agentic Government Technology solution that transitions disaster response from reactive "Chat" layers into fully **Autonomous Execution (Action)** via a Multi-Agent AI system built on the Google AI Ecosystem.

## 🏆 The Google AI Ecosystem Stack

This project was engineered exclusively on the Google AI Ecosystem Stack for the 2026 GovTech Challenge:

1. **The Intelligence (Brain): Gemini 2.0**
   - **Gemini 2.0 Flash:** Powers the **Citizen Agent** to handle real-time SOS triage and emergency data extraction (parsing GPS strings, routing requests, extracting headcounts).
   - **Gemini 2.0 Pro:** Powers the **Coordinator Agent** to generate comprehensive, multi-variable incident Situation Reports (SitReps) and perform complex supply-chain distribution modeling.

2. **The Orchestrator: Multi-Agent AI Workflows**
   - **Agentic Routing:** A system of specialized autonomous agents (Citizen Agent, Coordinator Agent, Resource Agent) that interact through Firebase Cloud Firestore as a message bus, ensuring high reliability in low-connectivity zones.
   - **Zero-Friction SOS:** Optimized for high-stress environments. The frontend focuses on instant data capture (GPS + Situation), while the backend Agent handles the complex triage autonomously.

3. **The Context: Grounded Execution**
   - **Retrieval-Augmented Generation (RAG):** The Chat AI and Command Assistant pull explicitly from vetted national civil defense (APM) and social welfare (JKM) SOP datasets (MKN Directive 20) to ground their safety instructions.

4. **The Infrastructure: Google Cloud Run**
   - All three components (Citizen/Volunteer Web App, Command Centre Dashboard, and AI Backend) are hosted on **Google Cloud Run** as separate serverless, stateless containers.
   - **Firebase / GCP:** Firestore acts as the real-time operational database synchronizing actions across all 3 user-role applications in real time.

## 🚀 Core Features

FloodSense is fundamentally **not** a chatbot. It is a system of autonomous execution.

1. **Autonomous SOS Triage:** A citizen submits a frantic distress request. The **Citizen Agent** autonomously parses the telemetry and selection data via Gemini 2.0, extracting `{headcount: 2, vulnerable: true, address: "Kg Meru", urgency: "CRITICAL"}` and routes it to the correct agency (NADMA/APM).
2. **Crisis-Ready UI:** Real-time location pinning and status tracking that updates in milliseconds via Firestore, even on older 4G/LTE handsets.
3. **AI-Orchestrated Damage Claims:** Bypassing manual JKM verification. Citizens file claims for the RM 5,000 BWI scheme using a 100% evidence-based wizard. The **Agentic Audit** system identifies claim items and verifies them against government aid bands (Band A/B) instantly.
4. **Government Command AI:** The **Coordinator Agent** executes independent loops in the background — evaluating active SOS cases against volunteer locations and generating live Situation Reports for NADMA commanders.
5. **Multi-Lingual Safety Chat AI:** A conversational assistant that provides grounded, localized safety protocols in BM and English to ensure every citizen stays safe.

## 🏗 Architectural Overview

The FloodSense architecture uses Firebase Cloud Firestore as an ultra-low latency real-time message bus that synchronizes the web application directly with the Python Multi-Agent Backend.

![Functional Diagram](./func_diagram.png)

```mermaid
graph TD
    subgraph Frontend [Web Applications - Flutter & Next.js on Cloud Run]
        C[Citizen App]
        V[Volunteer App]
        G[Government Command Centre]
    end

    subgraph Database [BaaS Cloud Layer]
        FS[(Firestore Real-Time DB)]
    end

    subgraph Backend [Google Cloud Run - Multi-Agent Backend]
        CA[Citizen Agent<br>Gemini 2.0 Flash]
        CO[Coordinator Agent<br>Gemini 2.0 Pro]
        RA[Resource Agent<br>Gemini 2.0 Flash]
    end

    C <--> |Live Tracking / Requests| FS
    V <--> |Live GPS Stream| FS
    G <--> |Dashboard Auditing| FS

    FS <--> |Triggers & Payloads| CA
    FS <--> |SitReps & Data| CO
    FS <--> |Predictions| RA
```

## 💻 Tech Stack
* **Frontend:** Flutter (Web), Next.js (Web Dashboard)
* **Backend:** Python (FastAPI, Smolagents, Google GenAI SDK)
* **Database & BaaS:** Firebase Cloud Firestore
* **AI Models:** Gemini 2.0 Flash, Gemini 2.0 Pro
* **Hosting:** Google Cloud Run (all 3 services)

## 🛠️ Google Developer Tools Used

| Tool | Role in FloodSense |
|---|---|
| **Gemini 2.0 Flash** | Powers Citizen Agent (SOS triage) and Resource Agent (supply modeling) |
| **Gemini 2.0 Pro** | Powers Coordinator Agent (SitRep generation and incident analytics) |
| **Firebase Cloud Firestore** | Real-time message bus syncing all 3 web apps with the AI backend |
| **Firebase Authentication** | Secure role-based access for Citizens, Volunteers, and Government officers |
| **Google Cloud Run** | Serverless container hosting for all 3 components (Web App, Dashboard, API) |
| **Google Cloud Build** | CI/CD pipeline for automated Docker image builds and deployments |
| **Google AI SDK (Python)** | `google-generativeai` library powering all Gemini agent calls |
| **Antigravity (by Google DeepMind)** | AI pair programming assistant used throughout the development lifecycle |

---

## ☁️ Cloud Run Services

All three services are independently deployed and publicly accessible:

### 1. 🌐 Citizen & Volunteer Web App
> **URL:** [`https://floodsense-app-653167130543.asia-southeast1.run.app`](https://floodsense-app-653167130543.asia-southeast1.run.app)
>
> Built with **Flutter Web** and served via Nginx on Cloud Run. Contains the full Citizen SOS flow and Volunteer mission management interface.

### 2. 📊 Government Command Centre Dashboard
> **URL:** [`https://floodsense-dashboard-653167130543.asia-southeast1.run.app`](https://floodsense-dashboard-653167130543.asia-southeast1.run.app)
>
> Built with **Next.js** on Cloud Run. Provides real-time SOS case monitoring, AI-generated SitReps via Gemini, and volunteer coordination for government officers.
>
> Access Code: `9999`

### 3. ☁️ Multi-Agent AI Backend
> **URL:** [`https://floodsense-agents-653167130543.asia-southeast1.run.app`](https://floodsense-agents-653167130543.asia-southeast1.run.app)
>
> **Swagger UI:** [`/docs`](https://floodsense-agents-653167130543.asia-southeast1.run.app/docs)

| Endpoint | Method | Description |
|---|---|---|
| [`/health`](https://floodsense-agents-653167130543.asia-southeast1.run.app/health) | GET | Service health check & agent status |
| [`/alerts`](https://floodsense-agents-653167130543.asia-southeast1.run.app/alerts) | GET | Latest flood alerts from the system |
| [`/sitrep/latest`](https://floodsense-agents-653167130543.asia-southeast1.run.app/sitrep/latest) | GET | Most recent AI-generated Situation Report |
| [`/incidents`](https://floodsense-agents-653167130543.asia-southeast1.run.app/incidents) | GET | Active SOS incidents |
| [`/volunteers/available`](https://floodsense-agents-653167130543.asia-southeast1.run.app/volunteers/available) | GET | Available volunteer list |
| `/chat` | POST | Ask the AI flood safety assistant |

---

## 🎬 Testing the Application (Judges Guide)

All user roles are accessible directly from the **[Live Web App](https://floodsense-app-653167130543.asia-southeast1.run.app)** — no installation or account required.

On the role-selection screen, choose the role you want to test:

1. **🏠 "Warganegara / Citizen"** — Test the Zero-Friction SOS submission flow with real-time GPS pinning, and file an AI-audited damage claim.
2. **🏛 "Pusat Arahan / Government"** *(Access Code: `9999`)* — View active SOS cases, review AI-generated Situation Reports, and interact with the Command AI assistant.
3. **🤝 "Sukarelawan / Volunteer"** — Browse the real-time SOS map, self-assign missions, and experience the live GPS synchronization across the ecosystem.

For the **Command Centre Dashboard**, visit:
> [`https://floodsense-dashboard-653167130543.asia-southeast1.run.app`](https://floodsense-dashboard-653167130543.asia-southeast1.run.app)

---

## 🛠 Local Development Setup

### Prerequisites
* Flutter SDK (3.24+)
* Python 3.11+
* Node.js 18+
* A Firebase project with Firestore enabled

### 1. AI Backend (FastAPI Agents)
```bash
cd agents
pip install -r requirements.txt
# Set your Gemini API key
export GEMINI_API_KEY="your-key"
python -m uvicorn agent_server:app --reload
```

### 2. Citizen/Volunteer Web App (Flutter Web)
```bash
cd mobile
flutter pub get
flutter run -d chrome
```

### 3. Command Centre Dashboard (Next.js)
```bash
cd dashboard
npm install
# Copy the example env and fill in your keys
cp .env.example .env.local
npm run dev
```

> **Note:** Firebase configuration is initialized via `firebase_options.dart` in the mobile app. You will need to supply your own `google-services.json` (Android) or configure Firebase manually for local development as these files are excluded from version control for security.

---

## 🤖 AI Disclosure & Development Workflow

In compliance with hackathon requirements, we disclose that this project was developed using a hybrid human-AI pair programming workflow:

- **AI Coding Tools:** We utilized **Google Gemini** (via Antigravity by Google DeepMind) as a core coding partner for rapid prototyping, UI component generation in Flutter, and complex logic orchestration in Python.
- **AI-Generated Logic:** Portions of the Multi-Agent orchestration (Smolagents) and the RAG pipeline integration were co-developed with AI assistance to ensure adherence to Google Cloud and GenAI SDK best practices.
- **Core Strategy:** All architectural decisions, disaster response logic (MKN Directive 20 grounding), and system integration were designed and validated by the human team to ensure safety and accuracy in critical environments.
