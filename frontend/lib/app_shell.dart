import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/providers/locale_provider.dart';
import 'features/auth/role_selection_screen.dart';
import 'features/auth/profile_screen.dart';
import 'features/home/citizen_home_screen.dart';
import 'features/home/gov_home_screen.dart';
import 'features/sos/sos_screen.dart';
import 'features/sop/sop_screen.dart';
import 'features/government/gov_ai_screen.dart';
import 'features/government/gov_sos_screen.dart';
import 'features/government/gov_pps_screen.dart';
import 'features/government/gov_claims_screen.dart';
import 'features/recovery/damage_claim_screen.dart';
import 'features/volunteer/volunteer_screen.dart';
import 'features/volunteer/volunteer_home_screen.dart';
import 'features/volunteer/volunteer_sos_screen.dart';
import 'features/volunteer/volunteer_guide_screen.dart';
import 'core/theme/app_theme.dart';

class AppShell extends StatefulWidget {
  final UserRole role;
  final String phone;
  final String ic;
  const AppShell({super.key, required this.role, required this.phone, required this.ic});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  // ── Screen lists (lazy — only built once by IndexedStack) ─────────────────

  late final List<Widget> _citizenScreens = [
    CitizenHomeScreen(userName: widget.ic),
    SOSScreen(contactName: widget.ic, phone: widget.phone),
    SOPScreen(userName: '${widget.role.name}_${widget.ic}'),
    DamageClaimScreen(userName: widget.ic),
  ];

  late final List<Widget> _volunteerScreens = [
    VolunteerHomeScreen(userName: widget.ic, onSwitchTab: _onTap),
    VolunteerSOSScreen(userName: widget.ic),
    VolunteerScreen(userName: widget.ic),
    SOPScreen(userName: '${widget.role.name}_${widget.ic}'),
    const VolunteerGuideScreen(),
  ];

  late final List<Widget> _govScreens = [
    const GovHomeScreen(),
    const GovSOSScreen(),
    const GovPPSScreen(),
    const GovClaimsScreen(),
    const GovAIScreen(),
  ];

  List<Widget> get _screens => switch (widget.role) {
        UserRole.government => _govScreens,
        UserRole.volunteer => _volunteerScreens,
        _ => _citizenScreens,
      };

  List<_NavItem> _buildNavItems(BuildContext context) {
    final isMs = context.watch<LocaleProvider>().locale.languageCode == 'ms';
    // Government always English; Volunteer partially translated; Citizen fully translated
    return switch (widget.role) {
        UserRole.government => const [
            _NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Command'),
            _NavItem(icon: Icons.sos_outlined, activeIcon: Icons.sos, label: 'SOS Command', isEmergency: true),
            _NavItem(icon: Icons.location_city_outlined, activeIcon: Icons.location_city, label: 'PPS & Supply'),
            _NavItem(icon: Icons.assignment_outlined, activeIcon: Icons.assignment, label: 'Claims Audit'),
            _NavItem(icon: Icons.smart_toy_outlined, activeIcon: Icons.smart_toy, label: 'Command AI'),
          ],
        UserRole.volunteer => [
            _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: isMs ? 'Utama' : 'Home'),
            _NavItem(icon: Icons.sos_outlined, activeIcon: Icons.sos, label: isMs ? 'SOS' : 'SOS', isEmergency: true),
            _NavItem(icon: Icons.volunteer_activism_outlined, activeIcon: Icons.volunteer_activism, label: isMs ? 'Misi' : 'Missions'),
            _NavItem(icon: Icons.smart_toy_outlined, activeIcon: Icons.smart_toy, label: isMs ? 'Sembang AI' : 'Chat AI'),
            _NavItem(icon: Icons.help_outline, activeIcon: Icons.help, label: isMs ? 'Panduan' : 'Guide'),
          ],
        _ => [
            _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: isMs ? 'Utama' : 'Home'),
            _NavItem(icon: Icons.sos_outlined, activeIcon: Icons.sos, label: isMs ? 'SOS' : 'SOS', isEmergency: true),
            _NavItem(icon: Icons.smart_toy_outlined, activeIcon: Icons.smart_toy, label: isMs ? 'Sembang AI' : 'Chat AI'),
            _NavItem(icon: Icons.assignment_outlined, activeIcon: Icons.assignment, label: isMs ? 'Tuntutan' : 'Claim'),
          ],
      };
  }

  void _onTap(int i) {
    if (i == _index) return; // no-op same tab
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    // All roles get a header — citizens get a lightweight branding bar too
    return Scaffold(
      appBar: _buildAppBar(context),
      body: IndexedStack(
        index: _index.clamp(0, _screens.length - 1),
        children: _screens,
      ),
      bottomNavigationBar: _BottomNav(
        items: _buildNavItems(context),
        currentIndex: _index,
        onTap: _onTap,
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    final isCitizen = widget.role == UserRole.citizen;
    final isGov = widget.role == UserRole.government;
    final roleLabel = isGov ? 'Command Centre' : isCitizen ? 'FloodSense' : 'Volunteer Portal';
    final roleColor = isGov ? const Color(0xFF1E3A5F) : isCitizen ? AppTheme.govBlue : AppTheme.hope;

    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      title: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: roleColor.withAlpha(15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isCitizen ? Icons.waves_outlined
                : isGov ? Icons.shield_outlined
                : Icons.handshake_outlined,
            color: roleColor, size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Text(roleLabel,
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.w700, fontSize: 17)),
      ]),
      actions: [
        // Notification bell (volunteer)
        if (widget.role == UserRole.volunteer)
          const SizedBox.shrink(), // Volunteer bell is embedded in VolunteerHomeScreen header

        // Live badge (gov)
        if (isGov)
          Container(
            margin: const EdgeInsets.only(right: 8, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(20)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.circle, color: Color(0xFF16A34A), size: 8),
              SizedBox(width: 4),
              Text('LIVE',
                  style: TextStyle(
                      color: Color(0xFF16A34A),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 1)),
            ]),
          ),

        // Avatar → Profile (ALL roles)
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ProfileScreen(userName: widget.ic, role: widget.role),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            width: 34, height: 34,
            decoration: BoxDecoration(color: roleColor, shape: BoxShape.circle),
            child: Center(
              child: Text(
                widget.ic.isNotEmpty ? widget.ic[0].toUpperCase() : 'U',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: AppTheme.border),
      ),
    );
  }
}

// ── Custom Bottom Navigation Bar ─────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isEmergency;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.isEmergency = false,
  });
}

class _BottomNav extends StatefulWidget {
  final List<_NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<_BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<_BottomNav> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.border, width: 0.8)),
        boxShadow: [
          BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(widget.items.length, (i) {
              final item = widget.items[i];
              final isActive = i == widget.currentIndex;

              // SOS button gets special treatment — always prominent
              if (item.isEmergency) {
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _pulse,
                          builder: (context, _) => Container(
                            width: 48, height: 32,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppTheme.emergency
                                  : AppTheme.emergency.withAlpha(18),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: !isActive
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.emergency.withAlpha((_pulse.value * 102).toInt()),
                                        blurRadius: 10 * _pulse.value,
                                        spreadRadius: 2 * _pulse.value,
                                      )
                                    ]
                                  : [],
                            ),
                            child: Icon(
                              isActive ? item.activeIcon : item.icon,
                              color: isActive ? Colors.white : AppTheme.emergency,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isActive ? AppTheme.emergency : AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Normal tab
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 48, height: 32,
                        decoration: BoxDecoration(
                          color: isActive ? AppTheme.govBlueLight : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          isActive ? item.activeIcon : item.icon,
                          color: isActive ? AppTheme.govBlue : AppTheme.textMuted,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 3),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 180),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive ? AppTheme.govBlue : AppTheme.textMuted,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
