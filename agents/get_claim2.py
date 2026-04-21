import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from shared.firestore_client import _get_db
import json

db = _get_db()
docs = db.collection('damage_claims').stream()
for d in docs:
    data = d.to_dict()
    if '19DAE962522' in data.get('claim_id', ''):
        print(json.dumps(data, indent=2, default=str))
