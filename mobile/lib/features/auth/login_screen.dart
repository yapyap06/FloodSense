import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/locale_provider.dart';
import 'role_selection_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _icCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _continue(String langCode) async {
    final name = _phoneCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(langCode == 'ms' 
              ? 'Sila masukkan nombor telefon anda untuk meneruskan.' 
              : 'Please enter your phone number to continue.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 600)); // simulated auth
    if (mounted) {
      setState(() => _loading = false);
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => RoleSelectionScreen(name: name),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    final isMs = localeProvider.locale.languageCode == 'ms';

    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      appBar: AppBar(
        title: Text(isMs ? 'Log Masuk' : 'Sign In'),
        automaticallyImplyLeading: false, // no back arrow — forward-only flow
        actions: [
          TextButton.icon(
            onPressed: () {
              localeProvider.setLocale(Locale(isMs ? 'en' : 'ms'));
            },
            icon: const Icon(Icons.language, color: AppTheme.govBlue, size: 18),
            label: Text(
              isMs ? 'MS' : 'EN',
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.govBlue),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),

          // Header
          Text(isMs ? 'Selamat kembali' : 'Welcome back', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 26, color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          Text(isMs ? 'Masukkan butiran anda untuk meneruskan' : 'Enter your details to continue', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
          const SizedBox(height: 32),

          // Phone
          Text(isMs ? 'Nombor Telefon' : 'Phone Number', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: '+60 1X-XXX XXXX',
              prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 20),

          // IC
          Text(isMs ? 'Nombor Kad Pengenalan (MyKad)' : 'MyKad (IC) Number', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          TextField(
            controller: _icCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'XXXXXX-XX-XXXX',
              prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 12),

          // OTP note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.govBlueLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, color: AppTheme.govBlue, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(isMs 
                  ? 'Kod OTP akan dihantar ke telefon anda untuk pengesahan.' 
                  : 'An OTP will be sent to your phone for verification.',
                  style: const TextStyle(color: AppTheme.govBlue, fontSize: 12))),
            ]),
          ),
          const SizedBox(height: 32),

          // Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : () => _continue(isMs ? 'ms' : 'en'),
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(isMs ? 'Teruskan' : 'Continue'),
            ),
          ),
          const SizedBox(height: 16),

          // Guest mode
          Center(
            child: TextButton(
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(
                builder: (_) => RoleSelectionScreen(name: isMs ? 'Tetamu' : 'Guest'),
              )),
              child: Text(isMs ? 'Teruskan sebagai Tetamu' : 'Continue as Guest',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Center(
            child: Text(isMs ? 'Kecemasan? Hubungi 999 atau SMS 15888' : 'Emergency? Call 999 or SMS 15888',
                style: const TextStyle(color: AppTheme.emergency, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ]),
      ),
    );
  }
}
