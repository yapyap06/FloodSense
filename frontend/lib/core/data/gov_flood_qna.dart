// ============================================================
// FLOODSENSE AI — FLOOD QnA KNOWLEDGE BASE
// Targeted: Government Officers (NADMA, Bomba, JKM, APM, JPS, MKN)
// Language: Bilingual — Bahasa Malaysia / English
// Version: 1.0
// ============================================================

const List<(List<String>, String)> govFloodQnA = [
  // ── CATEGORY 1: ALERT LEVELS & WARNING SYSTEMS (JPS / NADMA) ────────────────
  (["alert levels", "warning levels", "paras amaran", "peringkat amaran", "jps", "water level", "paras air", "sungai", "river", "danger", "bahaya"],
   "**Alert Levels (JPS Standard):**\n"
   "• **Normal:** Safe level.\n"
   "• **Waspada (Alert):** Water rises; continuous monitoring required. Activate local CP (Command Post).\n"
   "• **Amaran (Warning):** Approaching danger. Evacuation preparations activated.\n"
   "• **Bahaya (Danger):** Overflow immanent or occurring. Mandatory evacuation ordered by MKN/Police."),

  (["siren", "warning siren", "bunyi siren", "siren amaran"],
   "**Warning Sirens (JPS):**\n"
   "Sirens are activated when river levels hit the 'Amaran' (Warning) threshold. Officers must immediately blast SMS alerts via the FloodSense Command dashboard and coordinate with APM to secure the perimeter."),

  (["smart tunnel", "terowong smart", "mode 3", "mode 4"],
   "**SMART Tunnel Operations:**\n"
   "• **Mode 1/2:** Normal/Moderate rain. Open to traffic.\n"
   "• **Mode 3:** Heavy rain, major storms. Closed to traffic, partially diverting floodwater.\n"
   "• **Mode 4:** Severe flooding. Totally closed to traffic, diverting full flood capacity from Sg Klang/Sg Ampang."),

  (["metmalaysia", "cuaca", "weather alert", "amaran cuaca", "hujan lebat", "heavy rain"],
   "**MetMalaysia Weather Alerts:**\n"
   "• **Kuning (Waspada):** Continuous rain expected (1-3 days).\n"
   "• **Jingga (Buruk):** Heavy continuous rain expected.\n"
   "• **Merah (Bahaya):** Extreme heavy rain (>150mm/24h). Immediate localized flooding risk. All rescue agencies on standby."),

  (["air pasang", "high tide", "fenomena air pasang besar", "coastal", "pantai"],
   "**High Tide Phenomenon (Air Pasang Besar):**\n"
   "Coastal areas (Klang, Kuala Selangor, Batu Pahat) face highest risks when high tide coincides with heavy rain (Jingga/Merah alerts). JPS to deploy mobile pumps; APM to monitor bunds (benteng)."),

  (["telemetry", "stesen telemetri", "data jps"],
   "**Telemetry Stations:**\n"
   "JPS operates over 1,200 telemetry stations nationwide. Data updates every 15-30 mins. If a station goes offline during a storm, Bomba/APM must visually verify river levels at the affected coordinate."),

  (["flash flood", "banjir kilat", "urban flooding"],
   "**Flash Floods (Banjir Kilat):**\n"
   "Occurs within hours of extreme rainfall. SOP: DBKL/Local PBT immediately clear clogged drains. Traffic Police divert traffic. APM deploys boats to trapped vehicles. No PPS opening typically required unless water stagnant > 6 hours."),

  (["monsoon", "tengkujuh", "mtl", "timur laut"],
   "**Northeast Monsoon (MTL):**\n"
   "Nov-Mar. Expected heavy rain in East Coast (Kelantan, Terengganu, Pahang), Johor, and West Sarawak. NADMA pre-positions assets in October. JKM pre-stocks forward bases (Pangkalan Hadapan)."),

  (["smpcb", "pusat kawalan", "jps control center"],
   "**SMPCB (Program Ramalan dan Amaran Banjir):**\n"
   "National Flood Forecasting Centre. Provides 2-day lead time for monsoon floods. Officers should use SMPCB models to preemptively open PPS 24 hours before forecast impact."),

  (["cctv", "kamera", "camera", "live feed"],
   "**JPS / Highway CCTV:**\n"
   "Accessible via Command Dashboard. Used to confirm physical flooding before dispatching APM heavily. If CCTV fails, rely on Citizen 'SOS' aggregation map in FloodSense."),

  // ── CATEGORY 2: COORDINATION & SOS DISPATCH (NADMA / APM / BOMBA) ───────────
  (["dispatch", "hantar", "sos", "rescue", "penyelamat"],
   "**Volunteer Dispatch SOP:**\n"
   "1. Validate SOS on Command Dashboard.\n"
   "2. Dispatch nearest available APM / Verified Volunteer.\n"
   "3. For critical (medical/trapped), escalate to Bomba/MOH.\n"
   "4. Track rescue live via GPS. Update status to 'Resolved' upon PPS arrival."),

  (["mkn 20", "arahan mkn", "sop pengurusan bencana", "arahan 20"],
   "**Arahan MKN No. 20 (Disaster Management Mechanism):**\n"
   "• **Level 1:** Local/District (DO commands PKOB).\n"
   "• **Level 2:** State (State Sec commands PKON).\n"
   "• **Level 3:** National (NADMA DG commands PKSP). Multiple states involved or massive disaster."),

  (["pkob", "pusat kawalan operasi", "district command", "pegawai daerah"],
   "**PKOB (District Disaster Operations Control Centre):**\n"
   "Activated at Level 1 warning. Chaired by District Officer (DO). Coordinates Bomba, Police, APM, JKM, Health at the ground level. All FloodSense SOS cases feed into PKOB."),

  (["bomba", "jbpm", "fire rescue"],
   "**JBPM (Bomba) Role:**\n"
   "Lead agency for search and rescue (SAR). Handles swift-water rescue, structural collapse, hazmat, and extracting bedridden/critical victims. APM supports Bomba."),

  (["apm", "pertahanan awam", "civil defence", "kpa"],
   "**APM (Civil Defence) Role:**\n"
   "First responders for standard evacuations. Manage logistical movement of victims to PPS. Coordinate registered FloodSense civilian volunteers for non-critical rescues."),

  (["pdrm", "polis", "police", "ketua komander", "komander operasi"],
   "**PDRM (Police) Role:**\n"
   "Incident Commander (Komander Operasi Bencana) on the ground. Controls security, roadblocks, prevents looting in evacuated zones, and issues mandatory evacuation orders."),

  (["atm", "tentera", "army", "military", "angkat senjata"],
   "**ATM (Armed Forces) Role:**\n"
   "Deployed for heavy logistics (7-ton trucks), air evacuations (RMAF helicopters), building Bailey bridges, and accessing cut-off areas. Requested via PKOB/NADMA."),

  (["red zone", "zon merah", "cutoff", "terputus"],
   "**Cut-off Areas (Zon Merah):**\n"
   "Areas inaccessible by road/boat. SOP: Inform NADMA air unit / ATM for airdrop of food/meds. Use satellite comms if GSM is down. FloodSense operates in offline mesh mode here."),

  (["helicopter", "helikopter", "air rescue", "udara", "medevac", "rmaf", "tudm"],
   "**Air Evacuations (MEDEVAC):**\n"
   "Approved ONLY for extremely critical medical emergencies or cut-off areas. Requires PKON (State) approval. PDRM/Bomba ground unit must secure the landing zone (LZ)."),

  (["boat", "bot", "aset", "asset distribution", "aluminium", "fiberglass"],
   "**Asset Management (Boats):**\n"
   "Track via JKR/NADMA asset registry. If a district runs out of aluminum/inflatable boats, PKOB escalates to PKON to request inter-district asset sharing. Civilian boats can be commandeered if safe."),

  // ── CATEGORY 3: SHELTERS & RELIEF CENTERS (PPS) / JKM ───────────────────────
  (["pps", "pusat pemindahan", "shelter", "kem", "jkm"],
   "**PPS (Pusat Pemindahan Sementara) Management:**\n"
   "Managed by JKM. Ensure minimum ratio: 1 toilet per 30 persons. Segregate single men, families, and high-risk groups. Maintain live capacity counts in FloodSense."),

  (["food", "makanan", "bekalan", "ration", "caterer", "retort"],
   "**PPS Food SOP (JKM):**\n"
   "Hot meals provided 4x daily via appointed caterers. Must comply with MOH hygiene standards. If cut off, use 'Bungkusan Makanan Asas' (retort pouches). Avoid easily spoiled foods."),

  (["khemah", "tent", "khemah cubane", "privacy", "partition"],
   "**Privacy Tents (Khemah Cubane):**\n"
   "NADMA standard for PPS. Ensure adequate spacing (1m between tents) for fire safety and ventilation. Prioritize breastfeeding mothers and families with infants."),

  (["stadium", "sekolah", "dewan", "pps type", "balairaya"],
   "**PPS Selection Criteria:**\n"
   "Must be gazetted by JKM. Prioritize schools, community halls, stadiums. Must have adequate toilets, running water, electricity (or generator backup), and be located on high ground."),

  (["clinic", "klinik", "kkm", "perubatan", "health", "hospital"],
   "**Medical Posts at PPS (KKM):**\n"
   "Ministry of Health (KKM) sets up static/mobile clinics. Monitor for waterborne diseases, COVID-19/Influenza. Coordinate dialysis patients for hospital transfer immediately upon registration."),

  (["register", "daftar", "ic", "pendaftaran", "bwi registration"],
   "**Victim Registration:**\n"
   "Crucial for BWI claims. Scan MyKad / FloodSense QR via the Kiosk tab. If MyKad lost, JPN (Registration Dept) mobile units to verify via biometrics/database. Never turn away unregistered victims during acute phase."),

  (["volunteer limits", "had sukarelawan", "ngo", "pps entrance", "bsmm"],
   "**NGOs / Volunteers at PPS:**\n"
   "Must register with PKOB/JKM before entering to prevent overcrowding. Unregistered NGOs must drop off supplies at the gate. Avoid ad-hoc food distribution without KKM health clearance."),

  (["elderly", "warga emas", "oku", "disabled", "rentan", "vulnerable", "cacat"],
   "**Vulnerable Groups at PPS:**\n"
   "Ground floor placement near accessible toilets. JKM to provide specific aid (adult diapers, specialized food). PDRM to ensure physical safety and prevent exploitation."),

  (["pets", "haiwan peliharaan", "kucing", "anjing", "dvs", "jabatan haiwan"],
   "**Pet Evacuation (DVS SOP):**\n"
   "Strictly no pets inside human sleeping quarters at PPS. DVS (Dept of Veterinary Services) or NGOs setup separate pet-holding areas outside the main hall or designated pet-friendly PPS."),

  (["close pps", "tutup pps", "pulang", "return", "surut"],
   "**Closing a PPS:**\n"
   "MKN/PDRM declares area safe after water recedes and structures cleared. JKM coordinates Final Ration distribution (Bantuan Bertolak) before victims leave. JKR cleans the PPS facility post-evacuation."),

  // ── CATEGORY 4: DAMAGE ASSESSMENTS & AID (BWI / RECOVERY) ───────────────────
  (["claim", "bwi", "bantuan wang ihsan", "rm1000", "wang ihsan"],
   "**Bantuan Wang Ihsan (BWI):**\n"
   "RM 1,000 cash aid per Household. Eligibility: Must be registered at a PPS or verified by District Officer (DO)/Village Head (Ketua Kampung) if evacuated to relatives' homes."),

  (["kerosakan", "damage", "repair", "bantuan rumah", "jkm claim"],
   "**Damage Repair Aid:**\n"
   "Maximum RM 5,000 per household. Administered by JKM / KPKT/ ICU JPM. Verify FloodSense AI Damage Reports (images, quotes) to expedite processing and reject fraudulent claims."),

  (["ketua kampung", "jkkk", "penghulu", "verification"],
   "**Claim Verification (Ketua Kampung):**\n"
   "If victim did NOT move to PPS (stayed at relative's house), their BWI claim MUST be stamped and verified by their local Penghulu, Ketua Kampung, or MPKK before District Office approval."),

  (["fraud", "tipu", "palsu", "claim duplicate", "bertindih"],
   "**Duplicate/Fraud Claims:**\n"
   "Use MyKad cross-referencing in the BWI Portal/FloodSense Dashboard. Only ONE claim per Head of Household (KIR) allowed per disaster period. Reject split-family duplicate claims."),

  (["death", "kematian", "bantuan hilang nyawa", "lemas"],
   "**Death Benefit (Bantuan Pengurusan Kematian):**\n"
   "RM 10,000 paid to next of kin of flood victims who drown/die directly due to the disaster. Requires Police Report and Hospital Death Certificate confirming cause of death."),

  (["clean up", "cuci bersih", "post flood", "ngo cleaning", "lumpur"],
   "**Post-Flood Cleanup (Pembersihan Pra-Pasca):**\n"
   "SWCorp / PBT heavily manage solid waste. Coordinate NGOs via FloodSense Volunteer tab to assist cleaning schools, mosques, and OKU homes first. Prioritize rapid mud removal before it hardens."),

  (["infra", "infrastructure", "jambatan runtuh", "jalan putus", "jkr"],
   "**Critical Infrastructure Damage (JKR/TNB):**\n"
   "JKR immediately deploys Bailey Bridges for cut-off roads. TNB cuts off power to flooded substations. Do NOT allow victims to return until TNB certifies the area's grid is safe."),

  (["air paip", "water supply", "bekalan air", "span", "tangki"],
   "**Water Supply Disruption (SPAN / State Water Operators):**\n"
   "Deploy static water tanks to PPS and affected neighborhoods. SPAN coordinates mobile water tankers. Issue advisory to boil tap water post-flood due to contamination risks."),

  (["sumbangan", "donation", "akaun bencana", "fund"],
   "**Kumpulan Wang Amanah Bantuan Bencana Negara (KWABBN):**\n"
   "Channel all official monetary donations here. Under NADMA. Used for BWI payments and logistics. Strictly auditable."),

  (["diplomat", "foreign aid", "bantuan luar", "antarabangsa"],
   "**International Aid Offers:**\n"
   "Under MKN 20, NADMA coordinates with Wisma Putra. District/State officers generally DO NOT directly accept international SAR teams without federal MKN clearance."),

  // ── CATEGORY 5: APP ADMINISTRATION & TROUBLESHOOTING ────────────────────────
  (["dashboard", "papan pemuka", "approval", "lulus", "reject", "tolak"],
   "**Command Dashboard (FloodSense):**\n"
   "Use to: 1) Approve/Reject AI damage claims. 2) Dispatch SOS cases. 3) Broadcast Siaran (Announcements) to citizens. Ensure prompt handling of 'CRITICAL' medical flags."),

  (["siaran", "broadcast", "announce", "push notification"],
   "**Broadcasting (Siaran):**\n"
   "Officers can push Geofenced SMS/App notifications. Use ONLY for actionable alerts (e.g., 'Sg Klang breached 5.5m. Evacuate to PPS SMK Meru NOW'). Avoid spamming."),
   
  (["offline", "mesh", "tiada internet", "bluetooth"],
   "**Offline SOS Mode:**\n"
   "FloodSense uses Bluetooth Mesh / Compressed SMS if internet fails. Command dashboard will show 'SMS Backup' tag for these cases. Prioritize them as they likely have no other comms."),

  (["syserror", "ralat", "bug", "crash"],
   "**System Outage SOP:**\n"
   "If FloodSense API fails, fallback to radio communications (GIRN - Government Integrated Radio Network). Use physical whiteboard for PPS capacity tracking until online."),
];

/// Tokenize and clean text
List<String> _tokenize(String text) {
  return text
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]'), '')
      .split(RegExp(r'\s+'))
      .where((w) => w.length > 2)
      .toList();
}

/// Relevance check
bool isGovRelevant(String query) {
  final queryTokens = _tokenize(query);
  final qLower = query.toLowerCase();

  for (final (kws, _) in govFloodQnA) {
    for (final kw in kws) {
      final kwLower = kw.toLowerCase();
      // Exact substring match
      if (qLower.contains(kwLower)) return true;
      
      // Token overlap match for smarter semantics
      final kwTokens = _tokenize(kwLower);
      if (queryTokens.any((qt) => kwTokens.contains(qt))) return true;

      // Partial word match (e.g., 'flood' inside 'post flood')
      if (queryTokens.any((qt) => qt.length > 3 && kwLower.contains(qt))) return true;
    }
  }
  return false;
}

/// Retrieve top matching context using keyword scoring
List<String> retrieveGovSops(String query, {int topK = 3}) {
  final queryTokens = _tokenize(query);
  final qLower = query.toLowerCase();
  
  final scored = <(int, String)>[];
  for (final (kws, text) in govFloodQnA) {
    int score = 0;
    
    for (final kw in kws) {
      final kwLower = kw.toLowerCase();
      
      // 1. Direct phrase match (Highest weight)
      if (qLower.contains(kwLower)) {
        score += 10;
      }
      
      // 2. Token overlap match (Lighter weight)
      final kwTokens = _tokenize(kwLower);
      for (final qt in queryTokens) {
        if (kwTokens.contains(qt)) {
          score += 2;
        } else if (qt.length > 3 && kwLower.contains(qt)) {
          score += 1; // Partial word match
        }
      }
    }
    
    if (score > 0) scored.add((score, text));
  }
  
  scored.sort((a, b) => b.$1.compareTo(a.$1));
  
  if (scored.isEmpty) {
    // General fallback for Government if nothing specific matches
    return [
      "**Arahan MKN No. 20:** Follow chain of command. PKOB -> PKON -> PKSP.",
      "**SOS Dispatch:** Always prioritize critical/medical cases to Bomba.",
      "**PPS Operations:** Ensure JKM registration is strictly followed for BWI claims."
    ];
  }
  return scored.take(topK).map((e) => e.$2).toList();
}
