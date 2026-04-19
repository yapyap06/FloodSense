import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/locale_provider.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    final isMs = localeProvider.locale.languageCode == 'ms';

    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top badge and Lang Switcher
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.govBlueLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.verified_outlined, color: AppTheme.govBlue, size: 14),
                        SizedBox(width: 4),
                        Text('Sistem Rasmi Malaysia', style: TextStyle(color: AppTheme.govBlue, fontSize: 12, fontWeight: FontWeight.w600)),
                      ]),
                    ),
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
                  ],
                ),
                const SizedBox(height: 32),

                // Logo
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.govBlue,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: AppTheme.govBlue.withAlpha(60), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: const Icon(Icons.waves, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 24),

                // Title
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(text: 'Flood', style: TextStyle(color: AppTheme.govBlue, fontWeight: FontWeight.w900, fontSize: 40)),
                      TextSpan(text: 'Sense', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w900, fontSize: 40)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Malaysia', style: TextStyle(color: AppTheme.govBlue, fontWeight: FontWeight.w400, fontSize: 20, letterSpacing: 2)),
                const SizedBox(height: 16),
                Text(
                  isMs ? 'Menghubungkan data untuk kehidupan.' : 'Connecting data to lives.',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 17, fontStyle: FontStyle.italic),
                ),

                const SizedBox(height: 40),

                // Phase indicators
              _PhaseCard(
                color: AppTheme.govBlue,
                icon: Icons.shield_outlined,
                label: isMs ? 'Sebelum — Kesediaan' : 'Before — Preparedness',
                sub: isMs ? 'Semak status, cari pusat PPS' : 'Check readiness, locate shelters',
              ),
              const SizedBox(height: 10),
              _PhaseCard(
                color: AppTheme.emergency,
                icon: Icons.sos_outlined,
                label: isMs ? 'Semasa — Kecemasan' : 'During — Emergency',
                sub: isMs ? 'SOS, sukarelawan, bantuan AI' : 'SOS, rescue dispatch, AI guide',
              ),
              const SizedBox(height: 10),
              _PhaseCard(
                color: AppTheme.hope,
                icon: Icons.healing_outlined,
                label: isMs ? 'Selepas — Pemulihan' : 'After — Recovery',
                sub: isMs ? 'Tuntutan kerosakan, borang bantuan' : 'Damage claims, aid application',
              ),

              const SizedBox(height: 40),

              // CTA
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  child: Text(isMs ? 'Mula Sekarang' : 'Get Started'),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  isMs ? 'Dikuasakan oleh Google Gemini AI' : 'Powered by Google Gemini AI',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }
}

class _PhaseCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final String sub;
  const _PhaseCard({required this.color, required this.icon, required this.label, required this.sub});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: color.withAlpha(12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withAlpha(40)),
    ),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
        Text(sub, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ])),
    ]),
  );
}
