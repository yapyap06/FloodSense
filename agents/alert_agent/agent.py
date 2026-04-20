"""
Alert Agent - FloodSense
Polls JPS mock API every 60s, classifies flood risk using Gemini,
and writes alerts to Firestore. Runs as a background ADK agent.
"""
from __future__ import annotations
import asyncio
import os
import uuid
from datetime import datetime
import httpx
from google import genai
from dotenv import load_dotenv
from shared.models import FloodAlert, AlertSeverity, RiverGaugeReading
from shared.firestore_client import save_alert, get_latest_alert

load_dotenv()
client = genai.Client(api_key=os.environ['GEMINI_API_KEY'], http_options={'api_version': 'v1'})

JPS_API_BASE = os.getenv("JPS_API_BASE_URL", "http://localhost:3001")
POLL_INTERVAL_SECONDS = 60  # Poll every 60s (mock) - reduce to 30s in prod

# --- Prompt ------------------------------------------------------------------
CLASSIFY_PROMPT = """\
You are a flood risk classifier for Malaysia's JPS (Jabatan Pengairan dan Saliran) system.
Analyse the river gauge reading and classify the flood risk.

River: {river_name}
Current level: {level_m}m | Normal: {normal_m}m | Alert: {alert_m}m | Danger: {danger_m}m
Trend: {trend} | Rising rate: {delta_per_hour}m/hr
Rainfall last 6h: {rainfall_mm}mm

Classify as one of:
- WATCH    : Level elevated but no immediate threat. Monitor closely.
- WARNING  : Approaching alert threshold. Community should prepare.
- DANGER   : Above alert threshold. Initiate pre-evacuation.
- EVACUATE : Imminent or active flooding. Evacuate now.

Respond ONLY in this exact JSON format (no markdown, no explanation):
{{
  "severity": "WATCH|WARNING|DANGER|EVACUATE",
  "confidence": 0.0-1.0,
  "predicted_depth_cm": number_or_null,
  "time_to_impact_hours": number_or_null,
  "reasoning": "One sentence in plain English",
  "recommended_actions": ["action1", "action2", "action3"]
}}
"""


async def fetch_gauges() -> list[dict]:
    """Fetch river gauge readings from mock JPS API."""
    async with httpx.AsyncClient() as http:
        resp = await http.get(f"{JPS_API_BASE}/gauges", timeout=10)
        resp.raise_for_status()
        return resp.json()


async def fetch_rainfall() -> list[dict]:
    """Fetch rainfall data from mock API."""
    async with httpx.AsyncClient() as http:
        resp = await http.get(f"{JPS_API_BASE}/rainfall", timeout=10)
        resp.raise_for_status()
        return resp.json()


def classify_gauge(gauge: dict, rainfall_mm: float = 0) -> dict | None:
    """
    Use Gemini to classify flood risk for a single gauge.
    Returns parsed JSON response or None on error.
    """
    # Skip if level is well below alert threshold
    if gauge["level_m"] < gauge["alert_m"] * 0.7:
        return None

    prompt = CLASSIFY_PROMPT.format(
        river_name=gauge["name"],
        level_m=gauge["level_m"],
        normal_m=gauge["normal_m"],
        alert_m=gauge["alert_m"],
        danger_m=gauge["danger_m"],
        trend=gauge["trend"],
        delta_per_hour=gauge["delta_per_hour"],
        rainfall_mm=rainfall_mm,
    )

    try:
        import json
        response = client.models.generate_content(model="gemini-1.5-flash", contents=prompt)
        raw = response.text.strip().lstrip("```json").rstrip("```").strip()
        return json.loads(raw)
    except Exception as e:
        print(f"[AlertAgent] Gemini classification error for {gauge['name']}: {e}")
        return None


def build_alert(gauge: dict, classification: dict) -> FloodAlert:
    """Construct a FloodAlert from gauge data + Gemini classification."""
    severity_map = {s.value: s for s in AlertSeverity}
    severity = severity_map.get(classification["severity"], AlertSeverity.WATCH)

    return FloodAlert(
        alert_id=f"ALT-{uuid.uuid4().hex[:8].upper()}",
        district_id=gauge.get("district", "UNKNOWN"),
        kampung_ids=[gauge["id"]],  # In prod: cross-ref with kampung polygon DB
        severity=severity,
        river_level_m=gauge["level_m"],
        predicted_depth_cm=classification.get("predicted_depth_cm"),
        confidence=classification.get("confidence", 0.5),
        time_to_impact_hours=classification.get("time_to_impact_hours"),
        reasoning=classification.get("reasoning", ""),
        recommended_actions=classification.get("recommended_actions", []),
    )


async def poll_and_classify():
    """Main polling loop - fetch gauges, classify, save alerts."""
    print("[AlertAgent] Starting JPS polling loop...")

    try:
        rainfall_data = await fetch_rainfall()
        rainfall_map = {r["station"]: r["last_6h_mm"] for r in rainfall_data}
    except Exception as e:
        print(f"[AlertAgent] Rainfall fetch failed (continuing with 0): {e}")
        rainfall_map = {}

    try:
        gauges = await fetch_gauges()
    except Exception as e:
        print(f"[AlertAgent] Gauge fetch failed: {e}")
        return

    print(f"[AlertAgent] Fetched {len(gauges)} gauges")

    for gauge in gauges:
        district = gauge.get("district", "")
        rainfall_mm = rainfall_map.get(district, 0)

        classification = classify_gauge(gauge, rainfall_mm)
        if classification is None:
            print(f"[AlertAgent] {gauge['name']}: Below threshold - skipping")
            continue

        alert = build_alert(gauge, classification)
        alert_dict = {
            "alert_id": alert.alert_id,
            "district_id": alert.district_id,
            "severity": alert.severity.value,
            "river_level_m": alert.river_level_m,
            "confidence": alert.confidence,
            "reasoning": alert.reasoning,
            "recommended_actions": alert.recommended_actions,
            "predicted_depth_cm": alert.predicted_depth_cm,
            "time_to_impact_hours": alert.time_to_impact_hours,
        }
        alert_id = save_alert(alert_dict)

        print(
            f"[AlertAgent] {gauge['name']} -> {alert.severity.value} "
            f"(confidence: {alert.confidence:.0%}) -> saved as {alert_id}"
        )

        for action in alert.recommended_actions:
            print(f"  -> {action}")


async def run():
    """Entry point - run polling loop continuously."""
    while True:
        try:
            await poll_and_classify()
        except Exception as e:
            print(f"[AlertAgent] Error in poll cycle: {e}")
        print(f"[AlertAgent] Sleeping {POLL_INTERVAL_SECONDS}s...")
        await asyncio.sleep(POLL_INTERVAL_SECONDS)


if __name__ == "__main__":
    asyncio.run(run())
