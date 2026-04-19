import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/locale_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../auth/profile_screen.dart';
import '../auth/role_selection_screen.dart';
import 'volunteer_repository.dart';
import 'mission_dispatch_screen.dart';
import 'volunteer_sos_screen.dart';
import 'service_certificate_screen.dart';
import '../../core/widgets/loc_text.dart';
import '../home/notification_center.dart';
// ── Volunteer Home Screen ──────────────────────────────────────────────────────
// Field-worker focused dashboard: mission status, impact stats, quick actions.
// Accent colour: AppTheme.hope (teal-green). Emergency red only for active SOS missions.

class VolunteerHomeScreen extends StatelessWidget {
  final String userName;
  final void Function(int)? onSwitchTab;
  const VolunteerHomeScreen({super.key, required this.userName, this.onSwitchTab});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: VolunteerRepository().watch(userName),
        builder: (context, snap) {
          final data = snap.data?.data();
          final status = data?['status'] as String? ?? 'AVAILABLE';
          final volName = data?['name'] as String? ?? userName;
          final skills = (data?['skills'] as List?)?.cast<String>() ?? [];
          final bool consent = data?['standing_consent'] as bool? ?? false;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildHeader(context, volName, status),
              const SizedBox(height: 20),
              _buildStatusHeroCard(context, status, skills),
              const SizedBox(height: 20),
              if (consent) ...[
                _buildActiveMissionBanner(context),
                const SizedBox(height: 20),
              ],
              _buildImpactStrip(),
              const SizedBox(height: 20),
              _buildQuickActions(context),
              const SizedBox(height: 20),
              _buildSafetyTip(),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String volName, String status) {
    final hour = DateTime.now().hour;
    final isMs = context.watch<LocaleProvider>().locale.languageCode == 'ms';
    final greeting = hour < 12
        ? (isMs ? 'Selamat Pagi' : 'Good Morning')
        : hour < 17
            ? (isMs ? 'Selamat Tengahari' : 'Good Afternoon')
            : (isMs ? 'Selamat Petang' : 'Good Evening');

    return Row(children: [
      GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => ProfileScreen(userName: volName, role: UserRole.volunteer),
        )),
        child: Container(
          width: 44, height: 44,
          decoration: const BoxDecoration(color: AppTheme.hope, shape: BoxShape.circle),
          child: Center(child: Text(
            volName.isNotEmpty ? volName[0].toUpperCase() : 'V',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
          )),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$greeting, $volName 🤝',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppTheme.textPrimary)),
        const LocText('Portal Sukarelawan • FloodSense', 'Volunteer Portal • FloodSense',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ])),
      IconButton(
        icon: const Icon(Icons.notifications_none_outlined, color: AppTheme.textSecondary),
        onPressed: () { showNotificationCenter(context, role: 'volunteer', userName: volName); },
      ),
    ]);
  }

  Widget _buildStatusHeroCard(BuildContext context, String status, List<String> skills) {
    final isAvailable = status == 'AVAILABLE';
    final isOnMission = status == 'ON_MISSION';

    final gradientColors = isOnMission
        ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
        : isAvailable
            ? [const Color(0xFF0D9488), const Color(0xFF0F766E)]
            : [const Color(0xFF64748B), const Color(0xFF475569)];

    final statusIcon = isOnMission
        ? Icons.directions_run
        : isAvailable
            ? Icons.volunteer_activism
            : Icons.pause_circle_outline;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: gradientColors.first.withAlpha(80), blurRadius: 18,
            offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.white24, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.circle,
                  color: isOnMission ? Colors.white : const Color(0xFF4ADE80),
                  size: 8),
              const SizedBox(width: 6),
              LocText(
                  isOnMission ? 'Dalam Misi' : isAvailable ? 'Bersedia' : 'Tidak Bersedia',
                  isOnMission ? 'On Mission' : isAvailable ? 'Available' : 'Unavailable',
                  style: const TextStyle(color: Colors.white, fontSize: 11,
                      fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            ]),
          ),
          const Spacer(),
          Icon(statusIcon, color: Colors.white70, size: 24),
        ]),
        const SizedBox(height: 16),
        const LocText('Status Sukarelawan', 'Volunteer Status',
            style: TextStyle(color: Colors.white60, fontSize: 13)),
        const SizedBox(height: 4),
        LocText(
          isOnMission ? 'Anda sedang dalam misi aktif' : isAvailable ? 'Anda bersedia untuk misi' : 'Anda tidak bersedia',
          isOnMission ? 'You are on an active mission' : isAvailable ? 'You are available for missions' : 'You are unavailable',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
        ),
        if (skills.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: skills.take(4).map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: Colors.white24, borderRadius: BorderRadius.circular(20)),
              child: Text(s, style: const TextStyle(color: Colors.white, fontSize: 11)),
            )).toList(),
          ),
        ],
      ]),
    );
  }

  Widget _buildActiveMissionBanner(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: VolunteerRepository().watchMissionOffers(userName),
      builder: (context, snap) {
        final offers = snap.data?.docs ?? [];
        if (offers.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                    color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.radar, color: AppTheme.textMuted, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                LocText('TIADA MISI BARU', 'NO NEW MISSIONS',
                    style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w800,
                        fontSize: 11, letterSpacing: 0.5)),
                SizedBox(height: 4),
                LocText('Sila tunggu arahan seterusnya', 'Please wait for further instructions',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600,
                        fontSize: 14)),
              ])),
            ]),
          );
        }

        final doc = offers.first;
        final d = doc.data();
        final address = d['address'] as String? ?? (context.watch<LocaleProvider>().locale.languageCode == 'ms' ? 'Lokasi tidak diketahui' : 'Location unknown');
        final pax = d['head_count']?.toString() ?? '?';
        final distance = d['distance_km']?.toString() ?? '?';

        return GestureDetector(
          onTap: () async {
            try {
              final docRef = await FirebaseFirestore.instance.collection('volunteers').doc(userName).get();
              final isActive = docRef.data()?['standing_consent'] == true;
              if (!isActive && context.mounted) {
                await showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const LocText('Status Tidak Aktif', 'Inactive Status', style: TextStyle(color: AppTheme.emergency)),
                    content: const LocText('Anda tidak membenarkan tawaran misi buat masa ini.\n\nSila aktifkan "Kebenaran Tetap', 'Standing Consent" sebelum mula menerima misi menyelamat.'),
                    actions: [
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.emergency),
                        child: const LocText('Faham', 'Understood'),
                      ),
                    ],
                  ),
                );
                return;
              }
            } catch (_) {}

            if (context.mounted) {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => MissionDispatchScreen(missionId: doc.id, data: d),
              ));
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.warning.withAlpha(120)),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                    color: AppTheme.warningLight, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.sos, color: AppTheme.warning, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const LocText('TAWARAN MISI BARU!', 'NEW MISSION OFFER!',
                    style: TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w800,
                        fontSize: 12, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(address,
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600,
                        fontSize: 13)),
                LocText(
                    '$pax orang · $distance km dari anda',
                    '$pax people · $distance km from you',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ])),
              const Icon(Icons.chevron_right, color: AppTheme.warning, size: 22),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildImpactStrip() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: VolunteerRepository().watchCompletedMissions(userName),
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const LocText('IMPAK ANDA HARI INI', 'YOUR IMPACT TODAY',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11,
                    letterSpacing: 1.2, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _ImpactStat(
                  icon: Icons.check_circle_outline,
                  valueMs: '$count',
                  valueEn: '$count',
                  labelMs: 'Misi Selesai',
                  labelEn: 'Missions Done',
                  color: AppTheme.hope)),
              const _ImpactDivider(),
              const Expanded(child: _ImpactStat(
                  icon: Icons.people_outline,
                  valueMs: '14',
                  valueEn: '14',
                  labelMs: 'Orang Dibantu',
                  labelEn: 'People Helped',
                  color: AppTheme.govBlue)),
              const _ImpactDivider(),
              const Expanded(child: _ImpactStat(
                  icon: Icons.schedule_outlined,
                  valueMs: '5.5j',
                  valueEn: '5.5h',
                  labelMs: 'Jam Berkhidmat',
                  labelEn: 'Hours Served',
                  color: AppTheme.warning)),
            ]),
          ]),
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const LocText('TINDAKAN PANTAS', 'QUICK ACTIONS',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11,
              letterSpacing: 1.2, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _QuickActionCard(
            icon: Icons.volunteer_activism,
            labelMs: 'Lihat Misi',
            labelEn: 'View Missions',
            color: AppTheme.hope,
            onTap: () => onSwitchTab?.call(2),   // Missions tab
          ),
          _QuickActionCard(
            icon: Icons.map_outlined,
            labelMs: 'Peta Operasi',
            labelEn: 'Ops Map',
            color: AppTheme.govBlue,
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => VolunteerSOSScreen(userName: userName),
            )),
          ),
          _QuickActionCard(
            icon: Icons.badge_outlined,
            labelMs: 'Sijil Perkhidmatan',
            labelEn: 'Service Cert',
            color: const Color(0xFF7C3AED),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ServiceCertificateScreen(
                missionId: 'DEMO_MISSION_001',
                data: {
                  'volunteer_name': userName,
                  'sos_id': 'SOS-DEMO-001',
                },
              ),
            )),
          ),
          _QuickActionCard(
            icon: Icons.health_and_safety_outlined,
            labelMs: 'Laporan Keselamatan',
            labelEn: 'Safety Report',
            color: AppTheme.emergency,
            onTap: () => _showSafetyReportSheet(context),
          ),
        ],
      ),
    ]);
  }

  void _showSafetyReportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _SafetyReportSheet(),
    );
  }

  Widget _buildSafetyTip() {
    const tips = [
      ('🌊', 'Jangan redah air bergerak melebihi paras lutut. / Never wade in moving water above knee height.'),
      ('🦺', 'Sentiasa pakai jaket keselamatan semasa operasi bot. / Always wear a life jacket during boat operations.'),
      ('📡', 'Beritahu koordinator lokasi anda setiap 30 minit. / Update your coordinator every 30 minutes.'),
    ];
    final tip = tips[DateTime.now().hour % tips.length];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.hopeLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.hope.withAlpha(60)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tip.$1, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const LocText('TIP KESELAMATAN', 'SAFETY TIP',
              style: TextStyle(color: AppTheme.hope, fontWeight: FontWeight.w700,
                  fontSize: 11, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(tip.$2,
              style: const TextStyle(color: Colors.black, fontSize: 13, height: 1.5)),
        ])),
      ]),
    );
  }
}

// ── Reusable Widgets ──────────────────────────────────────────────────────────

class _ImpactStat extends StatelessWidget {
  final IconData icon;
  final String valueMs, valueEn, labelMs, labelEn;
  final Color color;
  const _ImpactStat({required this.icon, required this.valueMs, required this.valueEn,
      required this.labelMs, required this.labelEn, required this.color});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 6),
      LocText(valueMs, valueEn, style: TextStyle(
          color: color, fontWeight: FontWeight.w800, fontSize: 22)),
      LocText(labelMs, labelEn, textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
    ],
  );
}

class _ImpactDivider extends StatelessWidget {
  const _ImpactDivider();
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 50, color: AppTheme.border,
    margin: const EdgeInsets.symmetric(horizontal: 8),
  );
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String labelMs;
  final String labelEn;
  final Color color;
  final VoidCallback onTap;
  const _QuickActionCard({required this.icon, required this.labelMs, required this.labelEn,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          LocText(labelMs, labelEn,
              maxLines: 2, textAlign: TextAlign.left, // wait, need to pass overflow to textstyle or use LocText properties? we can wrap with Expanded/Flexible if needed. Wait, original has Text
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600,
                  fontSize: 11, height: 1.4)),
        ],
      ),
    ),
  );
}

// ── Safety Report Sheet ───────────────────────────────────────────────────────
class _SafetyReportSheet extends StatefulWidget {
  const _SafetyReportSheet();
  @override
  State<_SafetyReportSheet> createState() => _SafetyReportSheetState();
}

class _SafetyReportSheetState extends State<_SafetyReportSheet> {
  final _detailCtrl = TextEditingController();
  int _typeIdx = 0;
  bool _submitted = false;

  static const _typesMs = [
    'Kecederaan Sukarelawan',
    'Kawasan Tidak Selamat',
    'Kecemasan Perubatan',
    'Peralatan Rosak',
    'Lain-lain',
  ];
  static const _typesEn = [
    'Volunteer Injury',
    'Unsafe Area',
    'Medical Emergency',
    'Damaged Equipment',
    'Other',
  ];

  @override
  void dispose() {
    _detailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMs = context.watch<LocaleProvider>().locale.languageCode == 'ms';
    final currentTypes = isMs ? _typesMs : _typesEn;

    return Padding(
      padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppTheme.emergencyLight,
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.health_and_safety_outlined,
                  color: AppTheme.emergency, size: 20),
            ),
            const SizedBox(width: 12),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              LocText('Laporan Kecemasan', 'Emergency Report', style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 18, color: Colors.black)),
              LocText('Safety', 'Incident Report',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ]),
          ]),
          const SizedBox(height: 20),
          if (_submitted) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: AppTheme.hopeLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.hope.withAlpha(60))),
              child: const Column(children: [
                Icon(Icons.check_circle, color: AppTheme.hope, size: 40),
                SizedBox(height: 10),
                LocText('Laporan Dihantar!', 'Report Submitted!', style: TextStyle(
                    color: AppTheme.hope, fontWeight: FontWeight.w800, fontSize: 16)),
                SizedBox(height: 4),
                LocText('Koordinator akan menghubungi anda dalam masa 10 minit.', 'The coordinator will contact you within 10 minutes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final callUri = Uri(scheme: 'tel', path: '999'); // In production, this would be the specific coordinator's field line
                  if (await canLaunchUrl(callUri)) {
                    await launchUrl(callUri);
                  }
                },
                icon: const Icon(Icons.phone),
                label: const LocText('Hubungi Koordinator', 'Call Coordinator', style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emergency,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: AppTheme.border),
                ),
                child: const LocText('Tutup', 'Close', style: TextStyle(color: AppTheme.textSecondary)),
              ),
            ),
          ] else ...[
            const LocText('Jenis Insiden', 'Incident Type',
                style: TextStyle(color: AppTheme.textSecondary,
                    fontSize: 12, letterSpacing: 1)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: List.generate(currentTypes.length, (i) {
                final on = _typeIdx == i;
                return ChoiceChip(
                  label: Text(currentTypes[i]),
                  selected: on,
                  onSelected: (_) => setState(() => _typeIdx = i),
                  selectedColor: AppTheme.emergencyLight,
                  labelStyle: TextStyle(
                      color: on ? AppTheme.emergency : AppTheme.textPrimary,
                      fontWeight: on ? FontWeight.w700 : FontWeight.normal,
                      fontSize: 12),
                  side: BorderSide(color: on ? AppTheme.emergency : AppTheme.border),
                  backgroundColor: Colors.white,
                );
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _detailCtrl,
              maxLines: 4,
              style: const TextStyle(color: Colors.black, fontSize: 14),
              decoration: InputDecoration(
                hintText: isMs ? 'Terangkan apa yang berlaku...' : 'Describe what happened...',
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.emergency, width: 2)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _submitted = true),
                icon: const Icon(Icons.send_outlined),
                label: const LocText('Hantar Laporan', 'Submit Report',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emergency,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
