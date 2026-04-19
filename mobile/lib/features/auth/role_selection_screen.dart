import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/locale_provider.dart';
import '../../app_shell.dart';

enum UserRole { citizen, volunteer, government }

class RoleSelectionScreen extends StatefulWidget {
  final String phone;
  final String ic;
  const RoleSelectionScreen({super.key, required this.phone, required this.ic});
  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  UserRole _selected = UserRole.citizen;
  final _govCodeCtrl = TextEditingController();
  final _volIdCtrl = TextEditingController();
  bool _govCodeError = false;

  void _proceed() {
    if (_selected == UserRole.government) {
      if (_govCodeCtrl.text.trim() != '9999') {
        setState(() => _govCodeError = true);
        return;
      }
    }
    
    final finalIc = (_selected == UserRole.volunteer && _volIdCtrl.text.trim().isNotEmpty)
        ? _volIdCtrl.text.trim()
        : widget.ic;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => AppShell(role: _selected, phone: widget.phone, ic: finalIc)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMs = context.watch<LocaleProvider>().locale.languageCode == 'ms';
    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      appBar: AppBar(
        title: Text(isMs ? 'Pilih Peranan' : 'Select Role'),
        automaticallyImplyLeading: false, // no back — forward-only auth flow
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isMs ? 'Selamat datang, ${widget.ic}! 👋' : 'Welcome, ${widget.ic}! 👋',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          Text(isMs ? 'Bagaimanakah anda akan menggunakan FloodSense hari ini?' : 'How will you use FloodSense today?', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
          const SizedBox(height: 28),

          _RoleCard(
            role: UserRole.citizen,
            selected: _selected,
            icon: Icons.person_outline,
            title: isMs ? 'Rakyat' : 'Citizen',
            subtitle: isMs ? 'Amaran SOS, panduan, tuntutan kerosakan' : 'SOS alerts, preparedness guide, damage claims',
            color: AppTheme.govBlue,
            onTap: () => setState(() { _selected = UserRole.citizen; _govCodeError = false; }),
          ),
          const SizedBox(height: 12),
          _RoleCard(
            role: UserRole.volunteer,
            selected: _selected,
            icon: Icons.handshake_outlined,
            title: isMs ? 'Sukarelawan' : 'Volunteer',
            subtitle: isMs ? 'Terima tawaran misi, koordinasi menyelamat' : 'Receive mission offers, rescue coordination',
            color: AppTheme.hope,
            onTap: () => setState(() { _selected = UserRole.volunteer; _govCodeError = false; }),
          ),
          if (_selected == UserRole.volunteer) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _volIdCtrl,
              decoration: InputDecoration(
                labelText: isMs ? 'ID Sukarelawan (pilihan untuk demo)' : 'Volunteer ID (optional for demo)',
                prefixIcon: const Icon(Icons.badge_outlined, color: AppTheme.hope),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _RoleCard(
            role: UserRole.government,
            selected: _selected,
            icon: Icons.shield_outlined,
            title: isMs ? 'Pegawai Kerajaan' : 'Government Official',
            subtitle: isMs ? 'Papan pemuka arahan, peta langsung, AI sitrep' : 'Command dashboard, live map, AI sitrep',
            color: const Color(0xFF1E3A5F),
            onTap: () => setState(() { _selected = UserRole.government; _govCodeError = false; }),
          ),
          if (_selected == UserRole.government) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _govCodeCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: InputDecoration(
                labelText: isMs ? 'Kod Akses Agensi' : 'Agency Access Code',
                hintText: isMs ? 'Masukkan kod (demo: 9999)' : 'Enter code (demo: 9999)',
                prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF1E3A5F)),
                errorText: _govCodeError ? (isMs ? 'Kod tidak sah. Cuba 9999 untuk demo.' : 'Invalid code. Try 9999 for demo.') : null,
              ),
              onChanged: (_) => setState(() => _govCodeError = false),
            ),
          ],

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _proceed,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selected == UserRole.government
                    ? const Color(0xFF1E3A5F)
                    : _selected == UserRole.volunteer ? AppTheme.hope : AppTheme.govBlue,
              ),
              child: Text(isMs ? 'Masuk ke FloodSense' : 'Enter FloodSense'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final UserRole role;
  final UserRole selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _RoleCard({required this.role, required this.selected, required this.icon,
      required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = role == selected;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(15) : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? color : AppTheme.border, width: isSelected ? 2 : 1),
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: color.withAlpha(isSelected ? 40 : 20), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: isSelected ? color : AppTheme.textPrimary)),
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ])),
          if (isSelected) Icon(Icons.check_circle, color: color, size: 22),
        ]),
      ),
    );
  }
}
