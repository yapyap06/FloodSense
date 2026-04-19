"""
FloodSense — Start Everything
==============================
Launches the unified Agent API Server which internally runs all 4 agents
as background asyncio loops. Also starts the mock JPS API.

Usage:
  cd agents
  $env:PYTHONPATH = "."
  $env:PYTHONUTF8 = "1"
  python run_all_agents.py
"""
import subprocess
import sys
import os
import time

print("🌊 FloodSense — Starting Backend")
print()

# Check the mock JPS API is running
import urllib.request
try:
    urllib.request.urlopen("http://localhost:3001/gauges", timeout=2)
    print("  ✅ Mock JPS API already running on :3001")
except Exception:
    print("  ⚠️  Mock JPS API not detected on :3001")
    print("     Run in a separate terminal:")
    print("     npx json-server --watch mock-api/db.json --port 3001")
    print()

print("  🤖 Starting Agent API Server on http://localhost:8000")
print("     All 4 agents will run as background loops:")
print("     - Alert Agent     (polls JPS every 60s)")
print("     - Citizen Agent   (parses SOS on /sos endpoint)")
print("     - Coordinator     (dispatches volunteers every 90s)")
print("     - Resource Agent  (monitors inventory every 5m)")
print()
print("  📡 API Docs: http://localhost:8000/docs")
print("  ❤️  Health:   http://localhost:8000/health")
print()

# Set environment
env = os.environ.copy()
env["PYTHONPATH"] = os.path.dirname(os.path.abspath(__file__))
env["PYTHONUTF8"] = "1"

subprocess.run(
    [sys.executable, "-m", "uvicorn", "agent_server:app",
     "--host", "0.0.0.0", "--port", "8000", "--reload"],
    cwd=os.path.dirname(os.path.abspath(__file__)),
    env=env,
)
