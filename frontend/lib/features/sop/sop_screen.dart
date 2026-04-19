import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/locale_provider.dart';

// ── Expanded RAG knowledge base (100 Q&A pairs, 10 topics) ───────────────────

// Each entry: (keyword triggers, topic answer text)
const _sops = [

  // ── Topic 1: Emergency Kit & Packing ─────────────────────────────────────
  (["kit","emergency","beg","bag","pack","bawa apa","preparation","ready","persiapan","what to bring","barang","bring","what"],
   "Emergency Kit / Beg Kecemasan:\n"
   "• IC & birth certificates (digital copy in FloodSense app)\n"
   "• 3-day dry food + 3 litres water per person per day\n"
   "• Powerbank (fully charged), torchlight, extra batteries\n"
   "• 7-day supply of medicines (BP, diabetes, heart)\n"
   "• Rubber boots + quick-dry clothing\n"
   "• Baby: formula, diapers, wet wipes, carrier\n"
   "• Small pillow & blanket if space allows\n"
   "• Land titles, insurance policies in waterproof plastic bag\n"
   "• Cash (ATMs may be offline)\n"
   "Tip: Avoid bringing jewellery — store in bank vault or high secure location."),

  // ── Topic 2: Water Levels & Early Warning ─────────────────────────────────
  (["amaran","warning","waspada","alert","bahaya","danger","paras","level","sungai","river","air pasang","tide","flash flood","banjir kilat","siren","5.0","meter"],
   "River Level Stages / Peringkat Paras Air:\n"
   "• Waspada (Alert) — monitor closely, prepare bag\n"
   "• Amaran (Warning) — be ready to move immediately\n"
   "• Bahaya (Danger) — EVACUATE NOW, no waiting\n\n"
   "Check live levels: FloodSense Alert tab or publicinfobanjir.water.gov.my\n"
   "5.0m+ on Sg Klang = above Danger threshold.\n"
   "Flash floods can strike within MINUTES of heavy rain.\n"
   "Highest risk: high tide (air pasang besar) + heavy rain combined.\n"
   "Rain upstream affects you — floods happen even without local rain."),

  // ── Topic 3: Rescue / SOS ─────────────────────────────────────────────────
  (["rescue","sos","help","tolong","lemas","drowning","trapped","tersangkut","stuck","bumbung","roof","boat","bot","ambulance","ambulans","kritikal","critical","signal","helicopter","swim","berenang"],
   "SOS & Rescue / Penyelamatan:\n"
   "• Use FloodSense SOS button or call 999 / 991 (Civil Defence)\n"
   "• Weak signal: FloodSense sends compressed SMS or Bluetooth Mesh\n"
   "• Stranded on roof: wave bright cloth, signal torch; spell SOS/X with rocks\n"
   "• Signal helicopter: wave both arms or arrange 'SOS'/'X' with rocks\n"
   "• Medical emergency: select 'CRITICAL - MEDICAL' in SOS form\n"
   "• Dispatch takes ~90 seconds; APM volunteers are coordinated\n"
   "• DO NOT swim — hidden debris, strong currents, electric shock risk\n"
   "• DO NOT walk in floodwater — snakes, open manholes, live wires\n"
   "• Rescue boats carry people ONLY, not furniture\n"
   "• Proxy SOS for neighbour: use 'Proxy SOS' in SOS menu"),

  // ── Topic 4: PPS Shelters ──────────────────────────────────────────────────
  (["pps","shelter","pusat pemindahan","khemah","tent","register","daftar","makan","food","lapar","hungry","penuh","full","kapasiti","capacity","stadium","rules","peraturan","ic hilang"],
   "PPS Relief Centres / Pusat Pemindahan:\n"
   "• Find nearest: FloodSense Home screen 'Nearest PPS' card\n"
   "• Register: show MyKad to officer OR use FloodSense Kiosk\n"
   "• IC lost: officers verify through JPN or the app\n"
   "• Food & water provided by NADMA\n"
   "• KKM medical post at most large PPS\n"
   "• 'Khemah Cubane' = portable privacy tent for families\n"
   "• Separate zones for women, children, and elderly\n"
   "• Leaving PPS: inform officer first (for safety records)\n"
   "• Live capacity %: check FloodSense app\n"
   "• Pets: most PPS not allowed — contact APM for pet rescue centres"),

  // ── Topic 5: Elderly & Vulnerable ─────────────────────────────────────────
  (["elderly","warga emas","orang tua","wheelchair","kerusi roda","bayi","baby","susu","formula","lampin","diaper","mengandung","pregnant","sakit","sick","ubat","medicine","dialisis","dialysis","buta","blind","oku","disabled","cacat","bedridden","terlantar","trauma","kaunseling"],
   "Vulnerable Groups / Kumpulan Rentan:\n"
   "• Wheelchair: select 'Wheelchair' in FloodSense profile — boat rescue sent\n"
   "• Bedridden: mark 'Bedridden' — Bomba stretcher evacuation dispatched\n"
   "• Blind/PWD: SOS volunteers trained for PWD assistance\n"
   "• Elderly meds: bring 7-day supply (BP, diabetes, heart medicine)\n"
   "• Adult diapers: limited at PPS — bring 3-day supply\n"
   "• Dialysis patients: alert PPS medical team, they coordinate with hospital\n"
   "• Priority zones near bathrooms for elderly at PPS\n"
   "• Parents refusing to evacuate: show rising water levels, lives > property\n"
   "• Baby extras: formula, diapers, wet wipes, baby carrier\n"
   "• Flood trauma counselling: JKM emotional support available at PPS"),

  // ── Topic 6: Damage Claims & Financial Aid ────────────────────────────────
  (["claim","tuntut","bantuan","aid","wang","duit","money","kerosakan","damage","kereta","car","rumah","house","perabot","furniture","jkm","nadma","bwi","bantuan wang ihsan","insurans","insurance","special perils","laporan","report","police","polis","resit","receipt","gambar","photo"],
   "Damage Claims & Aid / Tuntutan & Bantuan:\n"
   "• File AI Damage Report in FloodSense Claims tab → submit to JKM\n"
   "• Max coverage: RM 5,000/household under JKM Bantuan Wang Ihsan (BWI)\n"
   "• BWI: RM 1,000 government aid for registered flood victims\n"
   "• AI estimates repair costs via Gemini Vision (photo required)\n"
   "• Take photos of watermarks on walls + damaged furniture BEFORE cleaning\n"
   "• Car damage: depends on 'Special Perils' insurance add-on coverage\n"
   "• Receipts washed away: photos + AI assessment accepted as secondary proof\n"
   "• Police report: available at mobile police station at PPS\n"
   "• Aid payment: usually 3–7 days after JKM approval\n"
   "• Electrical items: list in damage report with photos\n"
   "• 'Special Perils' insurance covers floods, storms, landslides"),

  // ── Topic 7: Electricity & Gas Safety ─────────────────────────────────────
  (["electricity","elektrik","suis","switch","plug","palam","fridge","peti ais","gas","dapur","stove","power line","kabel","tnb","generator","renjatan","shock","wet socket","soket","barang elektrik","conductive"],
   "Electricity & Gas Safety / Keselamatan Elektrik & Gas:\n"
   "• Turn off MAIN switch when water enters porch/car porch\n"
   "• Unplug ALL appliances, move them to high ground\n"
   "• Gas: turn off tank regulator, move tank to high place\n"
   "• DO NOT use generator in rain — electrocution + CO poisoning risk\n"
   "• Fallen power line: stay 10m away, report TNB Careline 15454\n"
   "• Touched wet socket/shocked: seek medical help immediately\n"
   "• Flood water + live wire = EXTREMELY dangerous\n"
   "• TNB cuts power in flooded areas for public safety\n"
   "• Power restored ONLY after water recedes + TNB substation inspection\n"
   "• Wet appliances: DO NOT turn on — let dry for days, get professional check"),

  // ── Topic 8: Post-Flood Cleaning ──────────────────────────────────────────
  (["clean","cuci","lumpur","mud","lepas banjir","after flood","mold","kulat","tap water","air paip","smell","bau","food","makanan","buang","throw","peeling","wall","dinding","cat","paint","sampah","waste","volunteer","leptospirosis"],
   "Post-Flood Recovery / Pemulihan Selepas Banjir:\n"
   "• Clean mud while still wet — much harder when dry\n"
   "• Wear gloves, rubber boots, and mask (bacteria & mold protection)\n"
   "• Tap water: BOIL or use bottled water until cleared by authorities\n"
   "• Prevent mold: ventilate + scrub with bleach solution\n"
   "• Throw away ALL food touched by floodwater — it's contaminated\n"
   "• Odour removal: vinegar, baking soda, or commercial disinfectant\n"
   "• Free cleaning volunteers: check FloodSense 'Post-Flood' tab for NGOs\n"
   "• Leptospirosis: dangerous disease from rat urine in floodwater\n"
   "  → Symptoms: fever, headache, muscle pain within 2 weeks — see doctor\n"
   "• Peeling walls: let dry 2–4 weeks fully before repainting\n"
   "• Bulky waste: wait for local council (PBT) special flood collection\n"
   "• DO NOT enter house until cleared by authorities — check structural damage"),

  // ── Topic 9: FloodSense App Features ──────────────────────────────────────
  (["app","aplikasi","offline","90 saat","90 second","family","keluarga","status","mykad","ramalan cuaca","weather","forecast","volunteer mode","sukarelawan","donate","derma","peta","map","red zone","zon merah","beacon","battery","bateri","proxy","neighbor","jiran"],
   "FloodSense App Features / Ciri Aplikasi:\n"
   "• 90-second rescue: AI parses SOS + alerts nearest boat instantly\n"
   "• Offline mode: safety SOPs + maps work without internet\n"
   "• Family Status: ping your location in 'Family Status' tab\n"
   "• MyKad: hashed & stored securely — raw numbers never visible\n"
   "• Weather: uses Open-Meteo + JPS data for high accuracy\n"
   "• Volunteer Mode: toggle in profile + add your skills\n"
   "• Donate: verified NADMA/NGO links in 'Donate' section\n"
   "• Red zones: predicted flood areas based on river levels\n"
   "• Battery 5%: FloodSense enters Beacon Mode (saves energy for SOS)\n"
   "• Proxy SOS: report for neighbour via 'Proxy SOS' in SOS menu"),

  // ── Topic 10: Misc & Agencies ─────────────────────────────────────────────
  (["snake","ular","drowning","lemas","waterborne","disease","penyakit","vehicle","insurans","kereta","jambatan","bridge","jkm","apm","nadma","smart tunnel","air pasang","high tide","coastal","pesisir","klang","batu pahat","bailey"],
   "Key Agencies & Misc / Agensi & Lain-lain:\n"
   "• JKM (Jabatan Kebajikan Masyarakat): manages PPS, food, and BWI payments\n"
   "• APM (Angkatan Pertahanan Awam): primary flood rescuers\n"
   "• NADMA: National Disaster Management Agency — top-level coordination\n"
   "• Bomba (JBPM): fire & rescue, stretcher evacuations\n"
   "• Smart Tunnel (KL): diverts Sg Klang floodwater to Klang River\n"
   "• High tide risk: coastal areas (Klang, Batu Pahat) — extra vigilance\n"
   "• Bailey bridges: APM/ATM build temporary bridges if roads cut off\n"
   "• Snake in flood: call 999/APM — do NOT try to catch yourself\n"
   "• Drowning: call for help, find floating object, do NOT jump in\n"
   "• Waterborne illness: watch for fever, diarrhoea, vomiting — see doctor\n"
   "• Vehicle insurance: ensure 'Special Perils' add-on BEFORE flood season"),

  // ── Topic 11: Evacuation Routes ───────────────────────────────────────────
  (["evacuation","laluan","route","jalan","cara keluar","escape","exit","akleh","sprint","highway","north","rawang","ampang","federal","sungai buloh","jalan masjid india"],
   "Evacuation Routes (Klang Valley) / Laluan Pemindahan:\n"
   "• AKLEH → Ampang Point (avoid if Sg Klang >5.5m)\n"
   "• SPRINT Highway northbound → Rawang\n"
   "• Federal Highway → Sungai Buloh (alternative)\n"
   "• Avoid: Jalan Masjid India & Jalan Tuanku Abdul Halim when Sg Kelantan >8m\n"
   "• Follow police/APM/volunteer direction at all times\n"
   "• 1 foot of water CAN stall or wash away a car — do not drive through"),

  // ── Topic 12: General Disaster / Bencana ─────────────────────────────────
  (["bencana","disaster","natural","kecemasan","mangsa","victim","safe","selamat","help","tolong","apa buat","what to do","step","langkah"],
   "In Any Flood Emergency / Semasa Bencana:\n"
   "1. Stay calm — assess the situation\n"
   "2. Move to higher ground immediately\n"
   "3. Call 999 (Police/Fire), 991 (Civil Defence), or use FloodSense SOS\n"
   "4. Turn off electricity when water enters porch\n"
   "5. Grab emergency kit (IC, meds, powerbank, food, water)\n"
   "6. Go to nearest PPS or follow evacuation route\n"
   "7. Follow official instruction — PDRM / APM / Bomba\n"
   "8. Do NOT spread unverified info — check official channels"),
];

/// Relevance check — full keyword set covering all 10 topics + intent categories
bool _isRelevant(String query) {
  const keywords = [
    // Rescue keywords
    'sos','help','tolong','lemas','drowning','trapped','tersangkut','bumbung',
    'roof','bot','boat','lori','truck','ambulans','ambulance','kritikal',
    'emergency','kecemasan','rescue','selamatkan','terjebak',
    // PPS/shelter keywords
    'pps','pusat pemindahan','shelter','khemah','tent','tidur','sleep',
    'makan','food','lapar','hungry','daftar','register','penuh','full',
    'lokasi','location','capacity','kapasiti',
    // Belongings/IC
    'ic','kad pengenalan','geran','land title','dokumen','document','hilang',
    'lost','selamat','plastik','beg','bag','barang','belongings','emas',
    'gold','duit','cash','jewellery','barang kemas',
    // Claims/Loss
    'claim','tuntut','bantuan','aid','wang','money','kerosakan','damage',
    'kereta','car','rumah','house','perabot','furniture','jkm','nadma','bwi',
    'insurans','insurance','perils','laporan','report','resit','receipt',
    // Vulnerable
    'orang tua','elderly','warga emas','wheelchair','kerusi roda','bayi',
    'baby','susu','formula','lampin','diaper','mengandung','pregnant',
    'sakit','sick','ubat','medicine','dialisis','dialysis','buta','blind',
    'oku','disabled','cacat','bedridden','terlantar',
    // Navigation/routes
    'map','peta','jalan','road','tutup','closed','sesak','jam','arus',
    'current','sungai','river','paras','level','route','laluan','akleh',
    'sprint','highway','rawang','ampang',
    // Water/flood
    'flood','banjir','water','air','rain','hujan','amaran','warning',
    'waspada','alert','bahaya','danger','flash flood','banjir kilat',
    'siren','paras air','air pasang','high tide','kilat',
    // Electricity/gas
    'electricity','elektrik','suis','switch','plug','palam','gas','dapur',
    'stove','tnb','generator','renjatan','shock','wayar','wire',
    // Post-flood
    'clean','cuci','lumpur','mud','lepas banjir','after flood','mold',
    'kulat','leptospirosis','smell','bau','sampah','waste','dinding','wall',
    // Agencies
    'apm','bomba','nadma','jkm','polis','police','smart tunnel',
    // App features
    'app','aplikasi','offline','90','beacon','proxy','volunteer','derma',
    'donate','zon merah','red zone',
    // General
    'bencana','disaster','mangsa','victim','safe','selamat','preparation',
    'sedia','persiapan','kit','emergency','how to','apa buat','macam mana',
    'cara','nak buat','step','langkah','apa','mana','bila','what',
    'bring','bawa','pack','prepare','pack',
  ];
  final q = query.toLowerCase();
  return keywords.any((kw) => q.contains(kw));
}

List<String> _retrieveSops(String query, {int topK = 3}) {
  final q = query.toLowerCase();
  final scored = <(int, String)>[];
  for (final (kws, text) in _sops) {
    final score = kws.where((kw) => q.contains(kw)).length;
    if (score > 0) scored.add((score, text));
  }
  scored.sort((a, b) => b.$1.compareTo(a.$1));
  // Always fall back to general safety + shelter info if nothing matches
  if (scored.isEmpty) return [_sops[0].$2, _sops[1].$2, _sops[2].$2];
  return scored.take(topK).map((e) => e.$2).toList();
}

// ── Widget ────────────────────────────────────────────────────────────────────

class SOPScreen extends StatefulWidget {
  final String userName;
  const SOPScreen({super.key, this.userName = 'Pengguna Awam'});
  @override
  State<SOPScreen> createState() => _SOPScreenState();
}

class _SOPScreenState extends State<SOPScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  final _messages = <({bool isUser, String text, bool isOffTopic})>[];
  bool _loading = false;
  bool _greeted = false;

  static const _geminiKey = String.fromEnvironment('GEMINI_API_KEY');

  static const _persona = '''
You are FloodSense Assistant — a helpful Malaysian flood & disaster safety AI.

IMPORTANT RULES:
1. Answer ALL questions related to: floods, banjir, evacuation, routes, shelters (PPS), SOS/rescue, damage claims, flood safety, leptospirosis, disaster preparedness, government aid (JKM/NADMA), river alerts, emergency kits, post-flood recovery.
2. "Route", "evacuation route", "laluan", "jalan keluar" are ALL valid flood-related questions — ALWAYS answer them.
3. If the question is clearly unrelated to ANY disaster, emergency, safety, or aid topic (e.g. cooking recipes, sports scores), reply EXACTLY: "IRRELEVANT"
4. Keep answers clear and helpful. Use bullet points for steps. Use Malaysian context.
5. Answer in the SAME LANGUAGE as the question (BM or English or mixed).
6. For claims: mention RM 5,000 maximum under JKM Bantuan Wang Ehsan.
7. Be empathetic — users may be in distress.
''';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('chat_sessions').doc(widget.userName).get();
      if (doc.exists) {
        final data = doc.data()?['messages'] as List<dynamic>?;
        if (data != null && data.isNotEmpty) {
          if (mounted) {
            setState(() {
              _messages.clear();
              for (final line in data) {
                try {
                  final map = line as Map<String, dynamic>;
                  _messages.add((
                    isUser: map['u'] as bool? ?? false,
                    text: map['t'] as String? ?? '',
                    isOffTopic: map['o'] as bool? ?? false,
                  ));
                } catch (_) {}
              }
              _greeted = true;
            });
          }
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    }

    if (!_greeted && mounted) {
      final isMs = context.read<LocaleProvider>().locale.languageCode == 'ms';
      setState(() {
        _greeted = true;
        _messages.add((
          isUser: false,
          text: isMs 
            ? 'Saya Pembantu FloodSense anda 🌊\n\nSaya boleh membantu dengan:\n• Laluan & pusat pemindahan (PPS)\n• Prosedur keselamatan semasa banjir\n• Tuntutan kerosakan (sehingga RM 5,000)\n• Bantuan kerajaan & pertolongan cemas\n\nTaip soalan anda. Saya faham BM & English.'
            : 'I am your FloodSense Assistant 🌊\n\nI can help you with:\n• Evacuation routes & shelters (PPS)\n• Flood safety procedures\n• Damage claims (up to RM 5,000)\n• Government aid & first aid\n\nType your question. I understand BM & English.',
          isOffTopic: false,
        ));
        _saveHistory();
      });
    }
    _scrollToBottom();
  }

  Future<void> _saveHistory() async {
    try {
      final list = _messages.map((m) => {
        'u': m.isUser,
        't': m.text,
        'o': m.isOffTopic,
      }).toList();
      await FirebaseFirestore.instance.collection('chat_sessions').doc(widget.userName).set({
        'messages': list,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _send() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    _ctrl.clear();
    setState(() {
      _messages.add((isUser: true, text: q, isOffTopic: false));
      _loading = true;
    });
    _saveHistory();

    // Light relevance pre-check — pass through if keywords match
    final relevant = _isRelevant(q);
    final ctx = _retrieveSops(q).join('\n\n');
    String answer;

    final isMs = context.read<LocaleProvider>().locale.languageCode == 'ms';
    try {
      final errIrrelevant = isMs
          ? 'Saya hanya membantu soalan berkaitan banjir, bencana, keselamatan, dan tuntutan. Sila tanya soalan berkaitan darurat atau pemindahan. 🌊'
          : 'I only assist with questions related to floods, disasters, safety, and claims. Please ask questions related to emergencies or evacuations. 🌊';


      if (_geminiKey.isNotEmpty) {
        final model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: _geminiKey);
        // Include context only if we have keyword matches; otherwise trust Gemini to decide
        final prompt = '$_persona\n\n'
            '${relevant ? "Relevant SOPs:\n$ctx\n\n" : ""}'
            'User: $q\nAssistant:';
        final raw = (await model.generateContent([Content.text(prompt)])).text ?? ctx;
        if (raw.trim().toUpperCase() == 'IRRELEVANT') {
          answer = errIrrelevant;
        } else {
          answer = raw.trim();
        }
      } else {
        // No API key — use RAG context directly
        answer = relevant ? ctx : errIrrelevant;
      }
    } catch (_) {
      final errService = isMs 
          ? 'Perkhidmatan tidak tersedia buat masa ini. Untuk kecemasan, hubungi 999 atau 991.' 
          : 'Service is currently unavailable. For emergencies, dial 999 or 991.';
      answer = relevant ? ctx : errService;
    }

    final isOffTopic = answer.startsWith('Saya hanya membantu') || answer.startsWith('I only assist');
    if (mounted) {
      setState(() {
        _messages.add((isUser: false, text: answer, isOffTopic: isOffTopic));
        _loading = false;
      });
      _saveHistory();
    }
    _scrollToBottom();
  }

  void _scrollToBottom() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (_scroll.hasClients) {
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMs = context.watch<LocaleProvider>().locale.languageCode == 'ms';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: AppTheme.govBlueLight, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.smart_toy_outlined, color: AppTheme.govBlue, size: 18),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isMs ? 'Pembantu FloodSense' : 'FloodSense Helper',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 15)),
              Text(isMs ? 'Pakar Banjir & Keselamatan' : 'Flood & Safety Specialist',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF4B5563), fontSize: 11)),
            ]),
          ),
        ]),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppTheme.govBlueLight, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.circle, color: AppTheme.hope, size: 8),
              const SizedBox(width: 4),
              Text(isMs ? 'Dalam Talian' : 'Online', style: const TextStyle(color: AppTheme.govBlue, fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: _messages.length + (_loading ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == _messages.length) return const _TypingIndicator();
              final m = _messages[i];
              return m.isUser
                  ? _UserBubble(text: m.text)
                  : _AIBubble(text: m.text, isOffTopic: m.isOffTopic);
            },
          ),
        ),

        // Quick chips — show only when just the greeting is visible
        if (_messages.length <= 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 8, runSpacing: 6,
              children: (isMs ? [
                 'Laluan pemindahan?', 'PPS terdekat?', 
                 'Cara tuntut RM 5,000?', 'Air masuk rumah — apa buat?', 
                 'Selepas banjir — apa buat?', 'Kit kecemasan?', 'SOS tiada internet?'
              ] : [
                 'Evacuation route?', 'Nearest PPS shelter?', 
                 'How to claim RM 5,000?', 'Water entering house — what to do?', 
                 'After flood — what to do?', 'Emergency kit?', 'No internet SOS?'
              ]).map((s) => GestureDetector(
                onTap: () { _ctrl.text = s; _send(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                      color: AppTheme.govBlueLight,
                      border: Border.all(color: AppTheme.govBlue.withAlpha(60)),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.govBlue, fontSize: 12, fontWeight: FontWeight.w500)),
                ),
              )).toList(),
            ),
          ),

        _buildInput(isMs),
      ]),
    );
  }

  Widget _buildInput(bool isMs) => Container(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
    decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.border))),
    child: Row(children: [
      Expanded(child: TextField(
        controller: _ctrl,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          hintText: isMs ? 'Tanya soalan banjir, laluan, tuntutan…' : 'Ask about floods, routes, claims…',
          hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
          filled: true, fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24),
              borderSide: const BorderSide(color: AppTheme.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24),
              borderSide: const BorderSide(color: AppTheme.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24),
              borderSide: const BorderSide(color: AppTheme.govBlue, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onSubmitted: (_) => _send(),
      )),
      const SizedBox(width: 8),
      IconButton(
        onPressed: _loading ? null : _send,
        icon: const Icon(Icons.send_rounded, color: Colors.white),
        style: IconButton.styleFrom(
            backgroundColor: AppTheme.govBlue,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(12)),
      ),
    ]),
  );
}

// ── Bubbles ───────────────────────────────────────────────────────────────────

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18), topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18), bottomRight: Radius.circular(4),
        ),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Text(text, style: const TextStyle(color: Colors.black, fontSize: 14, height: 1.5)),
    ),
  );
}

class _AIBubble extends StatelessWidget {
  final String text;
  final bool isOffTopic;
  const _AIBubble({required this.text, this.isOffTopic = false});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
      decoration: BoxDecoration(
        color: isOffTopic ? const Color(0xFFFFF8F0) : const Color(0xFFDBEAFE),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4), topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18), bottomRight: Radius.circular(18),
        ),
        border: isOffTopic ? Border.all(color: const Color(0xFFFBBF24).withAlpha(80)) : null,
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (isOffTopic) ...[
          const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 16),
          const SizedBox(width: 6),
        ],
        Expanded(child: Text(text,
            style: TextStyle(
              color: isOffTopic ? const Color(0xFF92400E) : const Color(0xFF1E3A8A),
              fontSize: 14, height: 1.5,
            ))),
      ]),
    ),
  );
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(14)),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E3A8A))),
        SizedBox(width: 10),
        Text('Sedang mencari…', style: TextStyle(color: Color(0xFF1E3A8A), fontSize: 13)),
      ]),
    ),
  );
}
