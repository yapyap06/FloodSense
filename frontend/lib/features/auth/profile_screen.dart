import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/locale_provider.dart';
import '../auth/welcome_screen.dart';
import '../auth/role_selection_screen.dart';

/// Unified Profile Screen — works for Citizen, Volunteer, and Government roles.
/// Always shows: Role label, ID hash, and a prominent [Log Out] button.
class ProfileScreen extends StatefulWidget {
  final String userName;
  final UserRole role;
  const ProfileScreen({super.key, required this.userName, this.role = UserRole.citizen});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _offlineMode = false;
  bool _batterySave = false;

  // ── Role metadata ─────────────────────────────────────────────────────────

  String get _roleLabel {
    switch (widget.role) {
      case UserRole.government:
        return 'Government Official — NADMA';
      case UserRole.volunteer:
        return 'Volunteer / Sukarelawan';
      case UserRole.citizen:
        return 'Warga Malaysia · FloodSense Citizen';
    }
  }

  Color get _roleColor {
    switch (widget.role) {
      case UserRole.government:
        return const Color(0xFF1E3A5F);
      case UserRole.volunteer:
        return AppTheme.hope;
      case UserRole.citizen:
        return AppTheme.govBlue;
    }
  }

  IconData get _roleIcon {
    switch (widget.role) {
      case UserRole.government:
        return Icons.shield_outlined;
      case UserRole.volunteer:
        return Icons.handshake_outlined;
      case UserRole.citizen:
        return Icons.person_outline;
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  void _logout() {
    // Clear session and return to Role Selection (demo start screen)
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMalay = Provider.of<LocaleProvider>(context).locale.languageCode == 'ms';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(isMalay ? 'Profil & Tetapan' : 'Profile & Settings',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Avatar & identity ──────────────────────────────────────────────
          Center(
            child: Column(children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: _roleColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: _roleColor.withAlpha(60),
                        blurRadius: 16,
                        offset: const Offset(0, 6))
                  ],
                ),
                child: Center(
                  child: Text(
                    widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(widget.userName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 20, color: Colors.black)),
              const SizedBox(height: 4),
              // Role badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _roleColor.withAlpha(15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _roleColor.withAlpha(40)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_roleIcon, color: _roleColor, size: 14),
                  const SizedBox(width: 6),
                  Text(_roleLabel,
                      style: TextStyle(
                          color: _roleColor, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 28),

          // ── My Details ────────────────────────────────────────────────────
          _SectionHeader(label: isMalay ? 'Maklumat Saya' : 'My Details'),
          const SizedBox(height: 12),
          const _DetailTile(
              icon: Icons.badge_outlined, label: 'MyKad (IC)', value: '••••••-••-••••'),
          _DetailTile(
              icon: Icons.phone_outlined,
              label: isMalay ? 'Kenalan Kecemasan' : 'Emergency Contact',
              value: '+60 12-345 6789'),
          _DetailTile(
              icon: Icons.location_on_outlined,
              label: isMalay ? 'Alamat Berdaftar' : 'Registered Address',
              value: 'No. 12, Jalan Meru, 41050 Klang, Selangor'),
          const SizedBox(height: 24),

          // ── Household (citizens only) ─────────────────────────────────────
          if (widget.role == UserRole.citizen) ...[
            _SectionHeader(label: isMalay ? 'Isi Rumah' : 'Household'),
            const SizedBox(height: 12),
            _DetailTile(
                icon: Icons.people_outline, label: isMalay ? 'Saiz Isi Rumah' : 'Household Size', value: isMalay ? '4 ahli' : '4 members'),
            _DetailTile(
                icon: Icons.child_care_outlined,
                label: isMalay ? 'Keperluan Khas' : 'Special Needs',
                value: isMalay ? 'Tiada pendaftaran' : 'None registered'),
            const SizedBox(height: 24),
          ],

          // ── Language Settings ────────────────────────────────────────────
          _SectionHeader(label: isMalay ? 'Bahasa' : 'Language'),
          const SizedBox(height: 12),
          Consumer<LocaleProvider>(
            builder: (context, localeProvider, _) {
              final current = localeProvider.locale.languageCode;
              return Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border)),
                child: Column(children: [
                  _LangTile(
                    label: 'English',
                    sub: isMalay ? 'Bahasa lalai' : 'Default language',
                    selected: current == 'en',
                    onTap: () async {
                      if (current == 'en') return;
                      await localeProvider.setLocale(const Locale('en'));
                      if (context.mounted) _logout();
                    },
                  ),
                  const Divider(height: 0, indent: 16, endIndent: 16),
                  _LangTile(
                    label: 'Bahasa Melayu',
                    sub: isMalay ? 'Bahasa kebangsaan' : 'Malaysian language',
                    selected: current == 'ms',
                    onTap: () async {
                      if (current == 'ms') return;
                      await localeProvider.setLocale(const Locale('ms'));
                      if (context.mounted) _logout();
                    },
                  ),
                ]),
              );
            },
          ),
          const SizedBox(height: 24),

          // ── App Settings ─────────────────────────────────────────────────
          _SectionHeader(label: isMalay ? 'Tetapan Aplikasi' : 'App Settings'),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border)),
            child: Column(children: [
              _ToggleTile(
                icon: Icons.wifi_off_outlined,
                label: isMalay ? 'Mod Luar Talian' : 'Offline Mode',
                sub: isMalay ? 'Simpan SOP & peta untuk kegunaan tanpa isyarat' : 'Cache SOPs & maps for no-signal use',
                value: _offlineMode,
                onChanged: (v) => setState(() => _offlineMode = v),
              ),
              const Divider(height: 0, indent: 16, endIndent: 16),
              _ToggleTile(
                icon: Icons.battery_saver_outlined,
                label: isMalay ? 'Mod Penjimat Bateri' : 'Battery Save Mode',
                sub: isMalay ? 'Kurangkan sinkronisasi latar bawah 20% bateri' : 'Reduce background sync below 20% battery',
                value: _batterySave,
                onChanged: (v) => setState(() => _batterySave = v),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // ── About ─────────────────────────────────────────────────────────
          _SectionHeader(label: isMalay ? 'Mengenai' : 'About'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _AboutRow(label: isMalay ? 'Versi' : 'Version', value: '1.0.0 (Demo)'),
              const SizedBox(height: 8),
              _AboutRow(label: isMalay ? 'Agensi' : 'Agency', value: 'APM / NADMA Malaysia'),
              const SizedBox(height: 8),
              const _AboutRow(label: 'AI Engine', value: 'Google Gemini 2.5 Flash'),
              const SizedBox(height: 8),
              _AboutRow(label: isMalay ? 'Acara' : 'Hackathon', value: 'Google AI Hackathon 2026'),
            ]),
          ),
          const SizedBox(height: 32),

          // ── Log Out — Large red-bordered button ──────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: Colors.white,
                  title: Text(isMalay ? 'Log Keluar?' : 'Log Out?', style: const TextStyle(color: Colors.black)),
                  content: Text(
                      isMalay ? 'Anda akan dikembalikan ke skrin pemilihan peranan.' : 'You will be returned to the role selection screen.',
                      style: const TextStyle(color: Color(0xFF4B5563))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(isMalay ? 'Batal' : 'Cancel',
                            style: const TextStyle(color: Color(0xFF6B7280)))),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _logout();
                      },
                      child: Text(isMalay ? 'Log Keluar' : 'Log Out',
                          style: const TextStyle(
                              color: AppTheme.emergency, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              icon: const Icon(Icons.logout, color: AppTheme.emergency, size: 22),
              label: Text(isMalay ? 'Log Keluar' : 'Log Out',
                  style: const TextStyle(
                      color: AppTheme.emergency,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.emergency, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});
  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: AppTheme.textMuted,
          letterSpacing: 0.5));
}

class _LangTile extends StatelessWidget {
  final String label, sub;
  final bool selected;
  final VoidCallback onTap;
  const _LangTile({
    required this.label, required this.sub,
    required this.selected, required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black)),
          Text(sub, style: const TextStyle(color: Color(0xFF4B5563), fontSize: 12)),
        ])),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 22, height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? AppTheme.govBlue : Colors.transparent,
            border: Border.all(color: selected ? AppTheme.govBlue : AppTheme.border, width: 2),
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 14)
              : null,
        ),
      ]),
    ),
  );
}

class _DetailTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _DetailTile({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border)),
        child: Row(children: [
          Icon(icon, color: AppTheme.govBlue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.w600, fontSize: 14)),
            ]),
          ),
        ]),
      );
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleTile(
      {required this.icon,
      required this.label,
      required this.sub,
      required this.value,
      required this.onChanged});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Icon(icon, color: AppTheme.govBlue, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black)),
              Text(sub,
                  style:
                      const TextStyle(color: Color(0xFF4B5563), fontSize: 12)),
            ]),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.govBlue,
            activeTrackColor: AppTheme.govBlueLight,
          ),
        ]),
      );
}

class _AboutRow extends StatelessWidget {
  final String label, value;
  const _AboutRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Row(children: [
        Text('$label  ',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
        Text(value,
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.w600, fontSize: 13)),
      ]);
}
