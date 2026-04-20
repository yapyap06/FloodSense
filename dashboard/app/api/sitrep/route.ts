import { NextRequest, NextResponse } from "next/server";
import { GoogleGenerativeAI } from "@google/generative-ai";

const genai = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || "");

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { incidents = [], alerts = [], district = "Klang Valley" } = body;

    const activeSOS = incidents.filter((i: { status: string }) => i.status === "PENDING" || i.status === "DISPATCHED");
    const criticalCount = activeSOS.filter((i: { urgency: string }) => i.urgency === "CRITICAL").length;
    const totalVictims = activeSOS.reduce((s: number, i: { head_count?: number }) => s + (i.head_count || 0), 0);
    const vulnerableGroups = [...new Set(activeSOS.flatMap((i: { vulnerable?: string[] }) => i.vulnerable || []))];
    const latestAlert = alerts[0];

    const prompt = `You are the FloodSense AI Situation Report Generator for Malaysian flood operations.
Generate a concise ADK-format situation report (sitrep) for emergency coordinators.

CURRENT OPERATIONAL DATA:
- District: ${district}
- Active SOS Cases: ${activeSOS.length}
- Critical Cases: ${criticalCount}  
- Total Victims: ${totalVictims}
- Vulnerable Groups: ${vulnerableGroups.join(", ") || "none reported"}
- River Level: ${latestAlert?.river_level_m || "No data"}m
- Alert Level: ${latestAlert?.severity || "WATCH"}
- AI Reasoning: ${latestAlert?.reasoning || "No active alert"}

SOS CASE SUMMARY:
${activeSOS.slice(0, 5).map((i: { sos_id?: string; urgency?: string; address_text?: string; head_count?: number; status?: string }) =>
  `- ${i.sos_id}: ${i.urgency} | ${i.address_text || "Location unknown"} | ${i.head_count || "?"} pax | ${i.status}`
).join("\n")}

Write a structured situation report with these exact sections:
**SITUATION** (2-3 sentences on water levels & immediate threat)
**RESCUE OPERATIONS** (active cases, dispatched units, rescue status)
**RESOURCE STATUS** (available volunteers, shelter capacity estimate)
**RECOMMENDED ACTIONS** (bullet points, specific and actionable)

Keep it under 250 words. Use Malaysian operational terminology. Be direct and specific.`;

    const model = genai.getGenerativeModel({ model: "gemini-1.5-flash" });
    const result = await model.generateContent(prompt);
    const content = result.response.text();

    // Also save to Firestore via Firebase Admin (if available)
    // For now, return the sitrep content directly
    return NextResponse.json({
      success: true,
      sitrep: {
        content,
        district_id: district,
        severity: latestAlert?.severity || "WATCH",
        active_sos: activeSOS.length,
        generated_at: new Date().toISOString(),
        model: "gemini-1.5-flash",
      },
    });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : "Unknown error";
    console.error("[/api/sitrep] Error:", message);
    return NextResponse.json({ success: false, error: message }, { status: 500 });
  }
}
