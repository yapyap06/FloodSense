"""
coordinator_sitrep.py — 15-minute automated sitrep generator
Runs as a background loop inside coordinator_agent, or standalone.

Usage:
  python coordinator_sitrep.py          # Run the sitrep loop forever
  python coordinator_sitrep.py --once   # Generate one sitrep and exit
"""
import asyncio
import json
import sys
import os
from datetime import datetime, timezone
from google import genai
import firebase_admin
from firebase_admin import credentials, firestore

# ── Firebase Init ─────────────────────────────────────────────────────────────
def _init_firebase():
    if not firebase_admin._apps:
        # Use service account if available, otherwise use ADC
        sa_path = os.path.join(os.path.dirname(__file__), '..', 'firebase-service-account.json')
        if os.path.exists(sa_path):
            cred = credentials.Certificate(sa_path)
        else:
            cred = credentials.ApplicationDefault()
        firebase_admin.initialize_app(cred, {'projectId': 'floodsense-app'})
    return firestore.client()

# ── Gemini Init ───────────────────────────────────────────────────────────────
def _init_gemini():
    api_key = os.getenv('GEMINI_API_KEY') or os.getenv('GOOGLE_API_KEY')
    if not api_key:
        raise ValueError("GEMINI_API_KEY not set in environment")
    return genai.Client(api_key=api_key)

# ── Data Fetchers ─────────────────────────────────────────────────────────────
def get_incident_summary(db) -> dict:
    incidents = db.collection('incidents').order_by('created_at', direction=firestore.Query.DESCENDING).limit(50).get()
    data = [{'id': d.id, **d.to_dict()} for d in incidents]
    pending = [i for i in data if i.get('status') in ('PENDING', 'DISPATCHED')]
    resolved = [i for i in data if i.get('status') in ('RESCUED', 'CLOSED')]
    critical = [i for i in pending if i.get('urgency') == 'CRITICAL']
    total_victims = sum(i.get('head_count', 0) for i in pending)
    vulnerable = list({g for i in pending for g in i.get('vulnerable', [])})
    top3 = [{
        'sos_id': i.get('sos_id', ''),
        'address': i.get('address_text', 'Unknown'),
        'urgency': i.get('urgency', ''),
        'head_count': i.get('head_count', 0),
        'vulnerable': i.get('vulnerable', []),
    } for i in (critical + [i for i in pending if i.get('urgency') != 'CRITICAL'])[:3]]

    return {
        'pending': len(pending),
        'dispatched': len([i for i in pending if i.get('status') == 'DISPATCHED']),
        'resolved': len(resolved),
        'critical_count': len(critical),
        'total_victims': total_victims,
        'vulnerable_groups': vulnerable,
        'top3_critical': top3,
    }

def get_latest_alert(db) -> dict:
    alerts = db.collection('alerts').order_by('created_at', direction=firestore.Query.DESCENDING).limit(1).get()
    if not alerts:
        return {'district_id': 'Klang Valley', 'severity': 'WATCH', 'river_level_m': 0}
    return {'id': alerts[0].id, **alerts[0].to_dict()}

def get_volunteer_summary(db) -> dict:
    vols = db.collection('volunteers').get()
    data = [d.to_dict() for d in vols]
    return {
        'total': len(data),
        'available': len([v for v in data if v.get('status') == 'AVAILABLE']),
        'on_mission': len([v for v in data if v.get('status') == 'ON_MISSION']),
    }

# ── Sitrep Generator ──────────────────────────────────────────────────────────
def generate_sitrep(gemini_client, incidents: dict, alert: dict, volunteers: dict) -> str:
    top3_lines = '\n'.join([
        f"  - {i['sos_id']}: {i['urgency']} | {i['address']} | {i['head_count']} pax | {', '.join(i['vulnerable']) or 'no vulnerable'}"
        for i in incidents['top3_critical']
    ]) or '  (no critical cases)'

    prompt = f"""You are FloodSense Coordinator AI generating a 15-minute situation report for the MKN Commander.
Write in formal English. Max 300 words. Be direct and specific.

OPERATIONAL DATA ({datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M')} UTC):
- District: {alert.get('district_id', 'Klang Valley')}
- Alert Level: {alert.get('severity', 'WATCH')}
- River Level: {alert.get('river_level_m', 'N/A')}m
- AI Reasoning: {alert.get('reasoning', 'No current alert data')}

INCIDENTS:
- Active/Pending: {incidents['pending']} cases
- Dispatched: {incidents['dispatched']} cases
- Resolved: {incidents['resolved']} cases
- Critical Cases: {incidents['critical_count']}
- Total Victims at Risk: {incidents['total_victims']} people
- Vulnerable Groups: {', '.join(incidents['vulnerable_groups']) or 'none'}

TOP 3 CRITICAL CASES:
{top3_lines}

VOLUNTEERS:
- Total Registered: {volunteers['total']}
- Available Now: {volunteers['available']}
- On Mission: {volunteers['on_mission']}

Write exactly in this structure:
**SITUATION**
(2-3 sentences on water levels, alert trend, immediate threat)

**RESCUE OPERATIONS**
(active case breakdown, dispatched units, priority gaps)

**CRITICAL CASES**
(top 3 cases with specific addresses and needs)

**RESOURCES**
(volunteer availability, estimated supply status)

**RECOMMENDATIONS** (3 bullet points, specific and actionable for next 15 minutes)"""

    response = gemini_client.models.generate_content(
        model='gemini-2.5-flash',
        contents=prompt,
    )
    return response.text

# ── Save Sitrep to Firestore ──────────────────────────────────────────────────
def save_sitrep(db, content: str, alert: dict, incidents: dict):
    sitrep_id = f"SITREP-{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M')}"
    db.collection('sitreps').document(sitrep_id).set({
        'id': sitrep_id,
        'content': content,
        'district_id': alert.get('district_id', 'Klang Valley'),
        'severity': alert.get('severity', 'WATCH'),
        'active_sos': incidents['pending'],
        'generated_at': firestore.SERVER_TIMESTAMP,
        'approved': False,
        'forwarded': False,
        'model': 'gemini-2.5-flash',
    })
    print(f"[{datetime.now().strftime('%H:%M:%S')}] ✅ Sitrep saved: {sitrep_id}")
    return sitrep_id

# ── Main Loop ─────────────────────────────────────────────────────────────────
async def sitrep_loop(interval_seconds: int = 900):
    db = _init_firebase()
    gemini_client = _init_gemini()
    print(f"[SITREP] Starting 15-minute loop (every {interval_seconds}s). Press Ctrl+C to stop.")

    while True:
        try:
            print(f"[{datetime.now().strftime('%H:%M:%S')}] Generating sitrep...")
            incidents = get_incident_summary(db)
            alert = get_latest_alert(db)
            volunteers = get_volunteer_summary(db)
            content = generate_sitrep(gemini_client, incidents, alert, volunteers)
            sitrep_id = save_sitrep(db, content, alert, incidents)
            print(f"  Active SOS: {incidents['pending']} | Victims: {incidents['total_victims']} | Severity: {alert.get('severity')}")
        except Exception as e:
            print(f"[SITREP ERROR] {e}")

        if '--once' in sys.argv:
            break
        await asyncio.sleep(interval_seconds)

if __name__ == '__main__':
    asyncio.run(sitrep_loop(900 if '--once' not in sys.argv else 0))
