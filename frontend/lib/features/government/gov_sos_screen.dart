import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/locale_provider.dart';

// ── Government SOS Command Screen ─────────────────────────────────────────────
// Real-time operational view for commanders to see, dispatch, and resolve SOS
class GovSOSScreen extends StatefulWidget {
  const GovSOSScreen({super.key});
  @override
  State<GovSOSScreen> createState() => _GovSOSScreenState();
}

class _GovSOSScreenState extends State<GovSOSScreen> {
  String _filter = 'ALL'; // ALL, PENDING, ASSIGNED, RESOLVED

  static const _filters = ['ALL', 'PENDING', 'ASSIGNED', 'RESOLVED'];

  @override
  Widget build(BuildContext context) {
    final isMs = context.watch<LocaleProvider>().locale.languageCode == 'ms';
    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      body: Column(children: [
        _buildHeader(isMs),
        _buildFilterChips(isMs),
        Expanded(child: _buildList(isMs)),
      ]),
    );
  }

  Widget _buildHeader(bool isMs) => Container(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF0F2044), Color(0xFF1E3A5F)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.emergency.withAlpha(30),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.sos, color: AppTheme.emergency, size: 24),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isMs ? 'Pusat Kawalan SOS' : 'SOS Command Centre',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
          Text(isMs ? 'Pengurusan & penghantaran masa nyata' : 'Real-time incident management & dispatch',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ]),
      ),
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('incidents')
            .where('status', isEqualTo: 'PENDING')
            .snapshots(),
        builder: (_, snap) {
          final count = snap.data?.docs.length ?? 0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: AppTheme.emergency, borderRadius: BorderRadius.circular(20)),
            child: Text('$count ${isMs ? 'KRITIKAL' : 'CRITICAL'}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
          );
        },
      ),
    ]),
  );

  Widget _buildFilterChips(bool isMs) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    color: Colors.white,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filters.map((f) {
          final active = _filter == f;
          final color = switch (f) {
            'PENDING'  => AppTheme.emergency,
            'ASSIGNED' => AppTheme.warning,
            'RESOLVED' => AppTheme.hope,
            _          => AppTheme.govBlue,
          };
          final localizedFilter = switch (f) {
            'ALL'      => isMs ? 'SEMUA'      : 'ALL',
            'PENDING'  => isMs ? 'TERTUNDA'   : 'PENDING',
            'ASSIGNED' => isMs ? 'DITUGASKAN' : 'ASSIGNED',
            'RESOLVED' => isMs ? 'SELESAI'    : 'RESOLVED',
            _          => f,
          };
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = f),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? color : color.withAlpha(15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withAlpha(active ? 255 : 80)),
                ),
                child: Text(localizedFilter,
                    style: TextStyle(color: active ? Colors.white : color, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ),
          );
        }).toList(),
      ),
    ),
  );

  Widget _buildList(bool isMs) {
    // No orderBy — avoids composite index requirement.
    // Sort client-side by created_at descending.
    Query query = FirebaseFirestore.instance.collection('incidents');
    if (_filter != 'ALL') {
      query = query.where('status', isEqualTo: _filter);
    } else {
      // For 'ALL', we still want to exclude 'CANCELLED' to keep the dashboard clean
      // and only show relevant operational data.
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = (snap.data?.docs ?? [])
            .where((d) => (d.data() as Map)['status'] != 'CANCELLED')
            .toList();
        docs.sort((a, b) {
          final aTs = (a.data() as Map)['created_at'] as Timestamp?;
          final bTs = (b.data() as Map)['created_at'] as Timestamp?;
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return bTs.compareTo(aTs);
        });
        if (docs.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.check_circle_outline, color: AppTheme.hope, size: 56),
              const SizedBox(height: 16),
              Text(
                isMs
                    ? 'Tiada kes SOS ${_filter == 'ALL' ? 'aktif' : _filter.toLowerCase()}'
                    : 'No ${_filter == 'ALL' ? 'active' : _filter.toLowerCase()} SOS cases',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.textSecondary),
              ),
              Text(
                isMs ? 'Semua jelas untuk penapis ini.' : 'All clear for this filter.',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ]),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) => _SOSTile(doc: docs[i], isMs: isMs),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _SOSTile extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final bool isMs;
  const _SOSTile({required this.doc, required this.isMs});

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    final status = d['status'] as String? ?? 'PENDING';

    final color = switch (status) {
      'PENDING'  => AppTheme.emergency,
      'ASSIGNED' => AppTheme.warning,
      'RESOLVED' => AppTheme.hope,
      _          => AppTheme.textSecondary,
    };
    final statusMap = {
      'PENDING':   isMs ? 'TERTUNDA'    : 'PENDING',
      'ASSIGNED':  isMs ? 'DITUGASKAN'  : 'ASSIGNED',
      'RESOLVED':  isMs ? 'SELESAI'     : 'RESOLVED',
      'CANCELLED': isMs ? 'DIBATALKAN'  : 'CANCELLED',
      'RESCUED':   isMs ? 'DISELAMATKAN': 'RESCUED',
    };

    // ── Field reads ──────────────────────────────────────────────────────────
    final name = d['contact_name'] as String?
        ?? d['sender_phone'] as String?
        ?? d['name'] as String?
        ?? (isMs ? 'Mangsa SOS' : 'SOS Victim');

    final headcount = (d['head_count'] as num?)?.toInt()
        ?? (d['headcount'] as num?)?.toInt()
        ?? 1;

    // Battery: only stored as real data when > 0.
    // The SOS app writes battery_level=0 as a placeholder — never show that.
    final batteryRaw = (d['battery_level'] as num?)?.toInt()
        ?? (d['battery'] as num?)?.toInt();
    final hasBattery = batteryRaw != null && batteryRaw > 0;
    final battery = batteryRaw ?? 0;

    // Phone: try every possible field name
    final phone = d['contact_phone'] as String?
        ?? d['sender_phone'] as String?
        ?? d['phone'] as String?
        ?? '';

    final address = d['address_text'] as String?
        ?? d['address'] as String?
        ?? '—';

    final description = d['description'] as String? ?? '';
    final situations  = (d['situations'] as List?)?.cast<String>() ?? [];
    final vulnerable  = (d['vulnerable'] as List?)?.cast<String>() ?? [];

    final lat = (d['lat'] as num?)?.toDouble();
    final lng = (d['lng'] as num?)?.toDouble();

    final createdAt = d['created_at'] as Timestamp?;
    final timeStr = createdAt != null
        ? '${createdAt.toDate().toLocal().hour.toString().padLeft(2, '0')}'
          ':${createdAt.toDate().toLocal().minute.toString().padLeft(2, '0')}'
        : '—:—';

    // Bilingual situation chip labels
    final sitLabels = <String, String>{
      'Trapped':           isMs ? 'Terperangkap'         : 'Trapped',
      'Medical Emergency': isMs ? 'Kecemasan Perubatan'  : 'Medical Emergency',
      'Infant/Elderly':    isMs ? 'Kanak-kanak/Warga Emas': 'Infant/Elderly',
      'Need Boat':         isMs ? 'Perlu Bot'             : 'Need Boat',
      'No Food/Water':     isMs ? 'Tiada Makanan/Air'     : 'No Food/Water',
      'Other':             isMs ? 'Lain-lain'             : 'Other',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 5, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // ── Status badge + ID + time ──────────────────────────────
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: color.withAlpha(20),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(statusMap[status] ?? status,
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              letterSpacing: 0.5)),
                    ),
                    const SizedBox(width: 8),
                    Text(doc.id.substring(0, 8).toUpperCase(),
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    const Spacer(),
                    Text(timeStr,
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 8),

                  // ── Name ─────────────────────────────────────────────────
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.black)),
                  const SizedBox(height: 4),

                  // ── Address ──────────────────────────────────────────────
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        size: 13, color: AppTheme.textMuted),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(address,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                  const SizedBox(height: 4),

                  // ── People count + battery only when real ─────────────────
                  Row(children: [
                    const Icon(Icons.people_outline,
                        size: 13, color: AppTheme.textMuted),
                    const SizedBox(width: 3),
                    Text(
                      isMs ? '$headcount mangsa' : '$headcount person(s)',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    if (hasBattery) ...[
                      const SizedBox(width: 12),
                      Icon(
                        battery < 20
                            ? Icons.battery_alert
                            : Icons.battery_std_outlined,
                        size: 13,
                        color: battery < 20
                            ? AppTheme.emergency
                            : AppTheme.textMuted,
                      ),
                      const SizedBox(width: 3),
                      Text('$battery%',
                          style: TextStyle(
                            color: battery < 20
                                ? AppTheme.emergency
                                : AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: battery < 20
                                ? FontWeight.w700
                                : null,
                          )),
                    ],
                  ]),

                  // ── Situation chips ───────────────────────────────────────
                  if (situations.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: situations.take(3).map((s) {
                        final label = sitLabels[s] ?? s;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.warningLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppTheme.warning.withAlpha(60)),
                          ),
                          child: Text(label,
                              style: const TextStyle(
                                  color: AppTheme.warning,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        );
                      }).toList(),
                    ),
                  ],

                  // ── Description snippet ───────────────────────────────────
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Row(children: [
                      const Icon(Icons.notes, size: 12, color: AppTheme.textMuted),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 11,
                              fontStyle: FontStyle.italic),
                        ),
                      ),
                    ]),
                  ],

                  const SizedBox(height: 12),

                  // ── Action buttons ────────────────────────────────────────
                  Row(children: [
                    if (status == 'PENDING') ...[
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.warning,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8)),
                          icon: const Icon(Icons.send, size: 14),
                          label: Text(isMs ? 'Hantar' : 'Dispatch',
                              style: const TextStyle(fontSize: 12)),
                          onPressed: () async {
                            final Map<String, String>? result = await showDialog(
                              context: context,
                              builder: (ctx) => _DispatchDialog(isMs: isMs),
                            );
                            if (result == null || result['volunteer_id']!.trim().isEmpty) return;

                            final incidentData = doc.data() as Map<String, dynamic>;
                            final sosIdField = incidentData['sos_id'] as String? ?? doc.id;

                            await FirebaseFirestore.instance
                                .collection('mission_offers')
                                .add({
                              ...result,
                              'sos_id': sosIdField,
                              'status': 'OFFERED',
                              'address': address,
                              'head_count': headcount,
                              'phone': phone,
                              'contact_name': name,
                              'description': description,
                              'situations': situations,
                              'vulnerable': vulnerable,
                              'sos_created_at': createdAt,
                              if (lat != null) 'lat': lat,
                              if (lng != null) 'lng': lng,
                              'distance_km': 2.1,
                              'created_at': FieldValue.serverTimestamp(),
                            });
                            await doc.reference
                                .update({'status': 'ASSIGNED'});
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isMs
                                      ? 'Misi dihantar ke ${result['volunteer_id']}!'
                                      : 'Mission dispatched to ${result['volunteer_id']}!'),
                                  backgroundColor: AppTheme.hope,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (status == 'ASSIGNED') ...[
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.hope,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8)),
                          icon: const Icon(Icons.check, size: 14),
                          label: Text(isMs ? 'Selesai' : 'Resolve',
                              style: const TextStyle(fontSize: 12)),
                          onPressed: () async {
                            await doc.reference.update({
                              'status': 'RESOLVED',
                              'resolved_at': FieldValue.serverTimestamp(),
                            });
                            await FirebaseFirestore.instance
                                .collection('activity_log')
                                .add({
                              'text':
                                  'SOS ${doc.id.substring(0, 8).toUpperCase()} resolved — $headcount victim(s)',
                              'icon': 'check_circle',
                              'type': 'RESOLVED',
                              'created_at': FieldValue.serverTimestamp(),
                            });
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isMs
                                      ? 'Kes berjaya diselesaikan.'
                                      : 'Case resolved successfully.'),
                                  backgroundColor: AppTheme.hope,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (phone.isNotEmpty)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.border),
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 12),
                        ),
                        icon: const Icon(Icons.phone_outlined,
                            size: 14, color: AppTheme.govBlue),
                        label: Text(isMs ? 'Panggil' : 'Call',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.govBlue)),
                        onPressed: () => launchUrl(Uri.parse('tel:$phone')),
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

// ── Dispatch Dialog ───────────────────────────────────────────────────────────
class _DispatchDialog extends StatefulWidget {
  final bool isMs;
  const _DispatchDialog({required this.isMs});
  @override
  State<_DispatchDialog> createState() => _DispatchDialogState();
}

class _DispatchDialogState extends State<_DispatchDialog> {
  final _vidCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _taskCtrl = TextEditingController();

  @override
  void dispose() {
    _vidCtrl.dispose();
    _titleCtrl.dispose();
    _taskCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isMs ? 'Agih Misi' : 'Distribute Mission',
          style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.govBlue)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _vidCtrl,
              decoration: InputDecoration(
                labelText: widget.isMs ? 'ID / Kod Sukarelawan' : 'Volunteer ID / Code',
                hintText: 'e.g. c01',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: widget.isMs ? 'Tajuk Misi' : 'Mission Title',
                hintText: widget.isMs ? 'Contoh: Pindah Mangsa' : 'e.g. Evacuate victims',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.campaign_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _taskCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: widget.isMs ? 'Arahan / Tugasan' : 'Task / Instructions',
                hintText: widget.isMs ? 'Tulis tugasan khusus di sini...' : 'Type specific task words here...',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.note_alt_outlined),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.isMs ? 'Batal' : 'Cancel', style: const TextStyle(color: AppTheme.textSecondary)),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, {
              'volunteer_id': _vidCtrl.text.trim(),
              'mission_title': _titleCtrl.text.trim().isEmpty 
                  ? (widget.isMs ? 'Misi Menyelamat' : 'Rescue Mission') 
                  : _titleCtrl.text.trim(),
              'mission_instruction': _taskCtrl.text.trim(),
            });
          },
          style: FilledButton.styleFrom(backgroundColor: AppTheme.warning),
          child: Text(widget.isMs ? 'Hantar' : 'Send'),
        ),
      ],
    );
  }
}
