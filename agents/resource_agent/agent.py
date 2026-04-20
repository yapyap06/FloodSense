"""
Resource Agent - FloodSense
Tracks warehouse inventory, detects critical stock levels,
and recommends supply deployment routes.
"""
from __future__ import annotations
import os
import json
from google import genai
from dotenv import load_dotenv
from shared.models import InventoryItem

load_dotenv()
client = genai.Client(api_key=os.environ["GEMINI_API_KEY"], http_options={'api_version': 'v1'})

# --- Warehouse simulation (Firestore in prod) ---------------------------------
MOCK_INVENTORY = [
    InventoryItem(item_id="INV_001", item_name="Food Pack (3-day)", quantity=1200, unit="packs",
                  min_threshold=200, warehouse_id="WH_KL_001", district_id="Kuala Lumpur"),
    InventoryItem(item_id="INV_002", item_name="Drinking Water 1.5L", quantity=3000, unit="bottles",
                  min_threshold=500, warehouse_id="WH_KL_001", district_id="Kuala Lumpur"),
    InventoryItem(item_id="INV_003", item_name="Power Bank 10000mAh", quantity=40, unit="units",
                  min_threshold=50, warehouse_id="WH_KL_001", district_id="Kuala Lumpur"),
    InventoryItem(item_id="INV_004", item_name="First Aid Kit", quantity=45, unit="kits",
                  min_threshold=30, warehouse_id="WH_SEL_001", district_id="Selangor"),
    InventoryItem(item_id="INV_005", item_name="Baby Formula", quantity=15, unit="cans",
                  min_threshold=20, warehouse_id="WH_SEL_001", district_id="Selangor"),
]

SUPPLY_PROMPT = """\
You are FloodSense Resource Agent. Analyse this inventory and recommend immediate actions.
Focus on CRITICAL items below minimum threshold first.
Be concise and actionable - 1 recommendation per item, max 50 words each.

Inventory:
{inventory_json}

Respond as JSON array:
[{{"item": "name", "status": "CRITICAL|LOW|OK", "action": "specific action to take", "priority": 1-5}}]
"""


def check_inventory() -> list[dict]:
    """Check all inventory items and get AI recommendations for critical ones."""
    critical = [item for item in MOCK_INVENTORY if item.is_critical]

    if not critical:
        print("[ResourceAgent] All inventory levels OK")
        return []

    inventory_data = [
        {
            "item": item.item_name,
            "quantity": item.quantity,
            "unit": item.unit,
            "min_threshold": item.min_threshold,
            "warehouse": item.warehouse_id,
            "is_critical": item.is_critical,
        }
        for item in MOCK_INVENTORY
    ]

    prompt = SUPPLY_PROMPT.format(inventory_json=json.dumps(inventory_data, indent=2))

    try:
        response = client.models.generate_content(model="gemini-1.5-flash", contents=prompt)
        raw = response.text.strip().lstrip("```json").rstrip("```").strip()
        recommendations = json.loads(raw)
    except Exception as e:
        print(f"[ResourceAgent] AI recommendation error: {e}")
        recommendations = [
            {"item": i.item_name, "status": "CRITICAL", "action": "Restock immediately", "priority": 1}
            for i in critical
        ]

    print(f"\n[ResourceAgent] {len(critical)} critical items found:")
    for rec in sorted(recommendations, key=lambda x: x.get("priority", 5)):
        status_icon = "[CRITICAL]" if rec["status"] == "CRITICAL" else "[LOW]"
        print(f"  {status_icon} [{rec['priority']}] {rec['item']}: {rec['action']}")

    return recommendations


def recommend_prepositioning(district_id: str, predicted_households: int) -> dict:
    """AI-powered pre-positioning recommendation before a flood hits."""
    prompt = f"""\
Calculate recommended supply quantities for a flood-prone district.

District: {district_id}
Predicted affected households: {predicted_households}
Planning horizon: 7 days

Standard ratios (adjust for local context):
- Food: 1 pack per person per 3 days
- Water: 15L per person per day
- Medical kits: 1 per 10 households
- Power banks: 1 per 2 households

Respond as JSON with item names as keys and quantities as int values.
Include a "reasoning" key with 1-sentence justification.
"""
    try:
        response = client.models.generate_content(model="gemini-1.5-flash", contents=prompt)
        raw = response.text.strip().lstrip("```json").rstrip("```").strip()
        return json.loads(raw)
    except Exception as e:
        print(f"[ResourceAgent] Pre-positioning error: {e}")
        persons = predicted_households * 4  # avg household size
        return {
            "Food Pack (3-day)": predicted_households * 7,
            "Drinking Water 1.5L": persons * 15 * 7,
            "Medical kits": predicted_households // 10,
            "Power banks": predicted_households // 2,
            "reasoning": "Standard ratios applied (AI call failed)",
        }


if __name__ == "__main__":
    print("=== INVENTORY CHECK ===")
    recs = check_inventory()

    print("\n=== PRE-POSITIONING RECOMMENDATION ===")
    rec = recommend_prepositioning("Klang Valley", 5000)
    print(json.dumps(rec, indent=2))
