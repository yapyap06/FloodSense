import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/locale_provider.dart';


// ── Government PPS & Supply Management Screen ─────────────────────────────────
class GovPPSScreen extends StatefulWidget {
  const GovPPSScreen({super.key});
  @override
  State<GovPPSScreen> createState() => _GovPPSScreenState();
}

class _GovPPSScreenState extends State<GovPPSScreen> {
  // Hardcoded PPS list (in production this would come from Firestore)
  static const _ppsList = [
    _PPSData(id: 'PPS_001', name: 'Stadium Shah Alam', capacity: 500, location: 'Shah Alam, Selangor'),
    _PPSData(id: 'PPS_002', name: 'Kompleks Sukan Klang', capacity: 300, location: 'Klang, Selangor'),
    _PPSData(id: 'PPS_003', name: 'Dewan Orang Ramai Semenyih', capacity: 150, location: 'Semenyih, Selangor'),
  ];

  @override
  Widget build(BuildContext context) {
    final isMs = context.watch<LocaleProvider>().locale.languageCode == 'ms';
    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHeader(isMs),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(children: [
              _buildPPSSection(context, isMs),
              const SizedBox(height: 20),
              _buildRegistrationsSection(isMs),
              const SizedBox(height: 20),
              _buildSupplySection(context, isMs),
              const SizedBox(height: 20),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMs) => Container(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF0F2044), Color(0xFF1E3A5F)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppTheme.hope.withAlpha(30), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.location_city, color: AppTheme.hope, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isMs ? 'PPS & Bekalan' : 'PPS & Supply Management', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
            Text(isMs ? 'Pengurusan Pusat Pemindahan & Bekalan' : 'Relief Centres & Supply Management', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ]),
        ),
      ]),
      const SizedBox(height: 16),
      // Quick stats row
      Row(children: [
        _StatChip(label: isMs ? 'PPS Aktif' : 'Active PPS', value: '${_ppsList.length}', color: AppTheme.hope),
        const SizedBox(width: 8),
        _StatChip(label: isMs ? 'Jumlah Kapasiti' : 'Total Capacity', value: '${_ppsList.fold(0, (s, p) => s + p.capacity)}', color: AppTheme.govBlue),
        const SizedBox(width: 8),
        _StatChip(label: isMs ? 'Daerah' : 'District', value: 'Klang', color: AppTheme.warning),
      ]),
    ]),
  );

  Widget _buildPPSSection(BuildContext context, bool isMs) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.apartment_outlined, color: AppTheme.govBlue, size: 18),
        const SizedBox(width: 8),
        Text(isMs ? 'Pusat Pemindahan Sementara (PPS)' : 'Temporary Relief Centres (PPS)', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.black)),
      ]),
      const SizedBox(height: 12),
      ..._ppsList.map((pps) => _PPSTile(pps: pps, isMs: isMs)),
    ]);
  }

  Widget _buildRegistrationsSection(bool isMs) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pps_registrations')
          .orderBy('registered_at', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(children: [
                const Icon(Icons.how_to_reg_outlined, color: AppTheme.govBlue, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(isMs ? 'Pendaftaran PPS' : 'PPS Registrations', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.black))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.govBlue.withAlpha(20), borderRadius: BorderRadius.circular(12)),
                  child: Text('${docs.length} ${isMs ? 'mendaftar' : 'registered'}', style: const TextStyle(color: AppTheme.govBlue, fontWeight: FontWeight.w700, fontSize: 11)),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(isMs ? 'Segerak masa nyata dari kiosk PPS' : 'Live sync from citizen PPS kiosk registrations', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ),
            const Divider(height: 1),

            if (snap.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (docs.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  const Icon(Icons.person_search_outlined, color: AppTheme.textMuted, size: 40),
                  const SizedBox(height: 8),
                  Text(isMs ? 'Tiada pendaftaran lagi' : 'No registrations yet', style: const TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(isMs ? 'Pendaftaran yang dibuat di kiosk PPS akan dipaparkan di sini serta merta.' : 'Registrations made at the PPS kiosk will appear here instantly.',
                      textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                ]),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return Row(children: [
                    const Icon(Icons.person_outline, size: 16, color: AppTheme.textMuted),
                    const SizedBox(width: 8),
                    Expanded(child: Text(data['name'] ?? 'Unknown', style: const TextStyle(fontSize: 13))),
                    Text(data['pps_id'] ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ]);
                },
              ),
          ]),
        );
      },
    );
  }

  Widget _buildSupplySection(BuildContext context, bool isMs) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('supplies').doc('warehouse').snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data() as Map<String, dynamic>? ?? {};
        final supplies = [
          _SupplyItem(key: 'food',  label: isMs ? 'Pek Makanan' : 'Food Packs',       pct: (d['food']  as num?)?.toDouble() ?? 0.72, color: AppTheme.hope,       icon: Icons.fastfood_outlined),
          _SupplyItem(key: 'water', label: isMs ? 'Air Bersih' : 'Clean Water',        pct: (d['water'] as num?)?.toDouble() ?? 0.88, color: AppTheme.govBlue,    icon: Icons.water_drop_outlined),
          _SupplyItem(key: 'meds',  label: isMs ? 'Kit Perubatan' : 'Medical Kits',    pct: (d['meds']  as num?)?.toDouble() ?? 0.45, color: AppTheme.warning,    icon: Icons.medical_services_outlined),
          _SupplyItem(key: 'power', label: 'Power Bank',                               pct: (d['power'] as num?)?.toDouble() ?? 0.30, color: AppTheme.emergency, icon: Icons.battery_charging_full_outlined),
          _SupplyItem(key: 'baby',  label: isMs ? 'Susu Bayi' : 'Baby Formula',        pct: (d['baby']  as num?)?.toDouble() ?? 0.61, color: AppTheme.hope,       icon: Icons.child_care_outlined),
        ];

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.inventory_2_outlined, color: AppTheme.govBlue, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(isMs ? 'Inventori Bekalan' : 'Supply Inventory', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.black))),
            ]),
            const SizedBox(height: 4),
            Text(isMs ? 'Dikemas kini masa nyata dari Firestore' : 'Real-time updates from Firestore', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            const SizedBox(height: 16),
            ...supplies.map((s) => _SupplyRow(item: s, isMs: isMs)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showRestockDialog(context, isMs),
                icon: const Icon(Icons.add_shopping_cart, size: 16),
                label: Text(isMs ? 'Restock Bekalan' : 'Restock Supplies'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.govBlue,
                  side: const BorderSide(color: AppTheme.govBlue),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }

  void _showRestockDialog(BuildContext context, bool isMs) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.warehouse_outlined, color: AppTheme.govBlue),
          const SizedBox(width: 10),
          Text(isMs ? 'Restock Gudang' : 'Restock Warehouse', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ]),
        content: Text(isMs ? 'Restock akan mengisi semua inventori bekalan ke tahap penuh. Tindakan ini akan dilog sebagai operasi logistik.\n\nAdakah anda ingin meneruskan?' : 'Restock will fill all supplies to full capacity. This action will be logged as a logistics operation.\n\nDo you want to proceed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isMs ? 'Batal' : 'Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.hope),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('supplies').doc('warehouse').set({
                'food': 1.0, 'water': 1.0, 'meds': 0.9, 'power': 0.7, 'baby': 0.85,
              });
              await FirebaseFirestore.instance.collection('activity_log').add({
                'text': 'Restock bekalan depoh JKM dilakukan oleh Pengarah PKB',
                'icon': 'inventory',
                'type': 'SUPPLY',
                'created_at': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(isMs ? 'Inventori berjaya diisi semula!' : 'Inventory successfully restocked!'), backgroundColor: AppTheme.hope));
              }
            },
            child: Text(isMs ? 'Restock Sekarang' : 'Restock Now'),
          ),
        ],
      ),
    );
  }
}

// ── PPS Tile ───────────────────────────────────────────────────────────────────
class _PPSTile extends StatelessWidget {
  final _PPSData pps;
  final bool isMs;
  const _PPSTile({required this.pps, required this.isMs});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('pps_registrations').where('pps_id', isEqualTo: pps.id).snapshots(),
      builder: (context, snap) {
        final occupied = snap.data?.docs.length ?? 0;
        final pct = (occupied / pps.capacity).clamp(0.0, 1.0);
        final isNearFull = pct > 0.8;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isNearFull ? AppTheme.emergency.withAlpha(80) : AppTheme.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.govBlue.withAlpha(15), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.location_city_outlined, color: AppTheme.govBlue, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(pps.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black)),
                Text(pps.location, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ])),
              if (isNearFull)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppTheme.emergencyLight, borderRadius: BorderRadius.circular(6)),
                  child: Text(isMs ? 'HAMPIR PENUH' : 'NEAR FULL', style: const TextStyle(color: AppTheme.emergency, fontWeight: FontWeight.w800, fontSize: 10)),
                ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('$occupied / ${pps.capacity} orang', style: TextStyle(color: isNearFull ? AppTheme.emergency : AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                  Text('${(pct * 100).toStringAsFixed(0)}%', style: TextStyle(color: isNearFull ? AppTheme.emergency : AppTheme.govBlue, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    backgroundColor: AppTheme.border,
                    valueColor: AlwaysStoppedAnimation(isNearFull ? AppTheme.emergency : AppTheme.hope),
                  ),
                ),
              ])),
            ]),

          ]),
        );
      },
    );
  }
}

// ── Supply Row ─────────────────────────────────────────────────────────────────
class _SupplyRow extends StatelessWidget {
  final _SupplyItem item;
  final bool isMs;
  const _SupplyRow({required this.item, required this.isMs});

  @override
  Widget build(BuildContext context) {
    final isLow = item.pct < 0.35;
    final color = isLow ? AppTheme.emergency : item.color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(item.icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(item.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black))),
          if (isLow) Text(isMs ? '⚠ RENDAH' : '⚠ LOW', style: const TextStyle(color: AppTheme.emergency, fontWeight: FontWeight.w700, fontSize: 10)),
          const SizedBox(width: 8),
          Text('${(item.pct * 100).toStringAsFixed(0)}%', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: item.pct, minHeight: 8,
            backgroundColor: color.withAlpha(20),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ]),
    );
  }
}

// ── Data classes ───────────────────────────────────────────────────────────────
class _PPSData {
  final String id, name, location;
  final int capacity;
  const _PPSData({required this.id, required this.name, required this.capacity, required this.location});
}

class _SupplyItem {
  final String key, label;
  final double pct;
  final Color color;
  final IconData icon;
  const _SupplyItem({required this.key, required this.label, required this.pct, required this.color, required this.icon});
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withAlpha(60))),
    child: Column(children: [
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9)),
    ]),
  );
}
