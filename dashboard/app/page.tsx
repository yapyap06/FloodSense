"use client";
import { useEffect, useState, useCallback } from "react";
import {
  collection, onSnapshot, query,
  orderBy, limit, where
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import { AlertTriangle, Users, Package, Waves, Activity,
         MapPin, Clock, ChevronRight, Zap, Shield, RefreshCw } from "lucide-react";
import clsx from "clsx";
import dynamic from "next/dynamic";

// Load map client-side only (Mapbox GL requires browser)
const FloodMap = dynamic(() => import("@/components/FloodMap"), { ssr: false });

// ── Types ─────────────────────────────────────────────────────────────────────
type Severity = "EVACUATE" | "DANGER" | "WARNING" | "WATCH";
type IncidentStatus = "PENDING" | "DISPATCHED" | "RESCUED" | "CLOSED";

interface Incident {
  id: string;
  sos_id: string;
  urgency: "CRITICAL" | "HIGH" | "MEDIUM" | "LOW";
  status: IncidentStatus;
  head_count?: number;
  vulnerable: string[];
  address_text?: string;
  assigned_unit_id?: string;
  channel: string;
  created_at?: { seconds: number };
}

interface Alert {
  id: string;
  district_id: string;
  severity: Severity;
  river_level_m: number;
  reasoning: string;
  recommended_actions: string[];
  confidence: number;
  created_at?: { seconds: number };
}

interface SitRep {
  id: string;
  content: string;
  district_id: string;
  severity: Severity;
  active_sos: number;
  generated_at?: { seconds: number };
}

// ── Helpers ───────────────────────────────────────────────────────────────────
const SEVERITY_CONFIG: Record<Severity, { label: string; color: string; bg: string; pulse: boolean }> = {
  EVACUATE: { label: "EVACUATE",  color: "text-purple-300",  bg: "bg-purple-900/50 border-purple-500",  pulse: true },
  DANGER:   { label: "DANGER",    color: "text-red-300",     bg: "bg-red-900/50 border-red-500",         pulse: true },
  WARNING:  { label: "WARNING",   color: "text-amber-300",   bg: "bg-amber-900/50 border-amber-500",     pulse: false },
  WATCH:    { label: "WATCH",     color: "text-blue-300",    bg: "bg-blue-900/50 border-blue-500",       pulse: false },
};

const URGENCY_DOT: Record<string, string> = {
  CRITICAL: "bg-red-500",
  HIGH:     "bg-orange-500",
  MEDIUM:   "bg-amber-400",
  LOW:      "bg-blue-400",
};

function timeAgo(seconds?: number) {
  if (!seconds) return "just now";
  const diff = Math.floor(Date.now() / 1000 - seconds);
  if (diff < 60) return `${diff}s ago`;
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  return `${Math.floor(diff / 3600)}h ago`;
}

// ── Seed data for demo (shown when Firestore is empty) ───────────────────────
const DEMO_INCIDENTS: Incident[] = [
  { id: "1", sos_id: "SOS-A3B7C1", urgency: "CRITICAL", status: "PENDING",
    head_count: 5, vulnerable: ["infant", "wheelchair"], address_text: "No 47 Jalan Meranti, KL",
    channel: "APP", created_at: { seconds: Math.floor(Date.now() / 1000) - 180 } },
  { id: "2", sos_id: "SOS-D4E8F2", urgency: "CRITICAL", status: "DISPATCHED",
    head_count: 2, vulnerable: ["elderly"], address_text: "Sri Muda, Shah Alam",
    assigned_unit_id: "VOL_001", channel: "SMS", created_at: { seconds: Math.floor(Date.now() / 1000) - 540 } },
  { id: "3", sos_id: "SOS-G9H1I3", urgency: "HIGH", status: "PENDING",
    head_count: 7, vulnerable: [], address_text: "Tmn Mawar, Klang",
    channel: "WHATSAPP", created_at: { seconds: Math.floor(Date.now() / 1000) - 90 } },
  { id: "4", sos_id: "SOS-J2K5L6", urgency: "MEDIUM", status: "RESCUED",
    head_count: 3, vulnerable: [], address_text: "Brickfields, KL",
    channel: "APP", created_at: { seconds: Math.floor(Date.now() / 1000) - 1800 } },
];

const DEMO_ALERT: Alert = {
  id: "1", district_id: "Klang Valley", severity: "DANGER",
  river_level_m: 5.8, confidence: 0.91,
  reasoning: "Sg Klang at Jln Raja Laut crossing 5.8m — 0.4m above alert threshold. Rising at 2cm/hr.",
  recommended_actions: ["Activate PPS shelters in KL & Selangor", "Deploy Bomba boats to Sri Muda", "Issue SMS alert to Klang Valley subscribers"],
};

const DEMO_SITREP: SitRep = {
  id: "1", district_id: "Klang Valley", severity: "DANGER",
  active_sos: 3, generated_at: { seconds: Math.floor(Date.now() / 1000) - 300 },
  content: `**SITUATION**\nWater levels at Sg Klang (Jalan Raja Laut gauge) have risen to 5.8m — 0.4m above the alert threshold. Rising rate is 2cm/hour. Peak predicted at approximately 19:30 tonight.\n\n**RESCUE OPERATIONS**\n3 active SOS cases (1 CRITICAL with infant + wheelchair). 1 rescue dispatched (Volunteer Ahmad Farid). 1 case resolved. Priority escalation: 2 unassigned CRITICAL cases require immediate Bomba deployment.\n\n**RESOURCE STATUS**\nVolunteers available: 2 of 3 registered. Power banks at 40 units — below 50-unit threshold. Food and water stocks sufficient for 48h.\n\n**RECOMMENDED ACTIONS**\n• Deploy Bomba Boat Unit 7 to No 47 Jalan Meranti (infant + wheelchair — CRITICAL)\n• Open PPS Stadium Shah Alam — estimated need 400–600 displaced\n• Request emergency power bank resupply from NADMA warehouse WH_SEL_001`,
};

// ── Main Dashboard ────────────────────────────────────────────────────────────
export default function Dashboard() {
  const [incidents, setIncidents]   = useState<Incident[]>(DEMO_INCIDENTS);
  const [activeAlert, setAlert]     = useState<Alert>(DEMO_ALERT);
  const [sitrep, setSitrep]         = useState<SitRep>(DEMO_SITREP);
  const [liveData, setLiveData]     = useState(false);
  const [currentTime, setCurrentTime] = useState<Date | null>(null);
  const [generatingSitrep, setGeneratingSitrep] = useState(false);
  const [sitrepApproved, setSitrepApproved] = useState(false);
  const [forwarding, setForwarding] = useState(false);

  const generateSitrep = useCallback(async () => {
    setGeneratingSitrep(true);
    try {
      const res = await fetch("/api/sitrep", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ incidents, alerts: [activeAlert], district: activeAlert.district_id }),
      });
      const data = await res.json();
      if (data.success) {
        setSitrep(prev => ({ ...prev, content: data.sitrep.content, generated_at: { seconds: Math.floor(Date.now() / 1000) } }));
        setSitrepApproved(false);
      }
    } catch (e) {
      console.error("Sitrep generation failed:", e);
    } finally {
      setGeneratingSitrep(false);
    }
  }, [incidents, activeAlert]);

  const approveAndForward = useCallback(async () => {
    setForwarding(true);
    try {
      if (db && sitrep.id) {
        const { doc, updateDoc } = await import("firebase/firestore");
        await updateDoc(doc(db, "sitreps", sitrep.id), { approved: true, approved_at: new Date().toISOString() });
      }
      setSitrepApproved(true);
      // Simulate MKN email/WhatsApp forward
      console.log("[FloodSense] Sitrep forwarded to MKN duty officer:", sitrep.id);
    } catch (e) {
      console.error("Forward failed:", e);
    } finally {
      setForwarding(false);
    }
  }, [db, sitrep]);

  // Keyboard shortcuts: D=dismiss, A=assign, S=sitrep focus
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) return;
      if (e.key === 's' || e.key === 'S') { generateSitrep(); }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [generateSitrep]);

  // Clock — client only to avoid hydration mismatch
  useEffect(() => {
    setCurrentTime(new Date());
    const t = setInterval(() => setCurrentTime(new Date()), 1000);
    return () => clearInterval(t);
  }, []);

  // Firestore real-time listeners (only if Firebase is configured)
  useEffect(() => {
    if (!db) return; // No Firebase key — use demo data

    const unsubIncidents = onSnapshot(
      query(collection(db, "incidents"), orderBy("created_at", "desc"), limit(20)),
      (snap) => {
        if (!snap.empty) {
          setIncidents(snap.docs.map(d => ({ id: d.id, ...d.data() } as Incident)));
          setLiveData(true);
        }
      },
      () => {}
    );

    const unsubAlerts = onSnapshot(
      query(collection(db, "alerts"), orderBy("created_at", "desc"), limit(1)),
      (snap) => {
        if (!snap.empty) {
          setAlert({ id: snap.docs[0].id, ...snap.docs[0].data() } as Alert);
        }
      },
      () => {}
    );

    const unsubSitrep = onSnapshot(
      query(collection(db, "sitreps"), orderBy("generated_at", "desc"), limit(1)),
      (snap) => {
        if (!snap.empty) {
          setSitrep({ id: snap.docs[0].id, ...snap.docs[0].data() } as SitRep);
        }
      },
      () => {}
    );

    return () => { unsubIncidents(); unsubAlerts(); unsubSitrep(); };
  }, []);

  const pending    = incidents.filter(i => i.status === "PENDING");
  const dispatched = incidents.filter(i => i.status === "DISPATCHED");
  const resolved   = incidents.filter(i => ["RESCUED", "CLOSED"].includes(i.status));
  const critical   = incidents.filter(i => i.urgency === "CRITICAL" && i.status === "PENDING");
  const sev        = SEVERITY_CONFIG[activeAlert.severity] ?? SEVERITY_CONFIG.WARNING;

  return (
    <div className="h-screen flex flex-col overflow-hidden">

      {/* ── Top Nav ─────────────────────────────────────────── */}
      <header className="flex items-center justify-between px-5 py-3 border-b border-[--border] bg-[--surface] flex-shrink-0">
        <div className="flex items-center gap-3">
          <Waves className="text-blue-400 w-6 h-6" />
          <span className="font-bold text-lg tracking-tight">FloodSense</span>
          <span className="text-[--text-muted] text-sm">Ops Command Centre</span>
        </div>

        <div className="flex items-center gap-3">
          {/* Gemini Sitrep Button */}
          <button
            onClick={generateSitrep}
            disabled={generatingSitrep}
            className="flex items-center gap-2 px-3 py-1.5 rounded-lg text-xs font-semibold bg-[--danger-red]/10 border border-[--danger-red]/40 text-[--danger-red] hover:bg-[--danger-red]/20 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <RefreshCw className={clsx("w-3 h-3", generatingSitrep && "animate-spin")} />
            {generatingSitrep ? "Generating..." : "Gemini Sitrep"}
          </button>
          {/* Severity Badge */}
          <span className={clsx("flex items-center gap-2 px-3 py-1 rounded-full text-sm font-semibold border", sev.bg, sev.color, sev.pulse && "pulse-critical")}>
            <span className={clsx("w-2 h-2 rounded-full animate-pulse", sev.color.replace("text-", "bg-"))} />
            {activeAlert.district_id} — {sev.label}
          </span>

          {/* Live / Demo indicator */}
          <span className={clsx("text-xs px-2 py-1 rounded border", liveData
            ? "border-green-600 text-green-400 bg-green-900/20"
            : "border-amber-600 text-amber-400 bg-amber-900/20")}>
            {liveData ? "🟢 LIVE" : "🟡 DEMO"}
          </span>

          <span className="text-[--text-muted] text-sm font-mono">
            {currentTime ? currentTime.toLocaleTimeString("en-MY", { hour12: false }) : "--:--:--"}
          </span>
        </div>
      </header>

      {/* ── Body ────────────────────────────────────────────── */}
      <div className="flex flex-1 overflow-hidden gap-0">

        {/* ── Left: Map ─────────────────────────────────────── */}
        <div className="flex-1 relative p-3">
          <div className="card h-full relative overflow-hidden">
            <FloodMap incidents={incidents} />

            {/* Map legend */}
            <div className="absolute bottom-4 left-4 card px-3 py-2 flex flex-col gap-1 text-xs">
              <div className="flex items-center gap-2"><span className="w-3 h-3 rounded-full bg-red-500/70 border border-red-400" />Critical SOS</div>
              <div className="flex items-center gap-2"><span className="w-3 h-3 rounded-full bg-orange-500/70 border border-orange-400" />High SOS</div>
              <div className="flex items-center gap-2"><span className="w-3 h-3 rounded-full bg-green-500/70 border border-green-400" />Volunteer</div>
              <div className="flex items-center gap-2"><span className="w-3 h-3 rounded bg-blue-500/40 border border-blue-400" />Flood Zone</div>
            </div>
          </div>
        </div>

        {/* ── Right panel ───────────────────────────────────── */}
        <div className="w-[340px] flex flex-col gap-3 p-3 pl-0 overflow-hidden">

          {/* KPI row */}
          <div className="grid grid-cols-3 gap-2">
            {[
              { icon: AlertTriangle, label: "Active SOS", value: pending.length, color: "text-red-400" },
              { icon: Users,         label: "Dispatched", value: dispatched.length, color: "text-amber-400" },
              { icon: Shield,        label: "Resolved",   value: resolved.length,   color: "text-teal-400" },
            ].map(({ icon: Icon, label, value, color }) => (
              <div key={label} className="card p-3 text-center">
                <Icon className={clsx("w-4 h-4 mx-auto mb-1", color)} />
                <div className={clsx("text-xl font-bold", color)}>{value}</div>
                <div className="text-[10px] text-[--text-muted] mt-0.5">{label}</div>
              </div>
            ))}
          </div>

          {/* SOS Queue */}
          <div className="card flex-1 flex flex-col overflow-hidden">
            <div className="flex items-center justify-between p-3 border-b border-[--border]">
              <span className="font-semibold text-sm flex items-center gap-2">
                <AlertTriangle className="w-3.5 h-3.5 text-red-400" />
                SOS Queue
              </span>
              {critical.length > 0 && (
                <span className="bg-red-600 text-white text-xs px-2 py-0.5 rounded-full pulse-critical">
                  {critical.length} CRITICAL
                </span>
              )}
            </div>

            <div className="scroll-panel flex-1">
              {incidents.filter(i => i.status !== "CLOSED").map(inc => (
                <div key={inc.id}
                  className={clsx(
                    "p-3 border-b border-[--border] hover:bg-[--surface2] transition-colors cursor-pointer",
                    inc.urgency === "CRITICAL" && inc.status === "PENDING" && "bg-red-950/20"
                  )}>
                  <div className="flex items-start justify-between gap-2">
                    <div className="flex items-center gap-2 flex-1 min-w-0">
                      <span className={clsx("w-2.5 h-2.5 rounded-full flex-shrink-0 mt-1", URGENCY_DOT[inc.urgency] ?? "bg-gray-400")} />
                      <div className="min-w-0">
                        <div className="text-sm font-medium truncate">
                          {inc.address_text ?? `SOS ${inc.sos_id}`}
                        </div>
                        <div className="text-xs text-[--text-muted] mt-0.5 flex flex-wrap gap-1">
                          {inc.head_count && <span>{inc.head_count} people</span>}
                          {inc.vulnerable?.map(v => (
                            <span key={v} className="bg-[--surface2] px-1.5 rounded">{v}</span>
                          ))}
                        </div>
                      </div>
                    </div>
                    <div className="text-right flex-shrink-0">
                      <span className={clsx("text-xs px-1.5 py-0.5 rounded font-medium",
                        inc.status === "PENDING"    ? "bg-red-900/60 text-red-300" :
                        inc.status === "DISPATCHED" ? "bg-amber-900/60 text-amber-300" :
                        "bg-teal-900/60 text-teal-300"
                      )}>
                        {inc.status === "DISPATCHED" ? "🚤 EN ROUTE" : inc.status}
                      </span>
                      <div className="text-[10px] text-[--text-muted] mt-1 flex items-center gap-1 justify-end">
                        <Clock className="w-2.5 h-2.5" />
                        {timeAgo(inc.created_at?.seconds)}
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* AI Sitrep */}
          <div className="card flex flex-col" style={{ height: "220px" }}>
            <div className="flex items-center justify-between p-3 border-b border-[--border]">
              <span className="font-semibold text-sm flex items-center gap-2">
                <Activity className="w-3.5 h-3.5 text-blue-400" />
                AI Sitrep
              </span>
              <span className="text-[10px] text-[--text-muted] flex items-center gap-1">
                <Zap className="w-2.5 h-2.5 text-amber-400" />
                {timeAgo(sitrep.generated_at?.seconds)}
              </span>
            </div>
            <div className="scroll-panel flex-1 p-3 text-xs text-[--text-muted] leading-relaxed whitespace-pre-wrap">
              {sitrep.content.replace(/\*\*/g, "").replace(/^## .+\n/gm, "").trim()}
            </div>
            <div className="p-2 border-t border-[--border] flex gap-2">
              <button
                onClick={sitrepApproved ? undefined : approveAndForward}
                disabled={forwarding || sitrepApproved}
                className={clsx(
                  "flex-1 py-1.5 rounded text-xs font-medium transition-colors flex items-center justify-center gap-1",
                  sitrepApproved
                    ? "bg-green-800/60 text-green-300 cursor-default"
                    : "bg-blue-700 hover:bg-blue-600 disabled:opacity-50"
                )}
              >
                {forwarding ? <RefreshCw className="w-3 h-3 animate-spin" /> : null}
                {sitrepApproved ? "✅ Forwarded to MKN" : "✅ Approve & Forward"}
              </button>
              <button
                onClick={generateSitrep}
                disabled={generatingSitrep}
                className="px-3 py-1.5 rounded text-xs border border-[--border] hover:bg-[--surface2] transition-colors disabled:opacity-50"
                title="Keyboard: S"
              >
                {generatingSitrep ? <RefreshCw className="w-3 h-3 animate-spin" /> : "↻"}
              </button>
            </div>
          </div>

        </div>
      </div>

      {/* ── Bottom bar: Supply levels ─────────────────────── */}
      <footer className="border-t border-[--border] bg-[--surface] px-5 py-2 flex items-center gap-6 flex-shrink-0">
        <span className="text-xs text-[--text-muted] font-medium">SUPPLY</span>
        {[
          { label: "Food Packs",   pct: 87, ok: true },
          { label: "Water",        pct: 71, ok: true },
          { label: "Medical Kits", pct: 44, ok: false },
          { label: "Power Banks",  pct: 32, ok: false },
          { label: "Baby Formula", pct: 19, ok: false },
        ].map(({ label, pct, ok }) => (
          <div key={label} className="flex items-center gap-2">
            <span className="text-xs text-[--text-muted]">{label}</span>
            <div className="w-16 h-1.5 bg-[--border] rounded-full">
              <div
                className={clsx("h-full rounded-full transition-all",
                  pct > 60 ? "bg-teal-500" : pct > 30 ? "bg-amber-500" : "bg-red-500"
                )}
                style={{ width: `${pct}%` }}
              />
            </div>
            <span className={clsx("text-xs font-mono", pct > 60 ? "text-teal-400" : pct > 30 ? "text-amber-400" : "text-red-400")}>
              {pct}% {!ok && "⚠"}
            </span>
          </div>
        ))}
        <div className="ml-auto flex items-center gap-2 text-xs text-[--text-muted]">
          <MapPin className="w-3 h-3" />
          Klang Valley EOC &nbsp;|&nbsp; JPS River: 5.8m ↑ &nbsp;|&nbsp;
          <span className="text-blue-400">6 agencies connected</span>
        </div>
      </footer>
    </div>
  );
}
