import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';

import 'package:provider/provider.dart';
import '../../../core/providers/locale_provider.dart';

// ── Government Command Centre Home Screen ─────────────────────────────────────
// Audience: Government/NADMA officers
// Design language: Authoritative, dense data, dark navy accent, tactical.
// This screen should feel like an incident command dashboard, not a consumer app.

class GovHomeScreen extends StatelessWidget {
  const GovHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isMs = context.watch<LocaleProvider>().locale.languageCode == 'ms';
    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildCommandHeader(context, isMs),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              _buildRiverGaugeTicker(isMs),
              const SizedBox(height: 16),
              _buildKPIGrid(isMs),
              const SizedBox(height: 20),
              _buildSOSQueue(isMs),
              const SizedBox(height: 20),
              _buildAiSitrep(context, isMs),
              const SizedBox(height: 20),
              _buildSupplyBars(context, isMs),
              const SizedBox(height: 20),
              _buildOperationsLog(isMs),
              const SizedBox(height: 20),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Dark navy command-centre header card ──────────────────────────────────
  Widget _buildCommandHeader(BuildContext context, bool isMs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F2044), Color(0xFF1E3A5F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Phase badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.emergency.withAlpha(200),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.circle, color: Colors.white, size: 8),
            const SizedBox(width: 6),
            Text(isMs ? 'FASA 1 — BANJIR AKTIF' : 'PHASE 1 — ACTIVE FLOOD',
                style: const TextStyle(color: Colors.white, fontSize: 10,
                    fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ]),
        ),
        const SizedBox(height: 14),
        Text(isMs ? 'Pusat Kawalan Operasi' : 'Command Operations Centre',
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 2),
        Text(isMs ? 'Daerah Klang, Selangor' : 'Klang District, Selangor',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800,
                fontSize: 22)),
        const SizedBox(height: 16),
        // Action buttons row
        Row(children: [
          Expanded(child: _CommandActionButton(
            icon: Icons.announcement_outlined,
            label: isMs ? 'Siaran' : 'Announce',
            color: const Color(0xFF60A5FA), // Soft Blue
            onTap: () => _showAnnounceModal(context, isMs),
          )),
          const SizedBox(width: 8),
          Expanded(child: _CommandActionButton(
            icon: Icons.people_alt_outlined,
            label: isMs ? 'Hantar' : 'Dispatch',
            color: const Color(0xFFFBBF24), // Soft Amber
            onTap: () => _showDispatchModal(context, isMs),
          )),
          const SizedBox(width: 8),
          Expanded(child: _CommandActionButton(
            icon: Icons.warehouse_outlined,
            label: isMs ? 'Bekalan' : 'Supply',
            color: const Color(0xFF34D399), // Soft Emerald
            onTap: () => _showSupplyModal(context, isMs),
          )),
          const SizedBox(width: 8),
          Expanded(child: _CommandActionButton(
            icon: Icons.file_download_outlined,
            label: isMs ? 'Laporan' : 'Report',
            color: const Color(0xFFA78BFA), // Soft Purple
            onTap: () => _showReportModal(context, isMs),
          )),
        ]),
      ]),
    );
  }

  // ── Modals ────────────────────────────────────────────────────────────────
  void _showAnnounceModal(BuildContext context, bool isMs) {
    final ctrl = TextEditingController();
    bool sending = false;
    String selectedTarget = 'all'; // 'all', 'volunteer', 'citizen'
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setB) => Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(isMs ? 'Siaran Awam' : 'Public Announce', style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 16)),
            ]),
            const SizedBox(height: 16),
            // ── Audience selector ────────────────────────────────────────
            Text(isMs ? 'Hantar kepada:' : 'Send to:', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _AudienceChip(label: isMs ? 'Semua Pengguna' : 'All Users', value: 'all', selected: selectedTarget, onTap: () => setB(() => selectedTarget = 'all')),
              _AudienceChip(label: isMs ? 'Sukarelawan' : 'Volunteers', value: 'volunteer', selected: selectedTarget, onTap: () => setB(() => selectedTarget = 'volunteer')),
              _AudienceChip(label: isMs ? 'Warganegara' : 'Citizens', value: 'citizen', selected: selectedTarget, onTap: () => setB(() => selectedTarget = 'citizen')),
            ]),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: isMs ? 'Taip mesej siaran anda di sini...' : 'Type your broadcast message here...',
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                filled: true, fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: AppTheme.govBlue, width: 2)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: sending ? null : () async {
                  if (ctrl.text.trim().isEmpty) return;
                  setB(() => sending = true);
                  try {
                    await FirebaseFirestore.instance.collection('notifications').add({
                      'title': isMs ? 'Peringatan PKB' : 'Command Alert',
                      'message': ctrl.text.trim(),
                      'type': 'alert',
                      'target': selectedTarget, // 'all', 'volunteer', or 'citizen'
                      'created_at': FieldValue.serverTimestamp(),
                    });
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      final label = selectedTarget == 'all'
                          ? (isMs ? 'semua pengguna' : 'all users')
                          : selectedTarget == 'volunteer'
                              ? (isMs ? 'sukarelawan' : 'volunteers')
                              : (isMs ? 'warganegara' : 'citizens');
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(isMs ? 'Siaran dihantar kepada $label!' : 'Broadcast sent to $label!'),
                          backgroundColor: AppTheme.hope));
                    }
                  } finally {
                    if (ctx.mounted) setB(() => sending = false);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.govBlue, foregroundColor: Colors.white),
                child: sending 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(isMs ? 'Hantar Siaran' : 'Send Broadcast', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showDispatchModal(BuildContext context, bool isMs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setB) {
          // Track per-doc state: 'idle' | 'loading' | 'done'
          final Map<String, String> itemState = {};

          return Padding(
            padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.people_alt, color: AppTheme.warning, size: 48),
              const SizedBox(height: 16),
              Text(isMs ? 'Padanan AI Sukarelawan' : 'AI Dispatch Match', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 8),
              Text(isMs ? 'Menugaskan sukarelawan berdekatan untuk kes SOS yang sedang menunggu.' : 'Assigning nearby volunteers to pending SOS cases.', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary, height: 1.5)),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('incidents')
                      .where('status', whereIn: ['PENDING', 'ASSIGNED']).snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data?.docs ?? [];
                    final pending = docs.where((d) {
                      final s = (d.data() as Map<String, dynamic>)['status'] as String? ?? '';
                      return s == 'PENDING' || itemState[d.id] == 'done';
                    }).toList();

                    if (pending.isEmpty) {
                      return Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.check_circle_outline, color: AppTheme.hope, size: 48),
                          const SizedBox(height: 12),
                          Text(isMs ? 'Semua kes SOS telah dihantar!' : 'All SOS cases dispatched!',
                              style: const TextStyle(color: AppTheme.hope, fontWeight: FontWeight.w600)),
                        ]),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final doc = docs[i];
                        final d = doc.data() as Map<String, dynamic>;
                        final docStatus = d['status'] as String? ?? 'PENDING';
                        final pax = (d['head_count'] as num?)?.toInt() ?? (d['headcount'] as num?)?.toInt() ?? 1;
                        final batt = (d['battery_level'] as num?)?.toInt() ?? (d['battery'] as num?)?.toInt() ?? 0;
                        final name = d['contact_name']?.toString() ?? d['name']?.toString() ?? (isMs ? 'Bantuan SOS' : 'SOS Assistance');
                        final address = d['address_text']?.toString() ?? d['address']?.toString() ?? name;
                        final state = itemState[doc.id] ?? (docStatus == 'ASSIGNED' ? 'done' : 'idle');
                        final isDone = state == 'done';
                        final isLoading = state == 'loading';

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          color: isDone ? AppTheme.hopeLight.withAlpha(80) : Colors.transparent,
                          child: Row(children: [
                            CircleAvatar(
                              backgroundColor: isDone ? AppTheme.hopeLight : AppTheme.emergencyLight,
                              child: Icon(isDone ? Icons.check : Icons.sos,
                                  color: isDone ? AppTheme.hope : AppTheme.emergency, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(name, style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13,
                                  color: isDone ? AppTheme.textMuted : Colors.black,
                                  decoration: isDone ? TextDecoration.lineThrough : null)),
                              Text(isMs ? 'Mangsa: $pax • Bateri: $batt%' : 'Victims: $pax • Battery: $batt%',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                              if (isDone)
                                Text(isMs ? '✓ Sukarelawan dihantar' : '✓ Volunteer dispatched',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.hope, fontWeight: FontWeight.w600)),
                            ])),
                            const SizedBox(width: 8),
                            isDone
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.hope,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.check, color: Colors.white, size: 16),
                                )
                              : FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: isLoading ? AppTheme.textMuted : AppTheme.warning,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  icon: isLoading
                                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.send, size: 13),
                                  label: Text(isMs ? 'Hantar' : 'Send', style: const TextStyle(fontSize: 12)),
                                  onPressed: isLoading ? null : () async {
                                    setB(() => itemState[doc.id] = 'loading');
                                    try {
                                      await FirebaseFirestore.instance.collection('mission_offers').add({
                                        'volunteer_id': 'c01',
                                        'sos_id': doc.id,
                                        'status': 'OFFERED',
                                        'address': address,
                                        'head_count': pax,
                                        'distance_km': 1.2,
                                        'created_at': FieldValue.serverTimestamp(),
                                      });
                                      await FirebaseFirestore.instance.collection('incidents').doc(doc.id).update({'status': 'ASSIGNED'});
                                      setB(() => itemState[doc.id] = 'done');
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                            content: Text(isMs ? '✓ Misi diajukan kepada sukarelawan!' : '✓ Mission dispatched to volunteer!'),
                                            backgroundColor: AppTheme.hope,
                                            duration: const Duration(seconds: 2)));
                                      }
                                    } catch (e) {
                                      setB(() => itemState[doc.id] = 'idle');
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                            content: Text('Error: $e'), backgroundColor: AppTheme.emergency));
                                      }
                                    }
                                  },
                                ),
                          ]),
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(isMs ? 'Tutup' : 'Close', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  void _showSupplyModal(BuildContext context, bool isMs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.warehouse, color: AppTheme.hope, size: 48),
          const SizedBox(height: 16),
          Text(isMs ? 'Pengurusan Bekalan' : 'Supply Management', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 8),
          Text(isMs ? 'Adakah anda ingin merekod penerimaan bekalan baru (Restock) untuk depoh JKM di kawasan ini?' : 'Do you want to log new incoming supplies (Restock) for the JKM depot in this area?',
              textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary, height: 1.5)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                // Instantly restock the digital inventory
                await FirebaseFirestore.instance.collection('supplies').doc('warehouse').set({
                  'food': 1.0,
                  'water': 1.0,
                  'meds': 0.9,
                  'power': 0.6,
                  'baby': 0.8,
                });
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(isMs ? 'Inventori depoh dikemas kini (Restocked)!' : 'Depot inventory updated (Restocked)!'), backgroundColor: AppTheme.hope));
                }
              },
              icon: const Icon(Icons.add_shopping_cart, size: 18),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.hope),
              label: Text(isMs ? 'Restock Gudang' : 'Restock Warehouse', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isMs ? 'Batal' : 'Cancel', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          )
        ]),
      ),
    );
  }

  void _showReportModal(BuildContext context, bool isMs) {
    bool generating = false;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setB) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.picture_as_pdf, color: Color(0xFFA78BFA), size: 48),
            const SizedBox(height: 16),
            Text(isMs ? 'Jana Laporan SITREP' : 'Generate SITREP Report', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 8),
            Text(isMs ? 'Sistem akan menjana laporan komprehensif operasi bencana secara PDF untuk perkongsian NADMA dan JKM.' : 'The system will generate a comprehensive disaster operations report in PDF format for sharing with NADMA and JKM.',
                textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary, height: 1.5)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: generating ? null : () async {
                  setB(() => generating = true);
                  try {
                    await _generateAndSharePDF(isMs);
                    if (ctx.mounted) Navigator.pop(ctx);
                  } finally {
                    if (ctx.mounted) setB(() => generating = false);
                  }
                },
                icon: generating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.download, size: 18),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFA78BFA)),
                label: Text(generating ? (isMs ? 'Menjana PDF...' : 'Generating PDF...') : (isMs ? 'Jana PDF & Kongsi' : 'Generate & Share PDF'), style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(isMs ? 'Tutup' : 'Close', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
              ),
            )
          ]),
        ),
      ),
    );
  }

  Future<void> _generateAndSharePDF(bool isMs) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(isMs ? 'LAPORAN OPERASI BENCANA - FLOODSENSE' : 'DISASTER OPERATIONS REPORT - FLOODSENSE', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text('${isMs ? "Tarikh Janaan" : "Generated Date"}: ${DateTime.now().toLocal().toString().split('.')[0]}'),
              pw.Text(isMs ? 'Kawasan Operasi: Daerah Klang, Selangor' : 'Operations Area: Klang District, Selangor'),
              pw.Text(isMs ? 'Tahap Kecemasan: Fasa 1 - Banjir Aktif' : 'Emergency Level: Phase 1 - Active Flood', style: const pw.TextStyle(color: PdfColors.red700)),
              pw.SizedBox(height: 20),
              pw.Text(isMs ? '1. PARAS SUNGAI TERKINI:' : '1. LIVE RIVER GAUGES:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(isMs ? '  * Sg. Klang: 4.2m (BAHAYA)' : '  * Sg. Klang: 4.2m (DANGER)'),
              pw.Text(isMs ? '  * Sg. Gombak: 3.8m (AMARAN)' : '  * Sg. Gombak: 3.8m (WARNING)'),
              pw.SizedBox(height: 10),
              pw.Text(isMs ? '2. STATUS BEKALAN LOGISTIK JKM:' : '2. JKM LOGISTICS SUPPLY STATUS:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(isMs ? '  * Pek Makanan: 72%' : '  * Food Packs: 72%'),
              pw.Text(isMs ? '  * Air Bersih: 88%' : '  * Clean Water: 88%'),
              pw.Text(isMs ? '  * Susu Bayi: 61%' : '  * Baby Formula: 61%'),
              pw.SizedBox(height: 10),
              pw.Text(isMs ? '3. STATUS TINDAK BALAS SUKARELAWAN:' : '3. VOLUNTEER RESPONSE STATUS:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(isMs ? '  * Unit Sukarelawan Bertugas: 7 unit' : '  * Active Volunteer Units: 7 units'),
              pw.Text(isMs ? '  * Misi Diselesaikan Bantuan: 24 kes' : '  * Resolved Assistance Missions: 24 cases'),
              pw.SizedBox(height: 30),
              pw.Text(isMs ? 'Diakui Sah oleh,' : 'Verified by,'),
              pw.SizedBox(height: 30),
              pw.Text('......................................................'),
              pw.Text(isMs ? 'Pusat Komander Insiden NADMA' : 'NADMA Incident Commander Centre'),
            ],
          );
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/SITREP_Klang_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());

    // ignore: deprecated_member_use
    await Share.shareXFiles(
      [XFile(file.path)],
      text: isMs ? 'FloodSense: Laporan Operasi Bencana (Ketua Pengarah NADMA)' : 'FloodSense: Disaster Operations Report (NADMA Commander)',
    );
  }

  // ── River gauge horizontal scrolling ticker ───────────────────────────────
  Widget _buildRiverGaugeTicker(bool isMs) {
    const gauges = [
      _GaugeData('Sg. Klang', 4.2, 4.0, 'BAHAYA'),
      _GaugeData('Sg. Rasau', 2.1, 3.5, 'NORMAL'),
      _GaugeData('Sg. Gombak', 3.8, 4.0, 'AMARAN'),
      _GaugeData('Sg. Kerayong', 1.9, 3.0, 'NORMAL'),
      _GaugeData('Sg. Batu', 3.1, 3.5, 'AMARAN'),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(isMs ? 'PARAS SUNGAI LANGSUNG' : 'LIVE RIVER GAUGES',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11,
              letterSpacing: 1.2, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      SizedBox(
        height: 100,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: gauges.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) => _GaugeTile(g: gauges[i], isMs: isMs),
        ),
      ),
    ]);
  }

  // ── KPI Grid (Live Firestore) ──────────────────────────────────────────────
  Widget _buildKPIGrid(bool isMs) {
    return Row(children: [
      Expanded(child: _LiveKPI(
        stream: FirebaseFirestore.instance.collection('incidents').where('status', isEqualTo: 'PENDING').snapshots(),
        label: isMs ? 'SOS Aktif' : 'Active SOS', sublabel: isMs ? 'Menunggu' : 'Pending', icon: Icons.sos, color: AppTheme.emergency,
      )),
      const SizedBox(width: 10),
      Expanded(child: _LiveKPI(
        stream: FirebaseFirestore.instance.collection('mission_offers').where('status', isEqualTo: 'OFFERED').snapshots(),
        label: isMs ? 'Dihantar' : 'Dispatched', sublabel: isMs ? 'Sukarelawan' : 'Volunteers', icon: Icons.directions_run, color: AppTheme.warning,
      )),
      const SizedBox(width: 10),
      Expanded(child: _LiveKPI(
        stream: FirebaseFirestore.instance.collection('incidents').where('status', isEqualTo: 'RESOLVED').snapshots(),
        label: isMs ? 'Selesai' : 'Resolved', sublabel: isMs ? 'Kes' : 'Cases', icon: Icons.check_circle_outline, color: AppTheme.hope,
      )),
      const SizedBox(width: 10),
      Expanded(child: _LiveKPI(
        stream: FirebaseFirestore.instance.collection('pps_registrations').snapshots(),
        label: isMs ? 'Di PPS' : 'In Shelters', sublabel: isMs ? 'Mangsa' : 'Victims', icon: Icons.people_outline, color: AppTheme.govBlue,
      )),
    ]);
  }

  // ── SOS Queue (Live Firestore) ─────────────────────────────────────────────
  Widget _buildSOSQueue(bool isMs) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('incidents')
          .where('status', isEqualTo: 'PENDING')
          .snapshots(),
      builder: (context, snap) {
        var docs = snap.data?.docs ?? [];
        // Client-side sort to avoid missing composite index
        docs = docs.toList();
        docs.sort((a, b) {
          final aTs = (a.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
          final bTs = (b.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return bTs.compareTo(aTs);
        });
        if (docs.length > 3) docs = docs.take(3).toList();
        
        return Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(children: [
                const Icon(Icons.warning_amber_outlined, color: AppTheme.emergency, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(isMs ? 'SOS Aktif' : 'Active SOS Queue',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.black))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppTheme.emergencyLight, borderRadius: BorderRadius.circular(20)),
                  child: Text(isMs ? 'AKTIF' : 'ACTIVE',
                      style: const TextStyle(color: AppTheme.emergency, fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 0.5)),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            if (docs.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(isMs ? 'Tiada SOS aktif sekarang.' : 'No active SOS currently.', style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
              )
            else
              for (final doc in docs) Builder(builder: (ctx) {
                final d = doc.data() as Map<String, dynamic>;
                final status = d['status'] as String? ?? 'PENDING';
                final color = status == 'PENDING' ? AppTheme.emergency : AppTheme.warning;
                final urgency = status == 'PENDING' ? (isMs ? 'KRITIKAL' : 'CRITICAL') : (isMs ? 'DIHANTAR' : 'DISPATCHED');
                final name = d['contact_name'] as String? ?? (isMs ? 'Mangsa SOS' : 'SOS Victim');
                final pax = d['headcount'] as int? ?? 1;
                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withAlpha(8),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withAlpha(40)),
                  ),
                  child: Row(children: [
                    Icon(status == 'PENDING' ? Icons.sos : Icons.directions_run, color: color, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.black)),
                      Text(isMs ? '$pax orang' : '$pax pax', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(6)),
                      child: Text(urgency, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 10)),
                    ),
                  ]),
                );
              }),
            const SizedBox(height: 4),
          ]),
        );
      },
    );
  }

  // ── AI Sitrep ─────────────────────────────────────────────────────────────
  Widget _buildAiSitrep(BuildContext context, bool isMs) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.govBlue.withAlpha(60)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.smart_toy_outlined, color: AppTheme.govBlue, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(isMs ? 'AI Laporan Situasi' : 'AI Situation Report',
                style: const TextStyle(fontWeight: FontWeight.w700,
                    fontSize: 15, color: AppTheme.govBlue)),
          ),
          const Text('Gemini 2.5', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ]),
        const SizedBox(height: 4),
        Text(isMs ? 'Dijana automatik' : 'Auto-generated',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        const SizedBox(height: 12),
        Text(
          isMs
          ? 'STATUS: FASA 1 — Kejadian banjir aktif di daerah Klang.\n\n3 kes SOS kritikal menunggu operasi penyelamatan. 7 sukarelawan telah dihantar. Tolok sungai Sg. Klang pada 4.2m (had bahaya: 4.0m). Cadangan: aktifkan 2 unit bot tambahan dari depot Bukit Rajah. PPS Stadium Shah Alam — kapasiti 36%, sesuai sebagai overflow.'
          : 'STATUS: PHASE 1 — Active flooding in Klang district.\n\n3 critical SOS cases pending rescue. 7 volunteers dispatched. Sg. Klang river gauge at 4.2m (danger limit: 4.0m). Recommendation: activate 2 extra boat units from Bukit Rajah depot. Stadium Shah Alam shelter — 36% capacity, suitable for overflow.',
          style: const TextStyle(color: Colors.black, fontSize: 13, height: 1.6),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            flex: 3,
            child: FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isMs ? 'Laporan situasi telah disahkan dan disebarkan.' : 'Situation report has been approved and disseminated.')));
              },
              icon: const Icon(Icons.check, size: 16),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(isMs ? 'Luluskan & Sebarkan' : 'Approve & Disseminate'),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.govBlue,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isMs ? 'Menjana semula laporan...' : 'Regenerating report...')));
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(isMs ? 'Jana Semula' : 'Regenerate'),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  // ── Supply Bars ───────────────────────────────────────────────────────────
  Widget _buildSupplyBars(BuildContext context, bool isMs) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('supplies').doc('warehouse').snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data() as Map<String, dynamic>? ?? {};
        final supplies = [
          _Supply(label: isMs ? 'Pek Makanan' : 'Food Packs', pct: (d['food'] as num?)?.toDouble() ?? 0.72, color: AppTheme.hope),
          _Supply(label: isMs ? 'Air Bersih' : 'Clean Water', pct: (d['water'] as num?)?.toDouble() ?? 0.88, color: AppTheme.govBlue),
          _Supply(label: isMs ? 'Kit Perubatan' : 'Medical Kits', pct: (d['meds'] as num?)?.toDouble() ?? 0.45, color: AppTheme.warning),
          _Supply(label: 'Power Bank', pct: (d['power'] as num?)?.toDouble() ?? 0.30, color: AppTheme.emergency),
          _Supply(label: isMs ? 'Susu Bayi' : 'Baby Formula', pct: (d['baby'] as num?)?.toDouble() ?? 0.61, color: AppTheme.hope),
        ];

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.inventory_2_outlined, color: AppTheme.govBlue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(isMs ? 'Inventori Gudang' : 'Warehouse Inventory',
                    style: const TextStyle(fontWeight: FontWeight.w700,
                        fontSize: 15, color: Colors.black)),
              ),
              TextButton.icon(
                onPressed: () => _showSupplyModal(context, isMs),
                icon: const Icon(Icons.sync, size: 14),
                label: Text(isMs ? 'Sedia' : 'Ready', style: const TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: AppTheme.govBlue),
              ),
            ]),
            const SizedBox(height: 16),
            ...supplies.map((s) => _SupplyBar(s: s)),
          ]),
        );
      }
    );
  }

  // ── Operations Log (Live Firestore) ──────────────────────────────────────
  Widget _buildOperationsLog(bool isMs) {
    final staticLogs = [
      _LogEntry(time: '10:22', icon: Icons.check_circle_outline, text: isMs ? 'SOS diselesaikan — 3 mangsa ke PPS Shah Alam' : 'SOS resolved — 3 victims to Shah Alam shelter', color: AppTheme.hope),
      _LogEntry(time: '10:05', icon: Icons.directions_run, text: isMs ? 'Sukarelawan Khairul dihantar ke SOS kritikal' : 'Volunteer Khairul dispatched to critical SOS', color: AppTheme.warning),
      _LogEntry(time: '09:48', icon: Icons.inventory_2_outlined, text: isMs ? '200 pek makanan ke PPS Klang' : '200 food packs sent to Klang shelter', color: AppTheme.govBlue),
      _LogEntry(time: '09:15', icon: Icons.announcement_outlined, text: isMs ? 'Siaran awam: Kawasan banjir Kg. Jawa' : 'Public broadcast: Flood area Kg. Jawa', color: AppTheme.textSecondary),
    ];

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('activity_log').orderBy('created_at', descending: true).limit(8).snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.history, color: AppTheme.govBlue, size: 20),
              const SizedBox(width: 8),
              Text(isMs ? 'Log Operasi' : 'Operations Log',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.black)),
            ]),
            const SizedBox(height: 16),
            if (docs.isEmpty)
              ...staticLogs.map((l) => _LogTile(l: l))
            else
              for (final doc in docs) Builder(builder: (ctx) {
                final d = doc.data() as Map<String, dynamic>;
                final ts = d['created_at'] as Timestamp?;
                final dt = ts?.toDate().toLocal();
                final time = dt != null
                    ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
                    : '--:--';
                final type = d['type'] as String? ?? 'LOG';
                final icon = type == 'RESOLVED' ? Icons.check_circle_outline
                    : type == 'SUPPLY' ? Icons.inventory_2_outlined
                    : type == 'DISPATCH' ? Icons.directions_run
                    : Icons.info_outline;
                final color = type == 'RESOLVED' ? AppTheme.hope
                    : type == 'SUPPLY' ? AppTheme.govBlue
                    : type == 'DISPATCH' ? AppTheme.warning
                    : AppTheme.textSecondary;
                final rawText = d['text'] as String? ?? '';
                String localizedText = rawText;
                if (isMs) {
                  localizedText = localizedText
                    .replaceAll('resolved —', 'telah diselesaikan —')
                    .replaceAll('victim(s)', 'mangsa')
                    .replaceAll('Volunteer', 'Sukarelawan')
                    .replaceAll('dispatched to critical SOS', 'dihantar ke SOS kritikal')
                    .replaceAll('food packs sent to Klang shelter', 'pek makanan dihantar ke PPS Klang')
                    .replaceAll('Public broadcast: Flood area Kg. Jawa', 'Siaran awam: Kawasan banjir Kg. Jawa')
                    .replaceAll('JKM depot restocked by Command Director', 'Restock bekalan depoh JKM dilakukan oleh Pengarah PKB');
                } else {
                  localizedText = localizedText
                    .replaceAll('Restock bekalan depoh JKM dilakukan oleh Pengarah PKB', 'JKM depot restocked by Command Director')
                    .replaceAll('telah diselesaikan —', 'resolved —')
                    .replaceAll('mangsa', 'victim(s)')
                    .replaceAll('Sukarelawan', 'Volunteer')
                    .replaceAll('dihantar ke SOS kritikal', 'dispatched to critical SOS');
                }

                return _LogTile(l: _LogEntry(time: time, icon: icon, text: localizedText, color: color));
              }),
          ]),
        );
      },
    );
  }



}
class _LiveKPI extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final String label, sublabel;
  final IconData icon;
  final Color color;
  const _LiveKPI({required this.stream, required this.label, required this.sublabel, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot>(
    stream: stream,
    builder: (_, snap) {
      final count = snap.data?.docs.length ?? 0;
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text('$count',
                style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 24)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(label,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(sublabel,
                  style: TextStyle(color: color.withAlpha(180), fontSize: 10)),
            ),
          ],
        ),
      );
    },
  );
}

class _LogTile extends StatelessWidget {
  final _LogEntry l;
  const _LogTile({required this.l});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
              color: l.color.withAlpha(15), borderRadius: BorderRadius.circular(8)),
          child: Icon(l.icon, color: l.color, size: 16),
        ),
        if (l != const Object()) ...[],
      ]),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.time,
            style: const TextStyle(color: AppTheme.textMuted,
                fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(l.text,
            style: const TextStyle(color: Colors.black, fontSize: 13, height: 1.4)),
      ])),
    ]),
  );
}


// ─── Data Holders ──────────────────────────────────────────────────────────────

class _GaugeData {
  final String river, status;
  final double level, threshold;
  const _GaugeData(this.river, this.level, this.threshold, this.status);
}

class _Supply {
  final String label;
  final double pct;
  final Color color;
  const _Supply({required this.label, required this.pct, required this.color});
}

class _LogEntry {
  final String time, text;
  final IconData icon;
  final Color color;
  const _LogEntry({required this.time, required this.icon, required this.text, required this.color});
}

// ─── Additional Widget Classes ─────────────────────────────────────────────────

class _CommandActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _CommandActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(25)),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withAlpha(30), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 10),
        Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 10, height: 1.2)),
      ]),
    ),
  );
}

class _GaugeTile extends StatelessWidget {
  final _GaugeData g;
  final bool isMs;
  const _GaugeTile({required this.g, required this.isMs});

  @override
  Widget build(BuildContext context) {
    final isBahaya = g.status == 'BAHAYA';
    final isAmaran = g.status == 'AMARAN';
    final color = isBahaya ? AppTheme.emergency : isAmaran ? AppTheme.warning : AppTheme.hope;

    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(g.river, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 12)),
        const SizedBox(height: 4),
        Text('${g.level}m', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(6)),
          child: Text(
            isMs ? g.status : (g.status == 'BAHAYA' ? 'DANGER' : (g.status == 'AMARAN' ? 'WARNING' : 'NORMAL')),
            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ),
      ]),
    );
  }
}

class _SupplyBar extends StatelessWidget {
  final _Supply s;
  const _SupplyBar({required this.s});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(s.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black)),
        Text('${(s.pct * 100).toStringAsFixed(0)}%',
            style: TextStyle(color: s.color, fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
      const SizedBox(height: 5),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: s.pct, minHeight: 8,
          backgroundColor: s.color.withAlpha(20),
          valueColor: AlwaysStoppedAnimation(s.color),
        ),
      ),
    ]),
  );
}

// ── Audience selection chip for broadcast modal ────────────────────────────
class _AudienceChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final VoidCallback onTap;
  const _AudienceChip({required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.govBlue : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.govBlue : AppTheme.border),
        ),
        child: Text(label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
