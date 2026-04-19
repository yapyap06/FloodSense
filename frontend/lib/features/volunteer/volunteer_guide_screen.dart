import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../core/widgets/loc_text.dart';

/// Volunteer-specific guide / help centre.
/// Covers field procedures, safety protocols, coordination channels and FAQs.
class VolunteerGuideScreen extends StatefulWidget {
  const VolunteerGuideScreen({super.key});

  @override
  State<VolunteerGuideScreen> createState() => _VolunteerGuideScreenState();
}

class _VolunteerGuideScreenState extends State<VolunteerGuideScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  int _expandedIndex = -1;

  // ── All guide sections ────────────────────────────────────────────────────

  static final _sections = [
    const _GuideSection(
      icon: Icons.directions_run,
      color: AppTheme.hope,
      titleMs: 'Prosedur Gerak Balas', titleEn: 'Response Procedure',
      items: [
        _GuideItem(
          qMs: 'Apa yang perlu saya lakukan apabila menerima tawaran misi?',
          qEn: 'What should I do upon receiving a mission offer?',
          aMs: '1. Buka tab SOS / Dispatch dan semak lokasi mangsa pada peta.\n2. Tekan "Terima & Pergi" untuk mengunci misi.\n3. Hubungi koordinator anda di talian 03-XXXX XXXX sebelum bergerak.\n4. Rekod masa bertolak dan ETA anda.\n5. Hubungi 999 jika kawasan tidak selamat.',
          aEn: '1. Open the SOS / Dispatch tab and check the victim location on the map.\n2. Press "Accept & Go" to lock the mission.\n3. Call your coordinator at 03-XXXX XXXX before moving.\n4. Record your departure time and ETA.\n5. Call 999 if the area is unsafe.',
        ),
        _GuideItem(
          qMs: 'Bagaimana jika saya tidak dapat tiba di lokasi mangsa?',
          qEn: 'What if I cannot reach the victim location?',
          aMs: 'Lapor kepada koordinator segera melalui aplikasi atau hubungi 03-XXXX XXXX. JANGAN cuba redah air deras setinggi lutut. Dokumentasikan koordinat GPS dan hantar kepada pasukan sokongan.',
          aEn: 'Report to your coordinator immediately via the app or call 03-XXXX XXXX. Do NOT attempt to cross floodwater deeper than knee height. Document the GPS coordinates and pass them to the next available team.',
        ),
        _GuideItem(
          qMs: 'Bagaimana cara saya menanda misi selesai?',
          qEn: 'How do I mark a mission as completed?',
          aMs: 'Pada skrin "Misi Aktif", tatal ke bawah dan tekan butang hijau "MISI SELESAI". Sediakan bukti (gambar/video ringkas) sebelum menanda selesai. Senarai misi anda akan dikemas kini secara automatik.',
          aEn: 'On the "Active Mission" screen, scroll down and press the green "MISSION COMPLETED" button. Provide proof (brief photo/video) before marking it complete. Your mission list will update automatically.',
        ),
      ],
    ),
    const _GuideSection(
      icon: Icons.health_and_safety_outlined,
      color: AppTheme.warning,
      titleMs: 'Keselamatan Lapangan', titleEn: 'Field Safety',
      items: [
        _GuideItem(
          qMs: 'Peralatan wajib sebelum ke lapangan',
          qEn: 'Mandatory field equipment',
          aMs: '• Jaket keselamatan (MANDATORI)\n• Kasut getah / bot bertutup\n• Lampu suluh kalis air\n• Pelindung kepala (keledar)\n• Kit pertolongan cemas\n• Radio walkie-talkie\n• Air dan makanan tenaga untuk 4 jam',
          aEn: '• Life jacket (MANDATORY)\n• Covered rubber boots / shoes\n• Waterproof flashlight\n• Head protection (helmet)\n• Personal first aid kit\n• Radio / walkie-talkie\n• Water and energy food for 4 hours',
        ),
        _GuideItem(
          qMs: 'Had keselamatan air',
          qEn: 'Water safety limits',
          aMs: '🚫 JANGAN redah air bergerak melebihi paras lutut.\n🚫 JANGAN masuk kawasan tanpa ketua kumpulan.\n✅ Sentiasa bergerak dalam kumpulan minimum 2 orang.\n✅ Hubungi koordinator setiap 30 minit.\n✅ Gunakan tali keselamatan di air deras.',
          aEn: '🚫 DO NOT cross moving water above knee height.\n🚫 DO NOT enter areas without a team leader.\n✅ Always move in groups of minimum 2 people.\n✅ Contact coordinator every 30 mins.\n✅ Use safety ropes in rapid waters.',
        ),
        _GuideItem(
          qMs: 'Tindakan jika ahli pasukan tercedera?',
          qEn: 'What to do if a team member is injured?',
          aMs: '1. Hubungi 999 segera.\n2. Lakukan pertolongan cemas jika terlatih.\n3. JANGAN menggerakkan mangsa jika disyaki kecederaan tulang belakang.\n4. Kemas kini status GPS di dalam aplikasi.\n5. Rekod insiden bagi tujuan Laporan Keselamatan.',
          aEn: '1. Call 999 immediately for medical emergencies.\n2. Apply basic first aid if trained.\n3. Do NOT move the victim if spinal injury is suspected.\n4. Update coordinator via app and mark your GPS location.\n5. Document the incident for the Safety Report.',
        ),
      ],
    ),
    const _GuideSection(
      icon: Icons.groups_outlined,
      color: AppTheme.govBlue,
      titleMs: 'Koordinasi Pasukan', titleEn: 'Team Coordination',
      items: [
        _GuideItem(
          qMs: 'Saluran komunikasi rasmi',
          qEn: 'Official communication channels',
          aMs: 'Radio: Kanal 1 (umum) / Kanal 3 (kecemasan)\nWhatsApp Kumpulan: Hubungi penyelaras anda untuk dijemput\nTalian Koordinator: 03-XXXX XXXX (24/7)\nApp FloodSense: Tab Misi untuk kemas kini masa nyata',
          aEn: 'Radio: Channel 1 (general) / Channel 3 (emergency)\nWhatsApp Group: Ask your coordinator to invite you\nCoordinator Hotline: 03-XXXX XXXX (24/7)\nFloodSense App: Mission tab for real-time updates',
        ),
        _GuideItem(
          qMs: 'Apa peranan ketua kumpulan (Team Leader)?',
          qEn: 'What is the role of the Team Leader?',
          aMs: 'Ketua kumpulan bertanggungjawab untuk:\n• Mengarahkan laluan dan keputusan di lapangan\n• Melaporkan status setiap 30 minit\n• Mengesahkan keselamatan ahli sebelum berundur\n• Mengisi Laporan Insiden selepas setiap misi',
          aEn: 'The team leader is responsible for:\n• Directing routes and field decisions\n• Reporting status to coordinator every 30 mins\n• Confirming safety of all members before withdrawing\n• Filling out the Incident Report post-mission',
        ),
        _GuideItem(
          qMs: 'Bagaimana membuat laporan terus pada JPBD?',
          qEn: 'How do I escalate to government authorities?',
          aMs: '1. Guna butang "Laporan Kecemasan" di Laman Utama.\n2. Masukkan jenis insiden, lokasi, dan bilangan mangsa.\n3. Laporan akan dihantar terus ke Jawatankuasa Pengurusan Bencana Daerah (JPBD).\n4. Masa maklum balas < 30 minit bagi kes KRITIKAL.',
          aEn: '1. Use the "Emergency Report" button on the Home screen.\n2. Fill in the incident type, location, and number of victims.\n3. The report is sent directly to the District Disaster Management Committee (JPBD).\n4. Expected response time: < 30 minutes for CRITICAL incidents.',
        ),
      ],
    ),
    const _GuideSection(
      icon: Icons.badge_outlined,
      color: Color(0xFF7C3AED),
      titleMs: 'Pentadbiran', titleEn: 'Administration',
      items: [
        _GuideItem(
          qMs: 'Bagaimana mendapatkan Sijil Perkhidmatan?',
          qEn: 'How to obtain the Service Certificate?',
          aMs: 'Sijil Perkhidmatan Sukarelawan dijana secara automatik selepas 3 misi selesai. Tekan "Sijil Perkhidmatan" di Laman Utama untuk memuat turun PDF. Nama pada sijil berdasarkan profil yang anda daftarkan.',
          aEn: 'Volunteer Service Certificates are auto-generated after 3 completed missions. Press "Service Certificate" on Home to download the PDF. The name is based on your registered profile.',
        ),
        _GuideItem(
          qMs: 'Adakah saya mendapat elaun semasa bertugas?',
          qEn: 'Do I get an allowance during duty?',
          aMs: 'Sukarelawan RELA dan Swasta menerima:\n• Elaun harian: RM 30/hari (untuk misi > 8 jam)\n• Insurans kemalangan: RM 50,000\n• Makan dan minum disediakan di PPS.',
          aEn: 'Private & RELA volunteers receive:\n• Daily allowance: RM 30/day (for duty > 8 hours)\n• Accident insurance limit: RM 50,000\n• Food and drinks are provided at the evacuation center.',
        ),
        _GuideItem(
          qMs: 'Bagaimana menukar kenderaan/kemahiran di profil?',
          qEn: 'How do I update my skills / vehicle after registering?',
          aMs: 'Pergi ke tab Misi → tekan butang "Edit Profil" (butang hijau). Kemas kini kemahiran dan kenderaan anda, kemudian tekan SIMPAN.',
          aEn: 'Go to the Missions tab → tap the "Edit Profile" button (green FAB). Update your skills and vehicle, then tap SAVE. Changes reflect instantly.',
        ),
      ],
    ),
    const _GuideSection(
      icon: Icons.sos_outlined,
      color: AppTheme.emergency,
      titleMs: 'Kecemasan Talian', titleEn: 'Emergency Hotlines',
      items: [
        _GuideItem(
          qMs: 'Nombor talian penting polis / bomba',
          qEn: 'Key emergency numbers',
          aMs: '🚒 Bomba & Penyelamat: 994\n🚑 Ambulans: 999\n👮 Polis: 999\n🌊 JPS (Jabatan Pengairan): 1-800-88-2737\n🏥 Hospital Klang: 03-3375 6699\n🏛️ Bilik Gerakan Daerah Klang: 03-3371 XXXX\n📱 Koordinator: 03-XXXX XXXX\n📩 SMS (Tanpa Internet): 15888',
          aEn: '🚒 Fire & Rescue: 994\n🚑 Ambulance: 999\n👮 Police: 999\n🌊 JPS (Irrigation Dept): 1-800-88-2737\n🏥 Klang Hospital: 03-3375 6699\n🏛️ Klang District Command Center: 03-3371 XXXX\n📱 Coordinator Hotline: 03-XXXX XXXX\n📩 SMS (No Internet): 15888',
        ),
      ],
    ),
  ];


  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_GuideSection> _filtered(bool isMs) {
    if (_query.isEmpty) return _sections;
    final q = _query.toLowerCase();
    
    final result = <_GuideSection>[];
    for (final s in _sections) {
      final title = isMs ? s.titleMs : s.titleEn;
      final titleMatch = title.toLowerCase().contains(q);
      final matchedItems = s.items.where((i) {
          final itemQ = isMs ? i.qMs : i.qEn;
          final itemA = isMs ? i.aMs : i.aEn;
          return itemQ.toLowerCase().contains(q) || itemA.toLowerCase().contains(q);
      }).toList();
      
      if (titleMatch || matchedItems.isNotEmpty) {
        result.add(
          _GuideSection(
            icon: s.icon,
            color: s.color,
            titleMs: s.titleMs, titleEn: s.titleEn,
            items: titleMatch ? s.items : matchedItems,
          ),
        );
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isMs = context.watch<LocaleProvider>().locale.languageCode == 'ms';
    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LocText('Panduan Sukarelawan', 'Volunteer Guide',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 16)),
          LocText('Prosedur operasi dan keselamatan lapangan', 'Field operations and safety procedures',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ]),
      ),
      body: Column(children: [
        // ── Search bar ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.black, fontSize: 14),
            onChanged: (v) => setState(() {
              _query = v;
              _expandedIndex = -1;
            }),
            decoration: InputDecoration(
              hintText: isMs ? 'Cari soalan...' : 'Search questions...',
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
              prefixIcon: const Icon(Icons.search, color: AppTheme.govBlue),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() {
                        _searchCtrl.clear();
                        _query = '';
                      }),
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.govBlue, width: 2)),
            ),
          ),
        ),

        // ── Sections ─────────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: _filtered(isMs).length,
            itemBuilder: (_, si) {
              final section = _filtered(isMs)[si];
              return _buildSection(section, si, isMs);
            },
          ),
        ),
      ]),
    );
  }

  Widget _buildSection(_GuideSection section, int si, bool isMs) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Section header
      Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: section.color.withAlpha(20),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(section.icon, color: section.color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(isMs ? section.titleMs : section.titleEn,
              style: TextStyle(color: section.color, fontWeight: FontWeight.w700,
                  fontSize: 12, letterSpacing: 0.5))),
        ]),
      ),
      // Items
      ...section.items.asMap().entries.map((e) {
        final globalIdx = si * 100 + e.key;
        final isOpen = _expandedIndex == globalIdx;
        final item = e.value;
        return _buildItem(item, globalIdx, isOpen, section.color, isMs);
      }),
    ]);
  }

  Widget _buildItem(_GuideItem item, int idx, bool isOpen, Color color, bool isMs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isOpen ? color.withAlpha(80) : AppTheme.border,
            width: isOpen ? 1.5 : 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(children: [
          InkWell(
            onTap: () => setState(
                () => _expandedIndex = isOpen ? -1 : idx),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Text(isMs ? item.qMs : item.qEn,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: isOpen ? color : Colors.black)),
                ),
                const SizedBox(width: 8),
                Icon(isOpen ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.textSecondary, size: 20),
              ]),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: isOpen
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    color: color.withAlpha(8),
                    child: Text(isMs ? item.aMs : item.aEn,
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 13, height: 1.6)),
                  )
                : const SizedBox.shrink(),
          ),
        ]),
      ),
    );
  }
}

class _GuideSection {
  final IconData icon;
  final Color color;
  final String titleMs, titleEn;
  final List<_GuideItem> items;
  const _GuideSection({required this.icon, required this.color,
      required this.titleMs, required this.titleEn, required this.items});
}

class _GuideItem {
  final String qMs, aMs, qEn, aEn;
  const _GuideItem({required this.qMs, required this.aMs, required this.qEn, required this.aEn});
}
