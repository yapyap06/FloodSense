# ────────────────────────────────────────────────────────────────────────────
# FloodSense Agent API – Google Cloud Run Dockerfile
# ────────────────────────────────────────────────────────────────────────────
FROM python:3.11-slim

# Prevents .pyc files and enables real-time logging in Cloud Run
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Install OS-level dependencies for chromadb
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy all agent source code
COPY . .

# Cloud Run injects PORT env variable (default 8080)
ENV PORT=8080

# Start the FastAPI server
CMD exec uvicorn agent_server:app --host 0.0.0.0 --port ${PORT}
