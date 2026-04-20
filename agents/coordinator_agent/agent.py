"""
Coordinator Agent - FloodSense
The master orchestrator. Reads pending SOS incidents, scores priority,
matches volunteers, dispatches rescue, generates AI sitreps.
"""
from __future__ import annotations
import os
import uuid
import json
import math
from datetime import datetime
import google.generativeai as genai
from dotenv import load_dotenv
from shared.models import (
    FloodIncident, IncidentUrgency, IncidentStatus,
    Volunteer, SitRep, AlertSeverity
)
from shared.firestore_client import (
    get_pending_incidents, get_available_volunteers,
    assign_volunteer_to_incident, save_sitrep, update_incident
)

load_dotenv()
genai.configure(api_key=os.environ["GEMINI_API_KEY"])
model = genai.GenerativeModel("gemini-1.5-flash")


# --- Priority Scoring -------------------------------------------------------

VULNERABILITY_WEIGHTS = {
    "infant": 3.0, "baby": 3.0,
    "wheelchair": 2.5, "elderly": 2.0,
    "medical": 2.0,
}

URGENCY_SCORES = {
    IncidentUrgency.CRITICAL: 1.0,
    IncidentUrgency.HIGH: 0.75,
    IncidentUrgency.MEDIUM: 0.5,
    IncidentUrgency.LOW: 0.25,
}


def compute_priority_score(incident: dict) -> float:
    """
    Priority = (Vulnerability x 0.4) + (Urgency x 0.4) + (Wait time x 0.2)
    Returns 0-100 score. Higher = rescue first.
    """
    # Vulnerability component (0-1)
    vulnerable = incident.get("vulnerable", [])
    vuln_raw = sum(VULNERABILITY_WEIGHTS.get(v, 1.0) for v in vulnerable) if vulnerable else 0
    vulnerability = min(vuln_raw / 5.0, 1.0)  # Normalize to 0-1

    # Urgency component (0-1)
    urgency_str = incident.get("urgency", "MEDIUM")
    urgency_enum = IncidentUrgency(urgency_str)
    urgency = URGENCY_SCORES.get(urgency_enum, 0.5)

    # Wait time component (0-1, caps at 30 min)
    created_at = incident.get("created_at")
    if created_at and hasattr(created_at, "timestamp"):
        wait_seconds = (datetime.utcnow() - created_at.replace(tzinfo=None)).total_seconds()
        wait = min(wait_seconds / 1800, 1.0)  # Cap at 30 min
    else:
        wait = 0.1

    score = (vulnerability * 0.4 + urgency * 0.4 + wait * 0.2) * 100
    return round(score, 2)


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Calculate distance in km between two GPS coordinates."""
    R = 6371
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlam = math.radians(lng2 - lng1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlam / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def skills_match(incident: dict, volunteer: dict) -> bool:
    """Check if volunteer skills match incident needs."""
    volunteer_skills = set(volunteer.get("skills", []))
    vulnerable = set(incident.get("vulnerable", []))

    # If water rescue needed, volunteer needs boat
    # (indicated by being in flood zone - all incidents here)
    # For now: medic bonus for vulnerable cases, but any volunteer can respond
    required = set()
    if "infant" in vulnerable or "baby" in vulnerable:
        required.add("first_aid")        # Prefer first aid for infants
    if incident.get("head_count", 0) and incident.get("head_count", 0) > 8:
        required.add("boat")             # Large groups need boat

    # Accept if volunteer has all required skills OR if no special skills needed
    return required.issubset(volunteer_skills) or not required


def find_best_volunteer(incident: dict, volunteers: list[dict]) -> dict | None:
    """Find nearest available volunteer with matching skills."""
    inc_lat = incident.get("location", {}).get("lat", 3.139)
    inc_lng = incident.get("location", {}).get("lng", 101.687)

    candidates = []
    for vol in volunteers:
        if not skills_match(incident, vol):
            continue
        vol_lat = vol.get("location", {}).get("lat") or vol.get("lat", 3.139)
        vol_lng = vol.get("location", {}).get("lng") or vol.get("lng", 101.687)
        distance = haversine_km(inc_lat, inc_lng, vol_lat, vol_lng)
        candidates.append({**vol, "_distance_km": distance})

    if not candidates:
        return None
    return min(candidates, key=lambda v: v["_distance_km"])


# --- Sitrep Generator -------------------------------------------------------

SITREP_PROMPT = """\
You are FloodSense Coordinator AI generating a 15-minute situation report for NADMA officers.
Be concise, factual, and professional. Use Malaysian government terminology.

Data:
- District: {district}
- Current Severity: {severity}
- Active SOS: {active_sos} | Dispatched: {dispatched} | Resolved: {resolved}
- Volunteers active: {vol_active} | Available: {vol_available}
- Critical cases: {critical_count}
- Timestamp: {timestamp}

Write a structured sitrep in 4 paragraphs:
1. SITUATION (water levels, trend)
2. RESCUE OPERATIONS (SOS stats, key cases)
3. RESOURCE STATUS (volunteers, shelters)
4. RECOMMENDED ACTIONS (3 bullet points, most urgent first)

Keep total length under 250 words. Write in English.
"""


def generate_sitrep(district_id: str, incidents: list[dict], volunteers: list[dict]) -> SitRep:
    """Auto-generate an AI situation report."""
    active = [i for i in incidents if i.get("status") == "PENDING"]
    dispatched = [i for i in incidents if i.get("status") == "DISPATCHED"]
    resolved = [i for i in incidents if i.get("status") in ("RESCUED", "CLOSED")]
    critical = [i for i in active if i.get("urgency") == "CRITICAL"]
    available_vols = [v for v in volunteers if v.get("status") == "AVAILABLE"]

    prompt = SITREP_PROMPT.format(
        district=district_id,
        severity="DANGER",  # Would come from Alert Agent in prod
        active_sos=len(active),
        dispatched=len(dispatched),
        resolved=len(resolved),
        vol_active=len(dispatched),
        vol_available=len(available_vols),
        critical_count=len(critical),
        timestamp=datetime.utcnow().strftime("%d/%m/%Y %H:%M UTC"),
    )

    try:
        response = model.generate_content(prompt)
        content = response.text.strip()
    except Exception as e:
        content = f"[Sitrep generation error: {e}]"

    return SitRep(
        sitrep_id=f"SITREP-{uuid.uuid4().hex[:6].upper()}",
        district_id=district_id,
        severity=AlertSeverity.DANGER,
        active_sos=len(active),
        dispatched=len(dispatched),
        resolved=len(resolved),
        volunteers_active=len(dispatched),
        content=content,
    )


# --- Main Coordination Loop -------------------------------------------------

def run_coordination_cycle():
    """
    Main coordination cycle:
    1. Fetch pending SOS incidents
    2. Score and sort by priority
    3. Match + dispatch volunteers
    4. Generate sitrep
    """
    print("\n[Coordinator] -- Running coordination cycle --")

    incidents = get_pending_incidents()
    volunteers = get_available_volunteers()

    print(f"[Coordinator] Pending SOS: {len(incidents)} | Available volunteers: {len(volunteers)}")

    if not incidents:
        print("[Coordinator] No pending incidents.")
        return

    # Score all incidents
    for inc in incidents:
        inc["_priority_score"] = compute_priority_score(inc)

    # Sort highest priority first
    incidents.sort(key=lambda x: x["_priority_score"], reverse=True)

    dispatched_count = 0
    used_volunteers: set[str] = set()

    for incident in incidents:
        inc_id = incident.get("id") or incident.get("sos_id", "UNKNOWN")
        score = incident["_priority_score"]
        urgency = incident.get("urgency", "?")
        vulnerable = incident.get("vulnerable", [])

        print(f"\n[Coordinator] SOS {inc_id} | Priority: {score:.1f} | {urgency} | {vulnerable}")

        available = [v for v in volunteers if v.get("id") not in used_volunteers and v.get("status") == "AVAILABLE"]
        best_vol = find_best_volunteer(incident, available)

        if best_vol:
            vol_id = best_vol.get("id", "UNKNOWN")
            dist = best_vol.get("_distance_km", 0)
            print(f"  -> Assigning {best_vol.get('name')} ({vol_id}) - {dist:.1f}km away")
            assign_volunteer_to_incident(vol_id, incident, dist)
            used_volunteers.add(vol_id)
            dispatched_count += 1
        else:
            print(f"  [!] No available volunteer - escalating to Bomba")
            update_incident(inc_id, {"escalated_to_bomba": True})

    print(f"\n[Coordinator] [OK] Dispatched {dispatched_count}/{len(incidents)} incidents")

    # Generate sitrep every cycle
    all_incidents = get_pending_incidents()  # Refresh
    sitrep = generate_sitrep("Klang Valley", all_incidents, volunteers)
    sitrep_id = save_sitrep(sitrep)
    print(f"[Coordinator] SitRep {sitrep.sitrep_id} generated -> {sitrep_id}")
    print(f"\n{'-'*60}\n{sitrep.content[:400]}...\n{'-'*60}")


if __name__ == "__main__":
    run_coordination_cycle()
