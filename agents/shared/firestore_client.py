"""
shared/firestore_client.py
Firebase Firestore client for FloodSense agents.

Uses the Firebase Admin SDK with the service account JSON file.
This gives full read/write access without REST API rate limits.
"""
import os
import datetime
from typing import Optional, List
from dotenv import load_dotenv

load_dotenv()

import firebase_admin
from firebase_admin import credentials, firestore

# ── Initialise Admin SDK (only once) ──────────────────────────────────────────
_app = None

def _get_db():
    global _app
    if _app is None:
        # Try service account file first, then fall back to env var
        sa_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "../firebase-service-account.json")
        # Resolve relative to this file's location if not absolute
        if not os.path.isabs(sa_path):
            base = os.path.dirname(os.path.abspath(__file__))
            sa_path = os.path.normpath(os.path.join(base, sa_path))

        if os.path.exists(sa_path):
            cred = credentials.Certificate(sa_path)
            print(f"[Firestore] Using service account: {sa_path}")
        else:
            # Fallback: Application Default Credentials
            cred = credentials.ApplicationDefault()
            print("[Firestore] Using Application Default Credentials")

        _app = firebase_admin.initialize_app(cred)

    return firestore.client()


# ── Public API used by all agents ─────────────────────────────────────────────

def create_incident(incident_data: dict) -> Optional[str]:
    """Save a new SOS incident to Firestore. Returns the document ID."""
    db = _get_db()
    incident_data["created_at"] = firestore.SERVER_TIMESTAMP
    _, ref = db.collection("incidents").add(incident_data)
    print(f"[Firestore] Created incident: {ref.id}")
    return ref.id


def update_incident(incident_id: str, update_data: dict) -> bool:
    """Update an existing incident (e.g., set status to DISPATCHED)."""
    db = _get_db()
    db.collection("incidents").document(incident_id).update(update_data)
    return True


def get_pending_incidents(limit: int = 20) -> List[dict]:
    """Retrieve PENDING incidents for the coordinator to process."""
    db = _get_db()
    docs = (
        db.collection("incidents")
        .where("status", "==", "PENDING")
        .limit(limit)
        .stream()
    )
    return [{"id": d.id, **d.to_dict()} for d in docs]


def get_all_incidents(limit: int = 50) -> List[dict]:
    """Get all incidents ordered by creation time (newest first)."""
    db = _get_db()
    docs = db.collection("incidents").limit(limit).stream()
    return [{"id": d.id, **d.to_dict()} for d in docs]


def save_alert(alert_data: dict) -> Optional[str]:
    """Save a new flood alert to Firestore. Returns doc ID."""
    db = _get_db()
    alert_data["created_at"] = firestore.SERVER_TIMESTAMP
    _, ref = db.collection("alerts").add(alert_data)
    print(f"[Firestore] Saved alert: {ref.id}")
    return ref.id


def get_latest_alert() -> Optional[dict]:
    """Get the single most recent alert."""
    db = _get_db()
    docs = (
        db.collection("alerts")
        .order_by("created_at", direction=firestore.Query.DESCENDING)
        .limit(1)
        .stream()
    )
    results = [{"id": d.id, **d.to_dict()} for d in docs]
    return results[0] if results else None


def save_sitrep(sitrep_data) -> Optional[str]:
    """Save an AI-generated situation report. Accepts Pydantic model or dict."""
    db = _get_db()
    if hasattr(sitrep_data, "model_dump"):
        data = sitrep_data.model_dump()
        # Convert any enum to value string
        for k, v in data.items():
            if hasattr(v, "value"):
                data[k] = v.value
    elif hasattr(sitrep_data, "dict"):
        data = sitrep_data.dict()
    else:
        data = dict(sitrep_data)

    data["created_at"] = firestore.SERVER_TIMESTAMP
    _, ref = db.collection("sitreps").add(data)
    print(f"[Firestore] Saved sitrep: {ref.id}")
    return ref.id


def get_available_volunteers(limit: int = 50) -> List[dict]:
    """Get all volunteers with status AVAILABLE."""
    db = _get_db()
    docs = (
        db.collection("volunteers")
        .where("status", "==", "AVAILABLE")
        .limit(limit)
        .stream()
    )
    return [{"id": d.id, **d.to_dict()} for d in docs]


def update_volunteer_status(volunteer_id: str, status: str, mission_id: str = "") -> bool:
    """Update a volunteer's status field."""
    db = _get_db()
    data: dict = {"status": status}
    if mission_id:
        data["current_mission"] = mission_id
    db.collection("volunteers").document(volunteer_id).update(data)
    return True


def assign_volunteer_to_incident(volunteer_id: str, incident: dict, distance_km: float = 2.0) -> bool:
    """
    Assign a volunteer to an SOS incident (atomic-style):
    - Sets volunteer status → ON_MISSION
    - Sets incident status → ASSIGNED
    - Creates a mission_offers document so the mobile app can pick it up
    """
    db = _get_db()
    batch = db.batch()

    inc_id = incident.get("id") or incident.get("sos_id", "UNKNOWN")

    vol_ref = db.collection("volunteers").document(volunteer_id)
    batch.update(vol_ref, {"status": "ON_MISSION", "current_mission": inc_id})

    inc_ref = db.collection("incidents").document(inc_id)
    # Using 'ASSIGNED' instead of 'DISPATCHED' to align with the mobile app states (PENDING, ASSIGNED, RESOLVED)
    batch.update(inc_ref, {"status": "ASSIGNED", "assigned_unit_id": volunteer_id,
                            "dispatched_at": firestore.SERVER_TIMESTAMP})

    offer_ref = db.collection("mission_offers").document()
    batch.set(offer_ref, {
        "volunteer_id": volunteer_id,
        "sos_id": inc_id,
        "status": "OFFERED",
        "address": incident.get("address_text") or incident.get("address") or "Auto-dispatched Location",
        "head_count": incident.get("head_count", 1),
        "distance_km": round(distance_km, 1),
        "created_at": firestore.SERVER_TIMESTAMP
    })

    batch.commit()
    return True
    return True


def get_shelters() -> List[dict]:
    """Get all PPS shelters."""
    db = _get_db()
    docs = db.collection("shelters").stream()
    return [{"id": d.id, **d.to_dict()} for d in docs]


def get_inventory(limit: int = 100) -> List[dict]:
    """Get all inventory items."""
    db = _get_db()
    docs = db.collection("inventory").limit(limit).stream()
    return [{"id": d.id, **d.to_dict()} for d in docs]


def update_inventory_item(item_id: str, update_data: dict) -> bool:
    """Update an inventory item's fields."""
    db = _get_db()
    db.collection("inventory").document(item_id).update(update_data)
    return True


def save_claim(claim_data: dict) -> Optional[str]:
    """Save a new damage claim."""
    db = _get_db()
    claim_data["submitted_at"] = firestore.SERVER_TIMESTAMP
    _, ref = db.collection("claims").add(claim_data)
    print(f"[Firestore] Saved claim: {ref.id}")
    return ref.id


def get_pending_claims(limit: int = 50) -> List[dict]:
    """Get all claims pending review."""
    db = _get_db()
    docs = (
        db.collection("claims")
        .where("status", "==", "pending_review")
        .limit(limit)
        .stream()
    )
    return [{"id": d.id, **d.to_dict()} for d in docs]


def log_audit(action: str, actor: str, details: dict = None) -> None:
    """Write an immutable audit log entry."""
    db = _get_db()
    db.collection("audit_log").add({
        "action": action,
        "actor": actor,
        "details": details or {},
        "timestamp": firestore.SERVER_TIMESTAMP,
    })
