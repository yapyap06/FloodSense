"use client";
import { useEffect, useRef } from "react";

// ── Incident type (passed from parent) ───────────────────────────────────────
interface Incident {
  id: string;
  urgency: string;
  status: string;
  head_count?: number;
  vulnerable?: string[];
  address_text?: string;
}

interface Props {
  incidents: Incident[];
}

// ── Demo pins (hardcoded for demo; replaced by real Firestore coords in prod) ─
const SOS_PINS = [
  { lat: 3.139, lng: 101.687, urgency: "CRITICAL", label: "No 47 Jalan Meranti, KL",  info: "5 people · infant + wheelchair" },
  { lat: 3.073, lng: 101.518, urgency: "CRITICAL", label: "Sri Muda, Shah Alam",       info: "Elderly couple · 2nd floor" },
  { lat: 3.044, lng: 101.448, urgency: "HIGH",     label: "Tmn Mawar, Klang",          info: "Family of 7 · ground floor" },
];

const VOLUNTEER_PINS = [
  { lat: 3.130, lng: 101.680, name: "Ahmad Farid",  status: "🚤 En route to SOS-2" },
  { lat: 3.150, lng: 101.710, name: "Lim Wei Chen", status: "✅ Available" },
];

const SHELTERS = [
  { lat: 3.164, lng: 101.701, name: "PPS SK Kpg Baru",       cap: 500  },
  { lat: 3.063, lng: 101.509, name: "PPS Stadium Shah Alam",  cap: 5000 },
  { lat: 3.044, lng: 101.448, name: "PPS Dewan Klang",        cap: 1200 },
];

// ── Flood zone polygon (Sri Muda area) ───────────────────────────────────────
const FLOOD_POLYGON = [
  [3.09, 101.50], [3.09, 101.56],
  [3.05, 101.56], [3.05, 101.50],
] as [number, number][];

export default function FloodMap({ incidents }: Props) {
  const mapRef      = useRef<HTMLDivElement>(null);
  const mapInstance = useRef<any>(null);

  useEffect(() => {
    if (typeof window === "undefined" || !mapRef.current || mapInstance.current) return;

    // Dynamically import Leaflet (browser-only)
    import("leaflet").then((L) => {
      // Fix Leaflet default icon path broken by bundlers
      delete (L.Icon.Default.prototype as any)._getIconUrl;
      L.Icon.Default.mergeOptions({
        iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
        iconUrl:       "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
        shadowUrl:     "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
      });

      const map = L.map(mapRef.current!, {
        center: [3.139, 101.687],
        zoom: 11,
        zoomControl: true,
        attributionControl: true,
      });

      mapInstance.current = map;

      // ── Dark OpenStreetMap tile layer (no key needed!) ────────────────────
      L.tileLayer(
        "https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png",
        {
          attribution:
            '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> &copy; <a href="https://carto.com/attributions">CARTO</a>',
          subdomains: "abcd",
          maxZoom: 19,
        }
      ).addTo(map);

      // ── Flood zone polygon ────────────────────────────────────────────────
      L.polygon(FLOOD_POLYGON, {
        color:       "#60a5fa",
        fillColor:   "#1e40af",
        fillOpacity: 0.35,
        weight:      2,
        dashArray:   "6 4",
      })
        .addTo(map)
        .bindPopup(
          `<b style="color:#60a5fa">⚠️ Active Flood Zone</b><br/>
           Sri Muda / Klang Valley<br/>
           Est. depth: 0.8–1.5m`
        );

      // ── SOS incident pins ─────────────────────────────────────────────────
      SOS_PINS.forEach((pin) => {
        const isCritical = pin.urgency === "CRITICAL";
        const icon = L.divIcon({
          html: `
            <div style="
              width:32px;height:32px;border-radius:50%;
              background:${isCritical ? "#ef4444" : "#f97316"};
              border:2px solid ${isCritical ? "#fca5a5" : "#fdba74"};
              display:flex;align-items:center;justify-content:center;
              font-size:16px;
              box-shadow:0 0 ${isCritical ? "12px" : "6px"} ${isCritical ? "#ef444490" : "#f9731690"};
              ${isCritical ? "animation:pulsePin 1.5s infinite;" : ""}
            ">🆘</div>`,
          className: "",
          iconSize: [32, 32],
          iconAnchor: [16, 16],
        });
        L.marker([pin.lat, pin.lng], { icon })
          .addTo(map)
          .bindPopup(
            `<div style="font-size:12px;min-width:160px">
              <strong style="color:${isCritical ? "#f87171" : "#fb923c"}">${pin.urgency}</strong><br/>
              📍 ${pin.label}<br/>
              👥 ${pin.info}
            </div>`
          );
      });

      // ── Volunteer pins ────────────────────────────────────────────────────
      VOLUNTEER_PINS.forEach((v) => {
        const icon = L.divIcon({
          html: `<div style="
            width:28px;height:28px;border-radius:50%;
            background:#16a34a;border:2px solid #86efac;
            display:flex;align-items:center;justify-content:center;
            font-size:14px;box-shadow:0 0 8px #16a34a80;">🙋</div>`,
          className: "",
          iconSize: [28, 28],
          iconAnchor: [14, 14],
        });
        L.marker([v.lat, v.lng], { icon })
          .addTo(map)
          .bindPopup(`<div style="font-size:12px"><strong>${v.name}</strong><br/>${v.status}</div>`);
      });

      // ── Shelter pins ──────────────────────────────────────────────────────
      SHELTERS.forEach((s) => {
        const icon = L.divIcon({
          html: `<div style="
            width:24px;height:24px;border-radius:4px;
            background:#0f766e;border:2px solid #5eead4;
            display:flex;align-items:center;justify-content:center;
            font-size:12px;box-shadow:0 0 6px #0f766e80;">🏠</div>`,
          className: "",
          iconSize: [24, 24],
          iconAnchor: [12, 12],
        });
        L.marker([s.lat, s.lng], { icon })
          .addTo(map)
          .bindPopup(
            `<div style="font-size:12px">
              <strong style="color:#5eead4">PPS Shelter</strong><br/>
              📍 ${s.name}<br/>
              👥 Capacity: ${s.cap}
            </div>`
          );
      });

      // Pulse animation CSS
      const style = document.createElement("style");
      style.textContent = `
        @keyframes pulsePin {
          0%   { box-shadow: 0 0 0 0 rgba(239,68,68,0.6); }
          70%  { box-shadow: 0 0 0 10px rgba(239,68,68,0); }
          100% { box-shadow: 0 0 0 0 rgba(239,68,68,0); }
        }
        .leaflet-popup-content-wrapper {
          background: #152236 !important;
          border: 1px solid #243550 !important;
          color: #f0f4f8 !important;
          border-radius: 8px !important;
        }
        .leaflet-popup-tip { background: #152236 !important; }
        .leaflet-popup-close-button { color: #8AA3C0 !important; }
      `;
      document.head.appendChild(style);
    });

    // Load Leaflet CSS
    if (!document.getElementById("leaflet-css")) {
      const link  = document.createElement("link");
      link.id     = "leaflet-css";
      link.rel    = "stylesheet";
      link.href   = "https://unpkg.com/leaflet@1.9.4/dist/leaflet.css";
      document.head.appendChild(link);
    }

    return () => {
      if (mapInstance.current) {
        mapInstance.current.remove();
        mapInstance.current = null;
      }
    };
  }, []);

  return <div ref={mapRef} style={{ width: "100%", height: "100%", borderRadius: "12px" }} />;
}
