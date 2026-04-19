import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/locale_provider.dart';

// ── Government Claims Audit Screen ────────────────────────────────────────────
// Officers can review, approve, or reject citizen damage claims
class GovClaimsScreen extends StatefulWidget {
  const GovClaimsScreen({super.key});
  @override
  State<GovClaimsScreen> createState() => _GovClaimsScreenState();
}

// No demo claims. We run strict production data directly from Firestore.

class _GovClaimsScreenState extends State<GovClaimsScreen> {
  String _filter = 'ALL';
  static const _filters = ['ALL', 'SUBMITTED', 'APPROVED', 'REJECTED'];

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
        decoration: BoxDecoration(color: const Color(0xFFA78BFA).withAlpha(30), borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.assignment_outlined, color: Color(0xFFA78BFA), size: 24),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isMs ? 'Audit Tuntutan Kerosakan' : 'Damage Claims Audit', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
          Text(isMs ? 'Menyemak, melulus atau menolak tuntutan' : 'Review, approve or reject citizen claims', style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ]),
      ),
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('damage_claims').where('status', isEqualTo: 'SUBMITTED').snapshots(),
        builder: (_, snap) {
          final count = snap.data?.docs.length ?? 0;
          if (count == 0) return const SizedBox();
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFA78BFA), borderRadius: BorderRadius.circular(20)),
            child: Text('$count ${isMs ? 'BAHARU' : 'NEW'}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
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
            'SUBMITTED' => const Color(0xFFA78BFA),
            'APPROVED'  => AppTheme.hope,
            'REJECTED'  => AppTheme.emergency,
            _           => AppTheme.govBlue,
          };
          final localizedName = switch (f) {
            'ALL' => isMs ? 'SEMUA' : 'ALL',
            'SUBMITTED' => isMs ? 'DIHANTAR' : 'SUBMITTED',
            'APPROVED' => isMs ? 'DILULUSKAN' : 'APPROVED',
            'REJECTED' => isMs ? 'DITOLAK' : 'REJECTED',
            _ => f,
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
                child: Text(localizedName, style: TextStyle(color: active ? Colors.white : color, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ),
          );
        }).toList(),
      ),
    ),
  );

  Widget _buildList(bool isMs) {
    // No orderBy — avoids Firestore composite index requirement.
    // Filter by status alone; sort client-side.
    Query query = FirebaseFirestore.instance.collection('damage_claims');
    if (_filter != 'ALL') query = query.where('status', isEqualTo: _filter);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Sort Firestore results client-side: newest first
        final liveDocs = [...(snap.data?.docs ?? [])];
        liveDocs.sort((a, b) {
          final aTs = (a.data() as Map)['created_at'] as Timestamp?;
          final bTs = (b.data() as Map)['created_at'] as Timestamp?;
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return bTs.compareTo(aTs);
        });

        if (liveDocs.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.inbox_outlined, color: AppTheme.textMuted, size: 56),
              const SizedBox(height: 16),
              Text(isMs ? 'Tiada tuntutan${_filter == 'ALL' ? '' : ' ${_filter.toLowerCase()}'} untuk disemak' : 'No${_filter == 'ALL' ? '' : ' ${_filter.toLowerCase()}'} claims to review',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.textSecondary)),
              Text(isMs ? 'Hantar tuntutan baharu dari antara muka rakyat.' : 'Submit a new claim from the citizen interface.', style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
            ]),
          );
        }

        // Build the list
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Live Firestore tiles
            ...liveDocs.map((doc) => _ClaimTile(doc: doc, isMs: isMs)),
          ],
        );
      },
    );
  }
}

// ── Live Firestore claim tile ─────────────────────────────────────────────────
class _ClaimTile extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final bool isMs;
  const _ClaimTile({required this.doc, required this.isMs});

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    final status = d['status'] as String? ?? 'SUBMITTED';
    final name = d['owner_name'] as String? ?? d['name'] as String? ?? 'Applicant';
    final total = (d['total_amount'] as num?)?.toDouble() ??
        (d['total_estimated_cost_myr'] as num?)?.toDouble() ?? 0.0;
    final items = (d['items'] as List?)?.length ?? (d['assessments'] as List?)?.length ?? 0;
    final depth = d['flood_depth'] as String? ?? '—';
    final createdAt = d['created_at'] as Timestamp?;
    final dateStr = createdAt != null
        ? '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}'
        : '—';

    final statusColor = _statusColor(status);

    return _ClaimCard(
      id: d['claim_id'] as String? ?? doc.id.substring(0, 8).toUpperCase(),
      ownerName: name,
      status: status,
      statusColor: statusColor,
      dateStr: dateStr,
      totalAmount: total,
      items: items,
      depth: depth,
      photosB64: (d['photos_b64'] as List?)?.cast<String>() ?? [],
      receiptsB64: (d['receipts_b64'] as List?)?.cast<String>() ?? [],
      description: d['losses_description'] as String?,
      rejectionReason: d['rejection_reason'] as String?,
      isMs: isMs,
      onApprove: status == 'SUBMITTED' ? () async {
        await doc.reference.update({'status': 'APPROVED', 'reviewed_at': FieldValue.serverTimestamp()});
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isMs ? 'Tuntutan diluluskan.' : 'Claim approved successfully.'), backgroundColor: AppTheme.hope));
        }
      } : null,
      onReject: status == 'SUBMITTED' ? () => _showRejectDialog(context, doc, isMs) : null,
    );
  }

  void _showRejectDialog(BuildContext context, QueryDocumentSnapshot doc, bool isMs) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isMs ? 'Sebab Penolakan' : 'Reason for Rejection', style: const TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: InputDecoration(
              hintText: isMs ? 'Nyatakan sebab penolakan...' : 'State the reason for rejection...', border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isMs ? 'Batal' : 'Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.emergency),
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await doc.reference.update({
                'status': 'REJECTED',
                'rejection_reason': ctrl.text.trim(),
                'reviewed_at': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(isMs ? 'Tuntutan ditolak.' : 'Claim rejected.'), backgroundColor: AppTheme.emergency));
              }
            },
            child: Text(isMs ? 'Hantar Penolakan' : 'Submit Rejection'),
          ),
        ],
      ),
    );
  }
}

// ── Shared card widget used by both live & demo tiles ────────────────────────
class _ClaimCard extends StatelessWidget {
  final String id, ownerName, status, dateStr, depth;
  final Color statusColor;
  final double totalAmount;
  final int items;
  final List<String> photosB64;
  final List<String> receiptsB64;
  final String? description;
  final String? rejectionReason;
  final bool isMs;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _ClaimCard({
    required this.id, required this.ownerName, required this.status,
    required this.statusColor, required this.dateStr, required this.totalAmount,
    required this.items, required this.depth,
    required this.isMs,
    this.photosB64 = const [], this.receiptsB64 = const [], this.description,
    this.rejectionReason, this.onApprove, this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withAlpha(50)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header row ────────────────────────────────────────────────────────
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ownerName,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.black)),
            const SizedBox(height: 2),
            Text(id,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontFamily: 'monospace')),
          ])),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: statusColor.withAlpha(20), borderRadius: BorderRadius.circular(6)),
            child: Text(status, style: TextStyle(
                color: statusColor, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.5)),
          ),
        ]),
        const SizedBox(height: 10),

        // ── Details row ───────────────────────────────────────────────────────
        Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 13, color: AppTheme.textMuted),
          const SizedBox(width: 4),
          Text(dateStr, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(width: 14),
          const Icon(Icons.water_outlined, size: 13, color: AppTheme.textMuted),
          const SizedBox(width: 4),
          Text(depth, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const Spacer(),
          Text('RM ${totalAmount.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.govBlue)),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.list_alt_outlined, size: 13, color: AppTheme.textMuted),
          const SizedBox(width: 4),
          Text(isMs ? '$items barang rosak' : '$items damaged item(s)', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ]),

        // ── View Evidence Button ──────────────────────────────────────────────
        if (photosB64.isNotEmpty || receiptsB64.isNotEmpty || (description != null && description!.isNotEmpty)) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showEvidenceSheet(context, isMs),
              icon: const Icon(Icons.photo_library_outlined, size: 16),
              label: Text(isMs ? 'Lihat Bukti Sakongan' : 'View Supporting Evidence', style: const TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],

        // ── Rejection reason ──────────────────────────────────────────────────
        if (rejectionReason != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppTheme.emergencyLight, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 14, color: AppTheme.emergency),
              const SizedBox(width: 6),
              Expanded(child: Text(isMs ? 'Sebab: $rejectionReason' : 'Reason: $rejectionReason',
                  style: const TextStyle(color: AppTheme.emergency, fontSize: 12))),
            ]),
          ),
        ],

        // ── Action buttons (only for SUBMITTED) ───────────────────────────────
        if (status == 'SUBMITTED' && (onApprove != null || onReject != null)) ...[
          const SizedBox(height: 12),
          Row(children: [
            if (onApprove != null)
              Expanded(child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.hope, padding: const EdgeInsets.symmetric(vertical: 8)),
                icon: const Icon(Icons.check, size: 16),
                label: Text(isMs ? 'Lulus' : 'Approve', style: const TextStyle(fontSize: 12)),
                onPressed: onApprove,
              )),
            if (onApprove != null && onReject != null) const SizedBox(width: 8),
            if (onReject != null)
              Expanded(child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.emergency,
                  side: BorderSide(color: AppTheme.emergency.withAlpha(150)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                icon: const Icon(Icons.close, size: 16),
                label: Text(isMs ? 'Tolak' : 'Reject', style: const TextStyle(fontSize: 12)),
                onPressed: onReject,
              )),
          ]),
        ],

        // ── Approved/Rejected final state badge ───────────────────────────────
        if (status == 'APPROVED') ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppTheme.hopeLight, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.check_circle_outline, size: 14, color: AppTheme.hope),
              const SizedBox(width: 6),
              Expanded(child: Text(isMs ? 'Tuntutan diluluskan — dana akan dikreditkan dalam masa 7–14 hari bekerja.' : 'Claim approved — funds will be credited within 7–14 working days.',
                  style: const TextStyle(color: AppTheme.hope, fontSize: 12))),
            ]),
          ),
        ],
      ]),
    );
  }

  void _showEvidenceSheet(BuildContext context, bool isMs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95,
        expand: false,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          children: [
            Row(children: [
              const Icon(Icons.inventory_outlined, color: AppTheme.govBlue),
              const SizedBox(width: 10),
              Text(isMs ? 'Bukti Sokongan' : 'Supporting Evidence', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ]),
            const SizedBox(height: 16),
            if (description != null && description!.isNotEmpty) ...[
              Text(isMs ? 'Penerangan Kerosakan:' : 'Damage Description:', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8)),
                child: Text(description!, style: const TextStyle(fontSize: 14)),
              ),
              const SizedBox(height: 16),
            ],
            if (photosB64.isNotEmpty) ...[
              Text(isMs ? 'Foto Kerosakan:' : 'Damage Photos:', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              ...photosB64.map((b64) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(base64Decode(b64), fit: BoxFit.cover),
                ),
              )),
              const SizedBox(height: 8),
            ],
            if (receiptsB64.isNotEmpty) ...[
              Text(isMs ? 'Resit Pembelian:' : 'Purchase Receipts:', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              ...receiptsB64.map((b64) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(base64Decode(b64), fit: BoxFit.cover),
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }
}

Color _statusColor(String status) => switch (status) {
  'APPROVED' => AppTheme.hope,
  'REJECTED' => AppTheme.emergency,
  _          => const Color(0xFFA78BFA),
};
