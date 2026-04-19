import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';

// ── Static (demo) alert model ──────────────────────────────────────────────
class _Alert {
  final String id; // unique id (doc id for firestore, or fixed key for static)
  final String title, body, time;
  final IconData icon;
  final Color color;
  _Alert({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    required this.icon,
    required this.color,
  });
}

// Static demo alerts (shown to all users, clearable per-user via Firestore)
final _staticAlerts = [
  _Alert(
      id: 'static_river',
      title: 'River Level Warning',
      body: 'Sg. Klang has risen to 4.2m. Danger threshold is 4.0m. Prepare for possible evacuation.',
      time: '10:14 AM',
      icon: Icons.water,
      color: AppTheme.emergency),
  _Alert(
      id: 'static_rescue',
      title: 'Rescue Update',
      body: 'SOS-A1F2: Volunteer Khairul is 1.2km away. ETA 8 minutes.',
      time: '10:02 AM',
      icon: Icons.directions_boat,
      color: AppTheme.hope),
  _Alert(
      id: 'static_claim',
      title: 'Claim Status Update',
      body: 'Your damage claim CLM-1A2B3C is now Under Review by JKM officers.',
      time: '9:30 AM',
      icon: Icons.assignment_outlined,
      color: AppTheme.govBlue),
  _Alert(
      id: 'static_pps',
      title: 'PPS Alert',
      body: 'SK Kampung Baru relief centre is now at 90% capacity. Consider SK Sek. 7 Shah Alam as alternative.',
      time: 'Yesterday',
      icon: Icons.home_work_outlined,
      color: AppTheme.warning),
];

// ── Public API ─────────────────────────────────────────────────────────────
/// [userName] is the Firestore user key to store dismissed IDs under.
/// [role] filters broadcast notifications ('citizen' | 'volunteer' | 'all').
void showNotificationCenter(
  BuildContext context, {
  String role = 'all',
  String userName = '',
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    builder: (_) => _NotificationSheet(role: role, userName: userName),
  );
}

// ── Widget ─────────────────────────────────────────────────────────────────
class _NotificationSheet extends StatefulWidget {
  final String role;
  final String userName;
  const _NotificationSheet({this.role = 'all', this.userName = ''});

  @override
  State<_NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<_NotificationSheet> {
  // IDs of notifications the user has dismissed (loaded from Firestore)
  Set<String> _dismissed = {};
  bool _loadingDismissed = true;

  DocumentReference? get _userRef => widget.userName.isEmpty
      ? null
      : FirebaseFirestore.instance.collection('users').doc(widget.userName);

  @override
  void initState() {
    super.initState();
    _loadDismissed();
  }

  Future<void> _loadDismissed() async {
    if (_userRef == null) {
      setState(() => _loadingDismissed = false);
      return;
    }
    try {
      final snap = await _userRef!.get();
      final data = snap.data() as Map<String, dynamic>?;
      final list = (data?['dismissed_notifications'] as List?)
              ?.map((e) => e.toString())
              .toSet() ??
          {};
      if (mounted) setState(() { _dismissed = list; _loadingDismissed = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingDismissed = false);
    }
  }

  Future<void> _saveDismissed(Set<String> ids) async {
    if (_userRef == null) return;
    await _userRef!.set(
      {'dismissed_notifications': ids.toList()},
      SetOptions(merge: true),
    );
  }

  Future<void> _dismissOne(String id) async {
    final updated = {..._dismissed, id};
    setState(() => _dismissed = updated);
    await _saveDismissed(updated);
  }

  Future<void> _clearAll(Set<String> ids) async {
    final updated = {..._dismissed, ...ids};
    setState(() => _dismissed = updated);
    await _saveDismissed(updated);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 200) Navigator.pop(context);
      },
      behavior: HitTestBehavior.translucent,
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        minChildSize: 0.35,
        builder: (_, controller) => GestureDetector(
          onTap: () {},
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(children: [
                  const Text('Notifications',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: AppTheme.textPrimary)),
                  const Spacer(),
                  // Clear All persists to Firestore
                  _loadingDismissed
                    ? const SizedBox.shrink()
                    : TextButton(
                        onPressed: () async {
                          // We'll compute visible IDs inside StreamBuilder,
                          // so use a state flag to trigger clear
                          setState(() => _clearAllPending = true);
                        },
                        child: const Text('Clear All',
                            style: TextStyle(color: AppTheme.emergency, fontSize: 13)),
                      ),
                ]),
              ),

              // List
              Expanded(
                child: _loadingDismissed
                  ? const Center(child: CircularProgressIndicator())
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('notifications')
                          .orderBy('created_at', descending: true)
                          .snapshots(),
                      builder: (ctx, snap) {
                        final allDocs = snap.data?.docs ?? [];

                        // Filter Firestore broadcasts by role
                        final fireDocs = allDocs.where((doc) {
                          final d = doc.data() as Map<String, dynamic>;
                          final target = d['target'] as String? ?? 'all';
                          return target == 'all' || target == widget.role;
                        }).toList();

                        // Build combined list: Firestore first, then static
                        final fireAlerts = fireDocs.map((doc) {
                          final d = doc.data() as Map<String, dynamic>;
                          final type = d['type'] as String?;
                          final timestamp = d['created_at'] as Timestamp?;
                          return _Alert(
                            id: doc.id,
                            title: d['title']?.toString() ?? 'Broadcast',
                            body: d['message']?.toString() ?? '',
                            time: timestamp != null
                                ? '${timestamp.toDate().toLocal().hour.toString().padLeft(2, '0')}:${timestamp.toDate().toLocal().minute.toString().padLeft(2, '0')}'
                                : 'Just now',
                            icon: type == 'alert'
                                ? Icons.announcement_outlined
                                : Icons.info_outline,
                            color: type == 'alert'
                                ? AppTheme.emergency
                                : AppTheme.govBlue,
                          );
                        }).toList();

                        final allAlerts = [...fireAlerts, ..._staticAlerts];

                        // Handle Clear All press
                        if (_clearAllPending) {
                          _clearAllPending = false;
                          final ids = allAlerts.map((a) => a.id).toList();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _clearAll(ids.toSet());
                          });
                        }

                        // Filter out dismissed
                        final visible = allAlerts
                            .where((a) => !_dismissed.contains(a.id))
                            .toList();

                        if (visible.isEmpty) {
                          return const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.notifications_none,
                                    color: AppTheme.border, size: 48),
                                SizedBox(height: 12),
                                Text('No alerts',
                                    style: TextStyle(color: AppTheme.textMuted)),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          controller: controller,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final a = visible[i];
                            // Swipe-to-dismiss
                            return Dismissible(
                              key: ValueKey(a.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: AppTheme.emergency.withAlpha(20),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.delete_outline,
                                    color: AppTheme.emergency),
                              ),
                              onDismissed: (_) => _dismissOne(a.id),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 40, height: 40,
                                      decoration: BoxDecoration(
                                          color: a.color.withAlpha(20),
                                          borderRadius: BorderRadius.circular(10)),
                                      child: Icon(a.icon, color: a.color, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            Expanded(
                                              child: Text(a.title,
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 13,
                                                      color: Colors.black)),
                                            ),
                                            Text(a.time,
                                                style: const TextStyle(
                                                    color: AppTheme.textMuted,
                                                    fontSize: 10)),
                                          ]),
                                          const SizedBox(height: 4),
                                          Text(a.body,
                                              style: const TextStyle(
                                                  color: Color(0xFF4B5563),
                                                  fontSize: 12,
                                                  height: 1.4)),
                                        ],
                                      ),
                                    ),
                                    // Individual delete button
                                    GestureDetector(
                                      onTap: () => _dismissOne(a.id),
                                      child: const Padding(
                                        padding: EdgeInsets.only(left: 8, top: 2),
                                        child: Icon(Icons.close,
                                            size: 16, color: AppTheme.textMuted),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  bool _clearAllPending = false;
}
