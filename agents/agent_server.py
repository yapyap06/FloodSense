"""
FloodSense Agent API Server
===========================
FastAPI server that exposes all 4 ADK agents as HTTP endpoints.
The mobile app, dashboard, and Twilio webhooks call this server.

Endpoints:
  POST /sos                  → Citizen Agent parses SOS, saves to Firestore
  POST /chat                 → Citizen Agent answers flood Q&A via RAG
  GET  /alerts               → Latest alerts from Firestore (from Alert Agent)
  POST /coordinate           → Coordinator Agent: score → match → dispatch
  GET  /sitrep/latest        → Latest AI situation report
  POST /sitrep/generate      → Coordinator Agent generates a new sitrep
  GET  /inventory            → Resource Agent inventory check
  POST /inventory/recommend  → Resource Agent pre-positioning recommendation
  GET  /volunteers/available → Available volunteers from Firestore
  GET  /health               → Health check

Run:
  cd agents
  $env:PYTHONPATH = "."
  uvicorn agent_server:app --reload --port 8000
"""
from __future__ import annotations
import os
import sys
import json
import asyncio
from datetime import datetime, timezone
from typing import Optional

from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv

load_dotenv()

# ── Agent imports ──────────────────────────────────────────────────────────────
from shared.firestore_client import (
    get_pending_incidents, get_available_volunteers,
    save_sitrep, get_shelters, get_all_incidents,
)
from shared.models import SOSChannel

from citizen_agent.agent import parse_sos, answer_sop_question
from coordinator_agent.agent import run_coordination_cycle, generate_sitrep
from resource_agent.agent import check_inventory, recommend_prepositioning
import firebase_admin
from firebase_admin import firestore as fs

# ── App Setup ──────────────────────────────────────────────────────────────────
app = FastAPI(
    title="FloodSense Agent API",
    description="Multi-agent AI backend for FloodSense Malaysia",
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # Mobile app + dashboard
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Request / Response Models ──────────────────────────────────────────────────

class SOSRequest(BaseModel):
    raw_message: str
    channel: str = "app"          # app | sms | whatsapp | voice
    sender_phone: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None

class ChatRequest(BaseModel):
    question: str
    language: str = "en"

class PrepositionRequest(BaseModel):
    district_id: str
    predicted_households: int


# ── Background: Alert Agent loop (poll JPS every 60s) ─────────────────────────
_alert_task: asyncio.Task | None = None

async def _alert_loop():
    """Background task: runs the Alert Agent polling loop."""
    from alert_agent.agent import poll_and_classify
    import asyncio
    print("[Server] Alert Agent background loop started (60s interval)")
    while True:
        try:
            await poll_and_classify()
        except Exception as e:
            print(f"[AlertAgent] Loop error: {e}")
        await asyncio.sleep(60)

async def _coordinator_loop():
    """Background task: runs Coordinator Agent every 90 seconds."""
    import asyncio
    print("[Server] Coordinator Agent background loop started (90s interval)")
    while True:
        try:
            run_coordination_cycle()
        except Exception as e:
            print(f"[CoordinatorAgent] Loop error: {e}")
        await asyncio.sleep(90)

async def _resource_loop():
    """Background task: runs Resource Agent every 5 minutes."""
    import asyncio
    print("[Server] Resource Agent background loop started (5m interval)")
    while True:
        try:
            check_inventory()
        except Exception as e:
            print(f"[ResourceAgent] Loop error: {e}")
        await asyncio.sleep(300)


@app.on_event("startup")
async def startup():
    """Start all agent background loops on server boot."""
    print("🌊 FloodSense Agent Server starting...")
    asyncio.create_task(_alert_loop())
    asyncio.create_task(_coordinator_loop())
    asyncio.create_task(_resource_loop())
    print("✅ All 4 agents are running.")


# ── Health Check ───────────────────────────────────────────────────────────────

@app.get("/")
def root():
    return {
        "service": "FloodSense Multi-Agent API",
        "version": "2.0.0",
        "status": "🟢 Live",
        "description": "Autonomous disaster response backend for FloodSense Malaysia (GovTech 2026)",
        "docs": "/docs",
        "endpoints": {
            "health": "/health",
            "alerts": "/alerts",
            "incidents": "/incidents",
            "sitrep": "/sitrep/latest",
            "volunteers": "/volunteers/available",
            "chat": "POST /chat",
        }
    }


# ── Health Check ───────────────────────────────────────────────────────────────

@app.get("/health")
def health():
    return {
        "status": "ok",
        "service": "FloodSense Agent API",
        "version": "2.0.0",
        "agents": ["alert_agent", "citizen_agent", "coordinator_agent", "resource_agent"],
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


# ── CITIZEN AGENT: SOS Parsing ─────────────────────────────────────────────────

@app.post("/sos")
async def submit_sos(req: SOSRequest):
    """
    Mobile app / Twilio webhook calls this.
    Citizen Agent parses the raw message → saves structured incident to Firestore.
    Coordinator Agent auto-triggers in background.
    """
    channel_map = {
        "app": SOSChannel.APP,
        "sms": SOSChannel.SMS,
        "whatsapp": SOSChannel.WHATSAPP,
        "voice": SOSChannel.VOICE,
    }
    channel = channel_map.get(req.channel.lower(), SOSChannel.APP)

    try:
        incident = parse_sos(
            raw_input=req.raw_message,
            channel=channel,
            sender_phone=req.sender_phone,
            lat=req.lat,
            lng=req.lng,
        )
        if not incident:
            raise HTTPException(status_code=400, detail="Could not parse SOS message")

        return {
            "success": True,
            "sos_id": incident.sos_id,
            "urgency": incident.urgency.value,
            "vulnerable": incident.vulnerable,
            "head_count": incident.head_count,
            "message": f"SOS received. Help is being dispatched. Case ID: {incident.sos_id}",
            "message_ms": f"SOS diterima. Bantuan sedang dihantar. ID Kes: {incident.sos_id}",
        }
    except Exception as e:
        print(f"[API /sos] Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ── CITIZEN AGENT: Flood Q&A (RAG) ────────────────────────────────────────────

@app.post("/chat")
async def flood_chat(req: ChatRequest):
    """
    Mobile app AI chat → Citizen Agent answers using SOP RAG + Gemini.
    Works even when Gemini is rate-limited (falls back to SOP keywords).
    """
    try:
        answer = answer_sop_question(req.question, req.language)
        return {
            "question": req.question,
            "answer": answer,
            "language": req.language,
            "source": "FloodSense SOP + Gemini 2.0 Flash",
        }
    except Exception as e:
        print(f"[API /chat] Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ── ALERT AGENT: Latest Alerts ─────────────────────────────────────────────────

@app.get("/alerts")
def get_alerts(limit: int = 10):
    """Returns latest flood alerts from Firestore (written by Alert Agent)."""
    try:
        from shared.firestore_client import _get_db
        db = _get_db()
        docs = (
            db.collection("alerts")
            .order_by("created_at", direction=fs.Query.DESCENDING)
            .limit(limit)
            .stream()
        )
        alerts = []
        for d in docs:
            data = d.to_dict()
            data["id"] = d.id
            # Convert Firestore timestamps to ISO strings
            if hasattr(data.get("created_at"), "isoformat"):
                data["created_at"] = data["created_at"].isoformat()
            alerts.append(data)
        return {"alerts": alerts, "count": len(alerts)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ── COORDINATOR AGENT: Manual Trigger ─────────────────────────────────────────

@app.post("/coordinate")
async def trigger_coordination(background_tasks: BackgroundTasks):
    """
    Manually triggers one coordination cycle.
    Coordinator Agent scores all pending SOS → matches volunteers → dispatches.
    """
    def _run():
        try:
            run_coordination_cycle()
        except Exception as e:
            print(f"[API /coordinate] Error: {e}")

    background_tasks.add_task(_run)
    return {
        "success": True,
        "message": "Coordination cycle triggered. Check Firestore for dispatch updates.",
    }


# ── COORDINATOR AGENT: Sitrep ─────────────────────────────────────────────────

@app.get("/sitrep/latest")
def get_latest_sitrep():
    """Returns the most recent AI situation report."""
    try:
        from shared.firestore_client import _get_db
        db = _get_db()
        docs = (
            db.collection("sitreps")
            .order_by("created_at", direction=fs.Query.DESCENDING)
            .limit(1)
            .stream()
        )
        results = []
        for d in docs:
            data = d.to_dict()
            data["id"] = d.id
            if hasattr(data.get("created_at"), "isoformat"):
                data["created_at"] = data["created_at"].isoformat()
            results.append(data)

        if not results:
            return {"sitrep": None, "message": "No sitreps generated yet."}
        return {"sitrep": results[0]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/sitrep/generate")
async def generate_new_sitrep(background_tasks: BackgroundTasks):
    """Triggers the Coordinator Agent to generate a new sitrep immediately."""
    def _run():
        try:
            from shared.firestore_client import _get_db
            db = _get_db()

            incidents_raw = db.collection("incidents").limit(50).stream()
            incidents = [{"id": d.id, **d.to_dict()} for d in incidents_raw]

            volunteers_raw = db.collection("volunteers").stream()
            volunteers = [{"id": d.id, **d.to_dict()} for d in volunteers_raw]

            sitrep = generate_sitrep("Klang Valley", incidents, volunteers)
            sitrep_id = save_sitrep(sitrep)
            print(f"[API /sitrep/generate] Generated: {sitrep_id}")
        except Exception as e:
            print(f"[API /sitrep/generate] Error: {e}")

    background_tasks.add_task(_run)
    return {"success": True, "message": "Sitrep generation started. Check /sitrep/latest in ~5s."}


# ── RESOURCE AGENT: Inventory ─────────────────────────────────────────────────

@app.get("/inventory")
def get_inventory_status():
    """Resource Agent checks all inventory items and flags critical stock."""
    try:
        recommendations = check_inventory()
        return {
            "recommendations": recommendations,
            "critical_count": sum(1 for r in recommendations if r.get("status") == "CRITICAL"),
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/inventory/recommend")
async def preposition_supplies(req: PrepositionRequest):
    """Resource Agent calculates pre-positioning quantities for a district."""
    try:
        result = recommend_prepositioning(req.district_id, req.predicted_households)
        return {"recommendation": result, "district": req.district_id}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ── VOLUNTEERS ─────────────────────────────────────────────────────────────────

@app.get("/volunteers/available")
def available_volunteers():
    """Returns all currently available volunteers from Firestore."""
    try:
        vols = get_available_volunteers(limit=50)
        # Strip sensitive fields
        safe = []
        for v in vols:
            safe.append({
                "id": v.get("id"),
                "name": v.get("name"),
                "skills": v.get("skills", []),
                "status": v.get("status"),
                "lat": v.get("location", {}).get("lat") or v.get("lat"),
                "lng": v.get("location", {}).get("lng") or v.get("lng"),
            })
        return {"volunteers": safe, "count": len(safe)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ── INCIDENTS ──────────────────────────────────────────────────────────────────

@app.get("/incidents")
def list_incidents(status: Optional[str] = None, limit: int = 20):
    """Returns incidents, optionally filtered by status."""
    try:
        from shared.firestore_client import _get_db
        db = _get_db()
        q = db.collection("incidents").limit(limit)
        if status:
            q = db.collection("incidents").where("status", "==", status.upper()).limit(limit)
        docs = q.stream()
        incidents = []
        for d in docs:
            data = d.to_dict()
            data["id"] = d.id
            if hasattr(data.get("created_at"), "isoformat"):
                data["created_at"] = data["created_at"].isoformat()
            incidents.append(data)
        return {"incidents": incidents, "count": len(incidents)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ── SHELTERS ───────────────────────────────────────────────────────────────────

@app.get("/shelters")
def list_shelters():
    """Returns all PPS shelter data."""
    try:
        shelters = get_shelters()
        return {"shelters": shelters, "count": len(shelters)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ── Entry Point ────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("agent_server:app", host="0.0.0.0", port=8000, reload=True)
