import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore
import json

app = firebase_admin.initialize_app()
db = firestore.client()
docs = db.collection('damage_claims').stream()
for d in docs:
    data = d.to_dict()
    if '19DAE962522' in data.get('claim_id', ''):
        print(json.dumps(data, indent=2, default=str))
