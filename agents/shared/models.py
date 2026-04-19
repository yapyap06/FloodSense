"""
FloodSense Shared Models
Pydantic schemas used across all agents.
"""
from __future__ import annotations
from enum import Enum
from typing import Optional
from pydantic import BaseModel, Field
from datetime import datetime


# ─── Enums ────────────────────────────────────────────────────────────────────

class AlertSeverity(str, Enum):
    WATCH = "WATCH"
    WARNING = "WARNING"
    DANGER = "DANGER"
    EVACUATE = "EVACUATE"


class IncidentUrgency(str, Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"


class IncidentStatus(str, Enum):
    PENDING = "PENDING"
    DISPATCHED = "DISPATCHED"
    RESCUED = "RESCUED"
    CLOSED = "CLOSED"


class SOSChannel(str, Enum):
    APP = "APP"
    SMS = "SMS"
    WHATSAPP = "WHATSAPP"
    BLE_MESH = "BLE_MESH"
    VOICE = "VOICE"


class VolunteerStatus(str, Enum):
    AVAILABLE = "AVAILABLE"
    ON_MISSION = "ON_MISSION"
    OFF_DUTY = "OFF_DUTY"


# ─── Location ─────────────────────────────────────────────────────────────────

class GeoPoint(BaseModel):
    lat: float = Field(..., ge=-90, le=90, description="Latitude")
    lng: float = Field(..., ge=-180, le=180, description="Longitude")


# ─── Flood Alert ──────────────────────────────────────────────────────────────

class RiverGaugeReading(BaseModel):
    gauge_id: str
    river_name: str
    level_m: float
    normal_m: float
    alert_m: float
    danger_m: float
    trend: str  # "rising" | "falling" | "stable"
    delta_per_hour: float
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class FloodAlert(BaseModel):
    alert_id: str
    district_id: str
    kampung_ids: list[str]
    severity: AlertSeverity
    river_level_m: float
    predicted_depth_cm: Optional[float] = None
    confidence: float = Field(..., ge=0, le=1)
    time_to_impact_hours: Optional[float] = None
    reasoning: str
    recommended_actions: list[str]
    created_at: datetime = Field(default_factory=datetime.utcnow)


# ─── SOS Incident ─────────────────────────────────────────────────────────────

class SOSRequest(BaseModel):
    """Raw SOS input from any channel — may be incomplete."""
    raw_input: str
    channel: SOSChannel
    sender_phone: Optional[str] = None
    location: Optional[GeoPoint] = None
    battery_pct: Optional[int] = Field(None, ge=0, le=100)


class FloodIncident(BaseModel):
    """Parsed, structured incident created by Citizen Agent."""
    sos_id: str
    location: GeoPoint
    address_text: Optional[str] = None
    head_count: Optional[int] = None
    vulnerable: list[str] = []          # e.g. ["infant", "wheelchair", "elderly"]
    floor_level: Optional[int] = None
    urgency: IncidentUrgency
    priority_score: float = 0.0         # Computed by Coordinator Agent
    status: IncidentStatus = IncidentStatus.PENDING
    channel: SOSChannel
    sender_phone: Optional[str] = None
    battery_pct: Optional[int] = None
    assigned_unit_id: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    dispatched_at: Optional[datetime] = None
    resolved_at: Optional[datetime] = None
    language: str = "en"                # detected language code


# ─── Volunteer ────────────────────────────────────────────────────────────────

class Volunteer(BaseModel):
    volunteer_id: str
    name: str
    phone: str
    skills: list[str]           # e.g. ["boat", "medic", "mandarin", "diving"]
    vehicle: Optional[str] = None
    location: Optional[GeoPoint] = None
    readiness_toggle: bool = False
    standing_consent: bool = False
    status: VolunteerStatus = VolunteerStatus.OFF_DUTY
    apm_verified: bool = False
    missions_completed: int = 0


# ─── Shelter / PPS ────────────────────────────────────────────────────────────

class Shelter(BaseModel):
    shelter_id: str
    name: str
    location: GeoPoint
    capacity: int
    occupancy: int = 0
    is_open: bool = False

    @property
    def available_capacity(self) -> int:
        return max(0, self.capacity - self.occupancy)

    @property
    def occupancy_pct(self) -> float:
        return (self.occupancy / self.capacity * 100) if self.capacity > 0 else 0.0


# ─── Inventory ────────────────────────────────────────────────────────────────

class InventoryItem(BaseModel):
    item_id: str
    item_name: str
    quantity: int
    unit: str
    min_threshold: int
    warehouse_id: str
    district_id: str

    @property
    def is_critical(self) -> bool:
        return self.quantity < self.min_threshold


# ─── Situation Report ─────────────────────────────────────────────────────────

class SitRep(BaseModel):
    sitrep_id: str
    district_id: str
    generated_at: datetime = Field(default_factory=datetime.utcnow)
    severity: AlertSeverity
    active_sos: int
    dispatched: int
    resolved: int
    volunteers_active: int
    content: str                # Full AI-generated markdown report
    approved_by: Optional[str] = None
    approved_at: Optional[datetime] = None
