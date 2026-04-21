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
          _buildMissionsSection(context),
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
            const SizedBox(height: 12),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _repo.watchResolvedIncidents(widget.userName),
              builder: (ctx, snap) {
                final count = snap.data?.docs.length ?? 0;
                final isMs = context.watch<LocaleProvider>().locale.languageCode == 'ms';
                return Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      isMs ? '$count Kes Selesai' : '$count Missions Done',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                );
              },
            ),
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

  // ── Missions section ──────────────────────────────────────────────────────
  Widget _buildMissionsSection(BuildContext context) {
    final isMs = Provider.of<LocaleProvider>(context).locale.languageCode == 'ms';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const LocText('SELESAI (DARI FIREBASE)', 'COMPLETED (FROM FIRESTORE)',
          style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),

      // ── Firestore completed missions ──────────────────────────────────
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _repo.watchResolvedIncidents(widget.userName),
        builder: (ctx, snap) {
          final incidents = snap.data?.docs ?? [];
          if (incidents.isEmpty) {
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
            children: incidents.map((doc) {
              final d = doc.data();
              final sosId = d['sos_id'] as String? ?? doc.id;
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
                  title: Text((context.watch<LocaleProvider>().locale.languageCode == 'ms' ? 'Misi ' : 'Mission ') + sosId,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black)),
                  subtitle: Text(d['address_text'] ?? d['address'] ?? '',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  trailing: IconButton(
                    icon: const Icon(Icons.badge_outlined, color: AppTheme.govBlue, size: 22),
                    tooltip: 'View Certificate',
                    onPressed: () => Navigator.push(ctx, MaterialPageRoute(
                      builder: (_) => ServiceCertificateScreen(
                        missionId: doc.id,
                        data: {
                          ...d, 
                          'volunteer_name': widget.userName,
                          'head_count': d['head_count'] ?? d['headcount'] ?? 1,
                        },
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
