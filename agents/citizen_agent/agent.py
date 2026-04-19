"""
Citizen Agent - FloodSense
Handles SOS parsing (WhatsApp voice/text, SMS) and RAG Q&A using
keyword-based SOP retrieval + Gemini (no model download required).
Structures SOS into FloodIncident and saves to Firestore.
"""
from __future__ import annotations
import os, uuid, json, asyncio
from google import genai
from dotenv import load_dotenv
from shared.models import FloodIncident, IncidentUrgency, SOSChannel, GeoPoint
from shared.firestore_client import create_incident

load_dotenv()
client = genai.Client(api_key=os.environ['GEMINI_API_KEY'], http_options={'api_version': 'v1'})

# --- SOP Database (in-memory, no download needed) ----------------------------
FLOOD_SOPS = [
    ("SOP_001", ["water rising", "air naik", "electricity", "elektrik", "fuse", "upper floor"],
     "Water rising in house: Immediately turn off main electricity at fuse box. Move to upper floors. Do not touch floodwater - it may be electrified. Bring IDs, medicine, phone charger."),
    ("SOP_002", ["evacuation route", "laluan", "jalan", "escape", "highway", "klang valley"],
     "Evacuation routes Klang Valley: AKLEH to Ampang Point. Avoid Jalan Masjid India when Sg Klang >5.5m. Alternative: Sprint highway northbound to Rawang shelter."),
    ("SOP_003", ["shelter", "pps", "tempat", "capacity", "stadium shah alam", "kampung baru"],
     "PPS Shelters: SK Kampung Baru KL (500 cap), Stadium Shah Alam (5000 cap), Dewan Serbaguna Klang (1200 cap). All accept pets. Elderly and children given priority."),
    ("SOP_004", ["helicopter", "rescue signal", "sos signal", "rooftop", "wave", "torch"],
     "Signal for helicopter rescue: Use bright cloth or phone torch from rooftop. Wave slowly side to side. Spell SOS with rocks/objects."),
    ("SOP_005", ["baby", "infant", "formula", "baby formula", "bayi", "susu"],
     "Baby/infant care during flood: Keep elevated. Maintain warmth. Baby formula available at all PPS shelters. Fever: see shelter medic."),
    ("SOP_006", ["elderly", "wheelchair", "warga emas", "kerusi roda", "disabled", "mobility"],
     "Elderly/wheelchair evacuation: Priority rescue case. Call SOS - state mobility limitation. Volunteers with adapted transport dispatched first. Stay put."),
    ("SOP_007", ["wound", "luka", "leptospirosis", "bacteria", "skin", "contact", "first aid"],
     "First aid for floodwater contact: Wash wounds with clean water. Avoid touching eyes/mouth. Seek medical attention for cuts. Report fever within 2 weeks - leptospirosis risk."),
    ("SOP_008", ["no internet", "no signal", "4g", "offline", "sms", "battery", "low battery"],
     "When 4G is unavailable: Send SMS 'SOS' to 15888. Include house number and street. App queues SOS and sends when signal returns. Battery-save mode activates at 20%."),
    ("SOP_009", ["car", "kereta", "vehicle", "stuck", "floodwater", "engine", "driving"],
     "Car stuck in floodwater: Do NOT start engine if water above exhaust. Exit immediately if water enters cabin - open window first. Swim away, move to high ground."),
    ("SOP_010", ["gas", "gas leak", "smell", "bau", "fire", "letupan", "explosion"],
     "Gas leak during flood: Do not operate any switch or flame. Open all windows. Evacuate immediately. Call 999 from outside. Do not re-enter until cleared by Bomba."),
]


def retrieve_sops(question: str, top_k: int = 3) -> list[str]:
    """Simple keyword-based SOP retrieval - no model download, runs instantly."""
    q_lower = question.lower()
    scored = []
    for sop_id, keywords, text in FLOOD_SOPS:
        score = sum(1 for kw in keywords if kw in q_lower)
        if score > 0:
            scored.append((score, text))
    scored.sort(reverse=True, key=lambda x: x[0])
    if not scored:
        # Return top 2 general SOPs if no keyword match
        return [FLOOD_SOPS[0][2], FLOOD_SOPS[2][2]]
    return [text for _, text in scored[:top_k]]


# --- Prompts -----------------------------------------------------------------
SOS_PARSE_PROMPT = """\
You are an emergency SOS parser for FloodSense, Malaysia's flood rescue system.
Extract all available information from this distress message.
If you are unsure about urgency, err on the HIGHER side - this is life-critical.
Detect language automatically (Malay/English/Mandarin/Tamil).

Message: "{raw_input}"

Return ONLY valid JSON (no markdown fences):
{{
  "address_text": "raw address as stated or null",
  "head_count": number_or_null,
  "vulnerable_groups": ["infant"|"elderly"|"wheelchair"|"medical"|"baby"],
  "floor_level": number_or_null,
  "urgency": "CRITICAL|HIGH|MEDIUM|LOW",
  "language": "ms|en|zh|ta",
  "needs_translation": true_or_false,
  "summary_en": "One sentence in English describing situation"
}}
"""

RAG_ANSWER_PROMPT = """\
You are FloodSense AI assistant. Answer ONLY flood safety questions.
Be concise (max 3 sentences). Match the user's language: {language}.
If you don't know, say "Please call 999 or go to your nearest PPS shelter."

Context from SOP database:
{context}

User question: {question}

Answer:"""


def parse_sos(raw_input: str, channel: SOSChannel, sender_phone: str | None = None, lat: float | None = None, lng: float | None = None) -> FloodIncident | None:
    """Parse a raw SOS message into a structured FloodIncident using Gemini."""
    if not raw_input.strip():
        return None

    prompt = SOS_PARSE_PROMPT.format(raw_input=raw_input)

    try:
        response = client.models.generate_content(model="gemini-2.5-flash", contents=prompt)
        raw = response.text.strip().lstrip("```json").rstrip("```").strip()
        data = json.loads(raw)
    except Exception as e:
        print(f"[CitizenAgent] SOS parse error: {e}")
        data = {"urgency": "CRITICAL", "head_count": None, "vulnerable_groups": [], "language": "en"}

    urgency_map = {
        "CRITICAL": IncidentUrgency.CRITICAL,
        "HIGH": IncidentUrgency.HIGH,
        "MEDIUM": IncidentUrgency.MEDIUM,
        "LOW": IncidentUrgency.LOW,
    }

    incident = FloodIncident(
        sos_id=f"SOS-{uuid.uuid4().hex[:8].upper()}",
        location=GeoPoint(lat=lat, lng=lng) if lat and lng else GeoPoint(lat=3.1390, lng=101.6869),
        address_text=data.get("address_text"),
        head_count=data.get("head_count"),
        vulnerable=data.get("vulnerable_groups", []),
        floor_level=data.get("floor_level"),
        urgency=urgency_map.get(data.get("urgency", "HIGH"), IncidentUrgency.HIGH),
        channel=channel,
        sender_phone=sender_phone,
        language=data.get("language", "en"),
    )

    # Save to Firestore (convert model to dict)
    incident_dict = {
        "sos_id": incident.sos_id,
        "urgency": incident.urgency.value,
        "status": incident.status.value,
        "head_count": incident.head_count,
        "vulnerable": incident.vulnerable,
        "address_text": incident.address_text,
        "channel": incident.channel.value,
        "sender_phone": incident.sender_phone or "",
        "language": incident.language,
        "floor_level": incident.floor_level,
        "district_id": "Klang Valley",
        "lat": incident.location.lat,
        "lng": incident.location.lng,
    }
    
    # We must also format location correctly for firestore
    from firebase_admin import firestore
    incident_dict["location"] = firestore.GeoPoint(incident.location.lat, incident.location.lng)
    
    doc_id = create_incident(incident_dict)
    print(f"[CitizenAgent] SOS {incident.sos_id} created ({incident.urgency.value}) -> Firestore: {doc_id}")
    return incident


def answer_sop_question(question: str, language: str = "en") -> str:
    """Answer a flood safety question using keyword SOP retrieval + Gemini."""
    sop_texts = retrieve_sops(question)
    context = "\n\n".join(sop_texts)

    prompt = RAG_ANSWER_PROMPT.format(
        language=language, context=context, question=question
    )

    try:
        response = client.models.generate_content(model="gemini-2.5-flash", contents=prompt)
        return response.text.strip()
    except Exception as e:
        print(f"[CitizenAgent] RAG answer error: {e}")
        return "Sila hubungi 999 atau pergi ke PPS berhampiran. / Please call 999 or go to your nearest PPS shelter."


# --- Demo: test the agent directly -------------------------------------------
if __name__ == "__main__":
    print(f"[CitizenAgent] Loaded {len(FLOOD_SOPS)} SOPs (keyword index, no download)")

    # Test SOS parsing
    test_messages = [
        ("Saya terperangkap, rumah no 47 Jalan Meranti, ada 6 orang, satu orang tua dalam kerusi roda, air naik cepat", SOSChannel.WHATSAPP),
        ("SOS trapped 3rd floor, family of 5 with baby, please help", SOSChannel.SMS),
    ]

    print("\n=== SOS PARSING TESTS ===")
    for msg, channel in test_messages:
        print(f"\nInput: {msg[:60]}...")
        incident = parse_sos(msg, channel, sender_phone="+60123456789")
        if incident:
            print(f"-> Urgency: {incident.urgency.value} | Vulnerable: {incident.vulnerable} | Head count: {incident.head_count}")

    # Test RAG Q&A
    print("\n=== RAG Q&A TESTS ===")
    questions = [
        ("Air masuk rumah apa nak buat?", "ms"),
        ("How to signal a helicopter?", "en"),
    ]
    for q, lang in questions:
        print(f"\nQ ({lang}): {q}")
        answer = answer_sop_question(q, lang)
        print(f"A: {answer}")
