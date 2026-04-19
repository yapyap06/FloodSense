import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import 'volunteer_repository.dart';
import 'mission_dispatch_screen.dart';
import 'service_certificate_screen.dart';
import '../../core/widgets/loc_text.dart';
import 'package:provider/provider.dart';
import '../../core/providers/locale_provider.dart';

/// Main volunteer hub — light theme, high-contrast
class VolunteerScreen extends StatefulWidget {
  final String userName;
  const VolunteerScreen({super.key, this.userName = 'Sukarelawan Pengguna'});
  @override
  State<VolunteerScreen> createState() => _VolunteerScreenState();
}

class _VolunteerScreenState extends State<VolunteerScreen> {
  final _repo = VolunteerRepository();
  bool _standingConsent = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildStatusCard(),
          const SizedBox(height: 20),
          _buildMissionsHeader(context),
          const SizedBox(height: 12),
          _buildCompletedMissionsSection(context),
          const SizedBox(height: 20),
          _buildConsentSection(),
          const SizedBox(height: 32),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRegistrationSheet(context),
        icon: const Icon(Icons.person_add_outlined),
        label: const LocText('Edit Profil', 'Edit Profile'),
        backgroundColor: AppTheme.hope,
        foregroundColor: Colors.white,
      ),
    );
  }

  // ── Status card ───────────────────────────────────────────────────────────
  Widget _buildStatusCard() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _repo.watch(widget.userName),
      builder: (ctx, snap) {
        final profile = snap.data?.data();
        final name = profile?['name'] as String? ?? 'Sukarelawan Demo';
        final skills = (profile?['skills'] as List?)?.cast<String>() ?? [];
        final vehicle = profile?['vehicleType'] as String? ?? 'none';

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [AppTheme.hope, Color(0xFF1DB97A)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: AppTheme.hope.withAlpha(60), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white.withAlpha(30),
                child: const Icon(Icons.person, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                  const LocText('Sukarelawan Aktif', 'Active Volunteer',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(context.watch<LocaleProvider>().locale.languageCode == 'ms' ? '● AKTIF' : '● ACTIVE', style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
              ),
            ]),
            if (skills.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: skills.take(4).map((s) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(s, style: const TextStyle(color: Colors.white, fontSize: 10)),
                )).toList(),
              ),
            ],
            if (vehicle != 'none') ...[
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.directions_car_outlined, color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Text(_vehicleLabel(vehicle, context.watch<LocaleProvider>().locale.languageCode == 'ms'),
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ],
          ]),
        );
      },
    );
  }

  String _vehicleLabel(String v, bool isMs) => switch(v) {
    'boat' => isMs ? '🚤 Bot' : '🚤 Boat',
    'car_4wd' => isMs ? '🚙 Kenderaan 4x4' : '🚙 4x4 Vehicle',
    'lorry' => isMs ? '🚛 Lori' : '🚛 Lorry',
    _ => isMs ? 'Tiada kenderaan' : 'No vehicle',
  };

  // ── Missions header ───────────────────────────────────────────────────────
  Widget _buildMissionsHeader(BuildContext context) {
    if (!_standingConsent) return const SizedBox.shrink();

    return Row(children: [
      const Expanded(
        child: LocText('MISI AKTIF', 'ACTIVE MISSIONS',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600)),
      ),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _repo.watchMissionOffers(widget.userName),
        builder: (_, snap) {
          final count = snap.data?.docs.length ?? 0;
          if (count == 0) return const SizedBox.shrink();
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: AppTheme.emergencyLight,
                borderRadius: BorderRadius.circular(12)),
            child: Text(context.watch<LocaleProvider>().locale.languageCode == 'ms' ? '$count BARU' : '$count NEW',
                style: const TextStyle(
                    color: AppTheme.emergency, fontWeight: FontWeight.w800, fontSize: 10)),
          );
        },
      ),
    ]);
  }

  // ── Completed missions section (with demo cards) ──────────────────────────
  Widget _buildCompletedMissionsSection(BuildContext context) {
    final isMs = Provider.of<LocaleProvider>(context).locale.languageCode == 'ms';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Active mission offers ─────────────────────────────────────────
      if (!_standingConsent)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2), // Very light red
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.emergency.withAlpha(80)),
          ),
          child: const Column(children: [
            Icon(Icons.gpp_bad_outlined, color: AppTheme.emergency, size: 48),
            SizedBox(height: 12),
            LocText('Akses Misi Disekat', 'Mission Access Blocked',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.emergency, fontWeight: FontWeight.w800, fontSize: 14)),
            SizedBox(height: 6),
            LocText(
               'Anda kini berstatus Tidak Aktif.\nSila aktifkan pertukaran (Kebenaran Tetap) di bawah untuk mengakses tawaran misi baru.',
               'Your status is currently Inactive.\nPlease enable Standing Consent below to access new mission offers.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.emergency, fontSize: 12, height: 1.4)),
          ]),
        )
      else
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _repo.watchMissionOffers(widget.userName),
        builder: (ctx, snap) {
          final offers = snap.data?.docs ?? [];
          if (offers.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border)),
              child: const Center(
                child: Column(children: [
                  Icon(Icons.notifications_none, color: AppTheme.border, size: 48),
                  SizedBox(height: 8),
                  LocText(
                      'Tiada tawaran misi ketika ini',
                      'No mission offers right now',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                ]),
              ),
            );
          }
          return Column(
            children: offers.map((doc) {
              final d = doc.data();
              return _MissionOfferCard(
                missionId: doc.id,
                data: d,
                onAccept: () {
                  if (!_standingConsent) {
                    showDialog<void>(
                      context: ctx,
                      builder: (dialogCtx) => AlertDialog(
                        title: const LocText('Status Tidak Aktif', 'Inactive Status', style: TextStyle(color: AppTheme.emergency)),
                        content: const LocText(
                            'Anda tidak membenarkan tawaran misi buat masa ini.\n\nSila aktifkan Kebenaran Tetap sebelum menerima misi.',
                            'You do not allow mission offers currently.\n\nPlease enable Standing Consent before accepting missions.'),
                        actions: [
                          FilledButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            style: FilledButton.styleFrom(backgroundColor: AppTheme.emergency),
                            child: const LocText('Faham', 'Understood'),
                          ),
                        ],
                      ),
                    );
                    return;
                  }
                  Navigator.push(ctx, MaterialPageRoute(
                      builder: (_) => MissionDispatchScreen(missionId: doc.id, data: d)));
                },
                onDecline: () => _repo.respondToMission(doc.id, 'DECLINED', d['sos_id'] ?? ''),
              );
            }).toList(),
          );
        },
      ),

      const SizedBox(height: 20),
      const LocText('MISI SEMASA & SELESAI', 'MISSIONS',
          style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),

      // ── Firestore Active Missions ──────────────────────────────────
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _repo.watchActiveMissions(widget.userName),
        builder: (ctx, snap) {
          final missions = snap.data?.docs ?? [];
          if (missions.isEmpty) return const SizedBox.shrink();
          return Column(
            children: missions.map((doc) {
              final d = doc.data();
              final title = d['mission_title'] as String? ?? (isMs ? 'Misi Menyelamat' : 'Rescue Mission');
              
              final ts = d['created_at'] as Timestamp?;
              final timeStr = ts != null 
                  ? '${isMs ? 'Agihan:' : 'Issued:'} ${ts.toDate().toLocal().hour.toString().padLeft(2, '0')}:${ts.toDate().toLocal().minute.toString().padLeft(2, '0')}'
                  : '';

              final contactName = d['contact_name'] as String? ?? '-';
              final phone = d['phone'] as String? ?? '-';
              final headCount = d['head_count'] as int? ?? 1;
              final desc = d['description'] as String? ?? (isMs ? 'Tiada penerangan' : 'No description');
              
              final sosTs = d['sos_created_at'] as Timestamp?;
              final sosTimeStr = sosTs != null
                ? '${sosTs.toDate().toLocal().hour.toString().padLeft(2, '0')}:${sosTs.toDate().toLocal().minute.toString().padLeft(2, '0')}'
                : timeStr; // fallback to dispatch time if sos_created is missing

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.warning.withAlpha(80), width: 2),
                    boxShadow: [BoxShadow(color: AppTheme.warning.withAlpha(20), blurRadius: 8)]),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.push(ctx, MaterialPageRoute(
                        builder: (_) => MissionDispatchScreen(missionId: doc.id, data: d))),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: AppTheme.warning, borderRadius: BorderRadius.circular(6)),
                            child: const Text('AKTIF / ACTIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(children: [
                                const Icon(Icons.sos, size: 12, color: AppTheme.emergency),
                                const SizedBox(width: 4),
                                Text(sosTimeStr, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.textSecondary)),
                              ]),
                              if (timeStr.isNotEmpty)
                                Text(timeStr, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                            ],
                          ),
                        ]),
                        const SizedBox(height: 12),
                        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black)),
                        if (d['mission_instruction'] != null && (d['mission_instruction'] as String).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              d['mission_instruction'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                            ),
                          ),
                        const SizedBox(height: 8),
                        
                        Row(children: [
                          const Icon(Icons.people_outline, size: 16, color: AppTheme.govBlue),
                          const SizedBox(width: 8),
                          Text('$headCount ${isMs ? "orang" : "people"}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary)),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.person_outline, size: 16, color: AppTheme.govBlue),
                          const SizedBox(width: 8),
                          Text(contactName, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.phone_outlined, size: 16, color: AppTheme.govBlue),
                          const SizedBox(width: 8),
                          Text(phone, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                        ]),
                        const SizedBox(height: 12),
                        if (desc.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppTheme.bgBase, borderRadius: BorderRadius.circular(8)),
                            child: Text(desc, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontStyle: FontStyle.italic)),
                          ),
                        ]
                      ]),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),

      const SizedBox(height: 16),
      const LocText('SELESAI (DARI FIREBASE)', 'COMPLETED (FROM FIRESTORE)',
          style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),

      // ── Firestore completed missions ──────────────────────────────────
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _repo.watchCompletedMissions(widget.userName),
        builder: (ctx, snap) {
          final missions = snap.data?.docs ?? [];
          if (missions.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border)),
              child: const Center(child: LocText(
                  'Belum ada misi selesai',
                  'No completed missions yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 13))),
            );
          }
          return Column(
            children: missions.map((doc) {
              final d = doc.data();
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border)),
                child: ListTile(
                  leading: const CircleAvatar(
                      backgroundColor: AppTheme.hope,
                      child: Icon(Icons.check, color: Colors.white, size: 18)),
                  title: Text((context.watch<LocaleProvider>().locale.languageCode == 'ms' ? 'Misi ' : 'Mission ') + doc.id.substring(0, 8),
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black)),
                  subtitle: Text(d['sos_id'] ?? '',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  trailing: IconButton(
                    icon: const Icon(Icons.badge_outlined, color: AppTheme.govBlue, size: 22),
                    tooltip: 'View Certificate',
                    onPressed: () => Navigator.push(ctx, MaterialPageRoute(
                      builder: (_) => ServiceCertificateScreen(
                        missionId: doc.id,
                        data: {...d, 'volunteer_name': widget.userName},
                      ),
                    )),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    ]);
  }

  // ── Consent section ───────────────────────────────────────────────────────
  Widget _buildConsentSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _standingConsent ? AppTheme.govBlueLight : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: _standingConsent ? AppTheme.govBlue : AppTheme.border,
            width: _standingConsent ? 2 : 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _standingConsent 
                      ? (context.watch<LocaleProvider>().locale.languageCode == 'ms' ? '🌟 Anda Aktif Sekarang' : '🌟 You are Active') 
                      : (context.watch<LocaleProvider>().locale.languageCode == 'ms' ? 'Kebenaran Tetap' : 'Standing Consent'),
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _standingConsent ? AppTheme.govBlue : Colors.black,
                      fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  _standingConsent
                      ? 'Sedia menerima tawaran misi kecemasan terus ke peranti tanpa pengesahan manual.'
                      : 'Aktifkan untuk menerima misi kecemasan automatik semasa krisis memuncak.',
                  style: TextStyle(
                      color: _standingConsent ? AppTheme.govBlue : AppTheme.textSecondary,
                      fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: _standingConsent,
            activeThumbColor: AppTheme.govBlue,
            activeTrackColor: AppTheme.govBlue.withAlpha(50),
            onChanged: (val) async {
              setState(() => _standingConsent = val);
              await _repo.updateConsent(widget.userName, val);
            },
          ),
        ],
      ),
    );
  }

  void _showRegistrationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _VolunteerRegistrationSheet(userName: widget.userName),
    );
  }
}

// ── Mission Offer Card ────────────────────────────────────────────────────────
class _MissionOfferCard extends StatelessWidget {
  final String missionId;
  final Map<String, dynamic> data;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  const _MissionOfferCard({required this.missionId, required this.data,
      required this.onAccept, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    final sosId = data['sos_id'] as String? ?? '';
    final headCount = data['head_count'] as int? ?? 0;
    final address = data['address'] as String? ?? 'Unknown Location';
    final distanceKm = (data['distance_km'] ?? '?').toString();
    final vulnerable = (data['vulnerable'] as List?)?.cast<String>() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.emergency.withAlpha(60)),
        boxShadow: [BoxShadow(color: AppTheme.emergency.withAlpha(15), blurRadius: 8)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 5, color: AppTheme.emergency),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: AppTheme.emergencyLight,
                          borderRadius: BorderRadius.circular(6)),
                      child: const Text('TAWARAN MISI', style: TextStyle(
                          color: AppTheme.emergency, fontWeight: FontWeight.w800, fontSize: 10)),
                    ),
                    const Spacer(),
                    Text('$distanceKm km', style: const TextStyle(
                        color: AppTheme.govBlue, fontWeight: FontWeight.w700, fontSize: 12)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(child: Text(address, style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black))),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.people_outline, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text('$headCount orang', style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
                    if (vulnerable.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppTheme.warningLight,
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(vulnerable.first, style: const TextStyle(
                            color: AppTheme.warning, fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    ],
                    if (sosId.isNotEmpty) ...[
                      const Spacer(),
                      Text(sosId, style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 10)),
                    ],
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onDecline,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          side: const BorderSide(color: AppTheme.border),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Tolak', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: onAccept,
                        icon: const Icon(Icons.directions_run, size: 16),
                        label: const Text('Terima & Pergi', style: TextStyle(fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.emergency,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Mission Phase Data Class ──────────────────────────────────────────────────
class _MissionPhase {
  final String time, label;
  final bool done;
  final IconData icon;
  const _MissionPhase({required this.time, required this.label,
      required this.done, required this.icon});
}

// ── Mission Timeline Card ─────────────────────────────────────────────────────
class _MissionTimelineCard extends StatefulWidget {
  final String missionId, title, group, status;
  final Color groupColor, statusColor;
  final List<_MissionPhase> phases;
  const _MissionTimelineCard({
    required this.missionId, required this.title, required this.group,
    required this.groupColor, required this.status, required this.statusColor,
    required this.phases,
  });
  @override
  State<_MissionTimelineCard> createState() => _MissionTimelineCardState();
}

class _MissionTimelineCardState extends State<_MissionTimelineCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final doneCount = widget.phases.where((p) => p.done).length;
    final total = widget.phases.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.groupColor.withAlpha(60)),
      ),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: widget.groupColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(widget.group, style: TextStyle(
                      color: widget.groupColor, fontSize: 10,
                      fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: widget.statusColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(widget.status, style: TextStyle(
                      color: widget.statusColor, fontSize: 10,
                      fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                ),
                const Spacer(),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.textSecondary, size: 20),
              ]),
              const SizedBox(height: 8),
              Text(widget.title, style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13, color: Colors.black)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: doneCount / total,
                      backgroundColor: AppTheme.border,
                      color: widget.statusColor,
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('$doneCount/$total', style: TextStyle(
                    color: widget.statusColor, fontWeight: FontWeight.w700, fontSize: 12)),
              ]),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Column(children: [
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    ...widget.phases.asMap().entries.map((e) {
                      final i = e.key;
                      final p = e.value;
                      final isLast = i == widget.phases.length - 1;
                      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Column(children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: p.done ? widget.groupColor : AppTheme.border,
                            child: Icon(p.done ? Icons.check : p.icon,
                                color: Colors.white, size: 14),
                          ),
                          if (!isLast)
                            Container(
                              width: 2, height: 28,
                              color: p.done
                                  ? widget.groupColor.withAlpha(60)
                                  : AppTheme.border,
                            ),
                        ]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 8),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(p.time, style: TextStyle(
                                  color: p.done ? widget.groupColor : AppTheme.textSecondary,
                                  fontWeight: FontWeight.w800, fontSize: 11)),
                              Text(p.label, style: TextStyle(
                                  color: p.done ? Colors.black : AppTheme.textSecondary,
                                  fontSize: 13,
                                  fontWeight: p.done ? FontWeight.w600 : FontWeight.normal)),
                            ]),
                          ),
                        ),
                      ]);
                    }),
                  ]),
                )
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }
}

class _VolunteerRegistrationSheet extends StatefulWidget {
  final String userName;
  const _VolunteerRegistrationSheet({required this.userName});
  @override
  State<_VolunteerRegistrationSheet> createState() =>
      _VolunteerRegistrationSheetState();
}

class _VolunteerRegistrationSheetState
    extends State<_VolunteerRegistrationSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _otherSkillCtrl = TextEditingController();
  final _repo = VolunteerRepository();
  bool _saving = false;
  String _vehicle = 'none';
  final Set<String> _skills = {};
  bool _showOtherSkill = false;

  static const _allSkills = [
    'first_aid', 'boat_operator', 'heavy_vehicle',
    'search_rescue', 'medic', 'malay', 'english', 'mandarin', 'scuba',
  ];

  static const _vehicleOptions = [
    ('boat',    '🚤 Bot / Boat',         Icons.directions_boat_outlined),
    ('car_4wd', '🚙 4x4 Vehicle',        Icons.directions_car_outlined),
    ('lorry',   '🚛 Lori / Lorry',       Icons.local_shipping_outlined),
  ];

  final Map<String, TextEditingController> _plateControllers = {};

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _otherSkillCtrl.dispose();
    for (final c in _plateControllers.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final profile = VolunteerProfile(
      uid: widget.userName,
      name: _nameCtrl.text.trim().isEmpty ? widget.userName : _nameCtrl.text.trim(),
      icNumber: '820314145271',
      phone: _phoneCtrl.text.trim(),
      skills: [
        ..._skills,
        if (_showOtherSkill && _otherSkillCtrl.text.trim().isNotEmpty)
          _otherSkillCtrl.text.trim()
      ],
      vehicleType: _vehicle,
      vehicleCapacity: _vehicle == 'boat' ? 8 : _vehicle == 'lorry' ? 20 : 4,
      standingConsent: true,
    );
    await _repo.save(widget.userName, profile);
    setState(() => _saving = false);
    if (mounted) await Future.delayed(const Duration(seconds: 1));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LocText('Daftar Sukarelawan', 'Register',
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 20, color: Colors.black)),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.black),
              decoration: _inputDec('Nama Penuh / Full Name', Icons.person),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              style: const TextStyle(color: Colors.black),
              decoration: _inputDec('No. Telefon / Phone', Icons.phone),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            const LocText('Kemahiran', 'Skills', style: TextStyle(
                color: Color(0xFF4B5563), fontSize: 12, letterSpacing: 1)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: [
                ..._allSkills.map((s) {
                  final on = _skills.contains(s);
                  return FilterChip(
                    label: Text(s, style: TextStyle(
                        fontSize: 11,
                        color: on ? AppTheme.emergency : const Color(0xFF4B5563))),
                    selected: on,
                    onSelected: (v) =>
                        setState(() => v ? _skills.add(s) : _skills.remove(s)),
                    selectedColor: AppTheme.emergencyLight,
                    checkmarkColor: AppTheme.emergency,
                    side: BorderSide(color: on ? AppTheme.emergency : AppTheme.border),
                    backgroundColor: Colors.white,
                  );
                }),
                ..._skills.where((s) => !_allSkills.contains(s)).map((s) {
                  return FilterChip(
                    label: Text(s, style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.emergency)),
                    selected: true,
                    onSelected: (v) =>
                        setState(() => v ? _skills.add(s) : _skills.remove(s)),
                    selectedColor: AppTheme.emergencyLight,
                    checkmarkColor: AppTheme.emergency,
                    side: const BorderSide(color: AppTheme.emergency),
                    backgroundColor: Colors.white,
                  );
                }),
                FilterChip(
                  label: LocText('Lain-lain', 'Others', style: TextStyle(
                      fontSize: 11,
                      color: _showOtherSkill ? AppTheme.emergency : const Color(0xFF4B5563))),
                  selected: _showOtherSkill,
                  onSelected: (v) => setState(() => _showOtherSkill = v),
                  selectedColor: AppTheme.emergencyLight,
                  checkmarkColor: AppTheme.emergency,
                  side: BorderSide(color: _showOtherSkill ? AppTheme.emergency : AppTheme.border),
                  backgroundColor: Colors.white,
                )
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _showOtherSkill ? Padding(
                padding: const EdgeInsets.only(top: 10),
                child: TextField(
                  controller: _otherSkillCtrl,
                  style: const TextStyle(color: Colors.black, fontSize: 13),
                  decoration: _inputDec('Nyatakan kemahiran / Specify other skills...', Icons.add_circle_outline),
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      setState(() {
                        _skills.add(val.trim());
                        _otherSkillCtrl.clear();
                      });
                    }
                  },
                ),
              ) : const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            const LocText('Kenderaan', 'Vehicle', style: TextStyle(
                color: Color(0xFF4B5563), fontSize: 12, letterSpacing: 1)),
            const SizedBox(height: 10),
            // Card-based vehicle toggles
            ..._vehicleOptions.map(((String, String, IconData) opt) {
              final selected = _vehicle == opt.$1;
              _plateControllers.putIfAbsent(opt.$1, () => TextEditingController());
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                GestureDetector(
                  onTap: () => setState(() => _vehicle = selected ? 'none' : opt.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.govBlueLight : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: selected ? AppTheme.govBlue : AppTheme.border,
                          width: selected ? 2 : 1),
                    ),
                    child: Row(children: [
                      Icon(opt.$3,
                          color: selected ? AppTheme.govBlue : AppTheme.textSecondary,
                          size: 22),
                      const SizedBox(width: 12),
                      Expanded(child: Text(opt.$2, style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14,
                          color: selected ? AppTheme.govBlue : Colors.black))),
                      if (selected)
                        const Icon(Icons.check_circle, color: AppTheme.govBlue, size: 20),
                    ]),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: selected
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TextField(
                            controller: _plateControllers[opt.$1],
                            style: const TextStyle(color: Colors.black, fontSize: 14),
                            textCapitalization: TextCapitalization.characters,
                            decoration: _inputDec(
                              'Plate No. (Optional) e.g. VAA 1234',
                              Icons.pin_outlined,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ]);
            }),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const LocText('SIMPAN', 'SAVE'),
              ),
            ),
          ],
        ), // Column
      ),   // SingleChildScrollView
    );
  }

  InputDecoration _inputDec(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        prefixIcon: Icon(icon, color: AppTheme.govBlue),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.govBlue, width: 2)),
      );
}
