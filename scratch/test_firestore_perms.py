import os
import firebase_admin
from firebase_admin import credentials, firestore

# Point to the same file the agents use
sa_path = "c:/Users/User/Downloads/FloodSense/agents/firebase-service-account.json"

if not os.path.exists(sa_path):
    print(f"ERROR: {sa_path} not found")
    exit(1)

print(f"Testing service account: {sa_path}")
cred = credentials.Certificate(sa_path)
app = firebase_admin.initialize_app(cred, name="test-app")
db = firestore.client(app=app)

try:
    print("Attempting to read from 'incidents' collection...")
    # Just try to get one doc
    docs = db.collection("incidents").limit(1).get()
    print(f"Success! Found {len(docs)} documents.")
    
    print("Attempting to write a test document...")
    ref = db.collection("test_connection").add({"test": True, "time": firestore.SERVER_TIMESTAMP})
    print(f"Success! Written doc ID: {ref[1].id}")
    
except Exception as e:
    print(f"FAILED: {e}")
finally:
    firebase_admin.delete_app(app)
