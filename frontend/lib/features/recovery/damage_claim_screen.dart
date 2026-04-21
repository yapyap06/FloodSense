import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/loc_text.dart';
import '../../../core/providers/locale_provider.dart';

class DamageClaimScreen extends StatefulWidget {
  final String userName;
  const DamageClaimScreen({super.key, this.userName = 'Pengguna Awam'});
  @override
  State<DamageClaimScreen> createState() => _DamageClaimScreenState();
}

class _DamageClaimScreenState extends State<DamageClaimScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMs = context.watch<LocaleProvider>().locale.languageCode == 'ms';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(isMs ? 'Tuntutan Kerosakan' : 'Damage Claim',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
        actions: [
          // Policy info button
          IconButton(
            icon: const Icon(Icons.shield_outlined, color: AppTheme.govBlue),
            tooltip: isMs ? 'Polisi Tuntutan' : 'Claim Policy',
            onPressed: () => _showPolicySheet(context),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: AppTheme.govBlue,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.govBlue,
          tabs: [
            Tab(text: isMs ? 'Tuntutan Baharu' : 'New Claim'),
            Tab(text: isMs ? 'Tuntutan Saya' : 'My Claims'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _NewClaimWizard(userName: widget.userName, onSubmitted: () => _tab.animateTo(1)),
          _MyClaimsLive(userName: widget.userName),
        ],
      ),
    );
  }

  void _showPolicySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _PolicySheet(),
    );
  }
}

// --- Policy Sheet ---

class _PolicySheet extends StatelessWidget {
  const _PolicySheet();
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.all(24),
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Row(children: [
            Icon(Icons.shield_outlined, color: AppTheme.govBlue, size: 26),
            SizedBox(width: 10),
            Flexible(
              child: Text('Claim Policy / Polisi Tuntutan',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Colors.black)),
            ),
          ]),
          const SizedBox(height: 20),

          const _PolicySection(
            icon: Icons.attach_money,
            title: 'Maximum Coverage',
            color: AppTheme.hope,
            content: 'RM 5,000 per household per flood event under the JKM Bantuan Wang Ehsan scheme.\n\nHigh-value items (electronics, vehicles) require additional receipt proof.',
          ),
          const _PolicySection(
            icon: Icons.check_circle_outline,
            title: 'Eligibility',
            color: AppTheme.govBlue,
            content: '-  Property must be within a Government-declared flood zone\n-  Applicant must be Malaysian Citizen (MyKad required)\n-  One claim per registered household address\n-  Claims must be filed within 30 days of the flood event',
          ),
          const _PolicySection(
            icon: Icons.list_alt_outlined,
            title: 'How to Claim (Step-by-Step)',
            color: AppTheme.warning,
            content: '1. Upload up to 5 clear photos of damage\n2. Select flood water depth level\n3. List all damaged / lost items\n4. Run AI photo analysis for cost estimate\n5. Review and submit - receive Claim ID instantly\n6. JKM officer will contact you within 72 hours',
          ),
          const _PolicySection(
            icon: Icons.store_outlined,
            title: 'Partner Hardware Discounts',
            color: Color(0xFF7C3AED),
            content: 'Present your FloodSense Claim ID at these partners for rebuild discounts:\n\n-  Mr DIY - 10% off all purchases (code: BANJIR10)\n-  ACE Hardware - 15% off power tools (code: FLOOD15)\n-  Eco-Shop - Free delivery on orders > RM 50\n-  Lazada - Additional 8% cashback (code: JKMAID)',
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const LocText('Tutup', 'Close'),
          ),
        ],
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final IconData icon;
  final String title, content;
  final Color color;
  const _PolicySection({required this.icon, required this.title, required this.content, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withAlpha(10),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withAlpha(40)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color)),
      ]),
      const SizedBox(height: 10),
      Text(content, style: const TextStyle(color: Colors.black, fontSize: 13, height: 1.6)),
    ]),
  );
}

// --- 4-Step Wizard ---

class _NewClaimWizard extends StatefulWidget {
  final String userName;
  final VoidCallback onSubmitted;
  const _NewClaimWizard({required this.userName, required this.onSubmitted});
  @override
  State<_NewClaimWizard> createState() => _NewClaimWizardState();
}

class _NewClaimWizardState extends State<_NewClaimWizard> {
  int _step = 0;
  final List<XFile> _photos = [];
  final List<Uint8List> _photoBytes = [];
  final List<XFile> _receipts = [];
  String _floodDepth = 'Knee';
  final _lossesCtrl = TextEditingController();
  final _finalAmountCtrl = TextEditingController(); // MANDATORY: user must enter final RM
  List<Map<String, dynamic>> _assessments = [];
  // Manual override per photo
  final Map<int, TextEditingController> _manualOverrides = {};
  bool _analyzing = false;
  bool _submitted = false;
  String? _lastClaimId;
  bool _declarationChecked = false;

  Future<void> _pickPhoto() async {
    if (_photos.length >= 5) return;
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 30, maxWidth: 800, maxHeight: 800);
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _photos.add(file);
        _photoBytes.add(bytes);
        _assessments.clear();
      });
    }
  }

  Future<void> _pickReceipt() async {
    if (_receipts.length >= 5) return;
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 30, maxWidth: 600, maxHeight: 600);
    if (file != null) setState(() => _receipts.add(file));
  }
  static final _valuationTable = <(List<String>, String, int, int)>[
    // Furniture
    (['sofa', 'couch', 'kerusi panjang', 'kusyen'],             'Furniture',    1200, 600),
    (['bed', 'katil', 'bed frame', 'rangka katil'],             'Furniture',     800, 400),
    (['dining table', 'meja makan', 'dining set'],              'Furniture',     600, 300),
    (['coffee table', 'meja kopi', 'meja rendah'],              'Furniture',     300, 150),
    (['wardrobe', 'almari', 'wardrob', 'cabinet', 'kabinet'],   'Furniture',     600, 300),
    (['bookshelf', 'rak buku', 'shelf', 'rak'],                 'Furniture',     350, 175),
    (['chair', 'kerusi', 'stool', 'bangku'],                    'Furniture',     200, 100),
    // Electronics
    (['tv', 'television', 'televisyen', 'led tv', 'smart tv'],  'Electronics',  1100, 550),
    (['laptop', 'komputer riba', 'notebook'],                   'Electronics',  2500, 1200),
    (['computer', 'desktop', 'komputer', 'pc'],                 'Electronics',  2000, 1000),
    (['phone', 'telefon', 'handphone', 'smartphone'],           'Gadgets',      1500, 750),
    (['tablet', 'ipad'],                                        'Gadgets',      1200, 600),
    (['fan', 'kipas', 'ceiling fan', 'kipas siling'],           'Electronics',   200, 100),
    (['air cond', 'aircond', 'air conditioner', 'penyaman'],    'Electronics',  1800, 900),
    // Kitchen
    (['refrigerator', 'fridge', 'peti ais', 'peti sejuk'],      'Electronics',   950, 450),
    (['gas stove', 'dapur gas', 'stove', 'dapur'],              'Essential',     150,  75),
    (['washing machine', 'mesin basuh', 'washer'],              'Electronics',  1000, 500),
    (['microwave', 'ketuhar gelombang mikro'],                  'Electronics',   400, 200),
    (['rice cooker', 'periuk nasi', 'cooker'],                  'Essential',     150,  75),
    (['water heater', 'pemanas air'],                           'Electronics',   500, 250),
    // Bedroom
    (['mattress', 'tilam', 'queen mattress', 'king mattress'],  'Furniture',     800, 400),
    (['pillow', 'bantal', 'bedding', 'cadar', 'comforter'],     'Essential',     200, 100),
    // Structural
    (['wall', 'dinding', 'plaster', 'ceiling', 'siling'],       'Structural',   2000, 1000),
    (['floor', 'lantai', 'tile', 'jubin'],                      'Structural',   1500, 750),
    (['door', 'pintu', 'window', 'tingkap'],                    'Structural',    500, 250),
    (['roof', 'bumbung', 'atap'],                               'Structural',   3000, 1500),
  ];



  // Safe total: only read indices that exist in both lists
  int _effectiveCost(int i) {
    if (i < 0 || i >= _assessments.length) return 0;
    final ctrl = _manualOverrides[i];
    if (ctrl != null && ctrl.text.isNotEmpty) {
      return int.tryParse(ctrl.text.replaceAll(',', '')) ?? (_assessments[i]['estimated_cost_myr'] as int? ?? 0);
    }
    return _assessments[i]['estimated_cost_myr'] as int? ?? 0;
  }

  int get _totalCost {
    final len = _assessments.length;
    if (len == 0) return 0;
    return List.generate(len, (i) => _effectiveCost(i)).fold(0, (a, b) => a + b);
  }

  Future<void> _submit() async {
    final isMs = context.watch<LocaleProvider>().locale.languageCode == 'ms';
    if (!_declarationChecked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isMs
              ? 'Sila tandai kotak pengisytiharan untuk bersetuju.'
              : 'Please tick the declaration box to agree.',
              style: const TextStyle(color: Colors.white)),
          backgroundColor: AppTheme.emergency,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Mandatory: user must type the final RM amount
    if (_finalAmountCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isMs
              ? 'Sila masukkan jumlah tuntutan akhir (RM) sebelum menghantar.'
              : 'Please enter your final claim amount (RM) before submitting.',
              style: const TextStyle(color: Colors.white)),
          backgroundColor: AppTheme.emergency,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _analyzing = true);
    try {
      final claimId = 'CLM-${DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase()}';
      final finalAmount = int.tryParse(_finalAmountCtrl.text.replaceAll(',', '')) ?? _totalCost;
      final photoB64s = <String>[];
      for (final p in _photos.take(3)) {
        try {
          photoB64s.add(base64Encode(await p.readAsBytes()));
        } catch (_) {}
      }
      final receiptB64s = <String>[];
      for (final r in _receipts.take(3)) {
        try {
          receiptB64s.add(base64Encode(await r.readAsBytes()));
        } catch (_) {}
      }

      FirebaseFirestore.instance.collection('damage_claims').doc(claimId).set({
        'claim_id': claimId,
        // 'SUBMITTED' matches the GovClaimsScreen filter chips
        'status': 'SUBMITTED',
        // Canonical field names read by GovClaimsScreen
        'total_amount': finalAmount,
        'total_estimated_cost_myr': finalAmount, // alias for citizen My Claims tab
        'owner_name': widget.userName, 
        'items': _assessments, // GovClaimsScreen reads items.length
        'flood_depth': _floodDepth,
        'losses_description': _lossesCtrl.text,
        'photo_count': _photos.length,
        'receipt_count': _receipts.length,
        'photos_b64': photoB64s,
        'receipts_b64': receiptB64s,
        'assessments': _assessments,
        'created_at': Timestamp.now(),
        'user_id': widget.userName,
      });
      // Do not await the future, allow Firestore offline persistence to handle syncing in the background.
      setState(() { _submitted = true; _analyzing = false; _lastClaimId = claimId; });
      // Show success dialog FIRST — use builder context (dialogCtx) so pop() works correctly
      if (mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 56, height: 56,
                decoration: const BoxDecoration(color: AppTheme.hopeLight, shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_outline, color: AppTheme.hope, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                isMs ? 'Tuntutan Diterima!' : 'Claim Received!',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.black),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isMs
                    ? 'Pegawai kami akan mengesahkan gambar anda. Biasanya mengambil masa 2–3 hari. Kami akan memaklumkan anda di sini setelah status dikemaskini.'
                    : 'Our officers will verify your photos. This usually takes 2\u20133 days. We will notify you here once the status is updated.',
                style: const TextStyle(color: Color(0xFF4B5563), fontSize: 13, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ]),
            actions: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  // FIX: Use dialogCtx.pop() — closes only the dialog
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const LocText('Faham', 'Understood'),
                ),
              ),
            ],
          ),
        );
        // Switch to My Claims tab AFTER dialog is dismissed
        widget.onSubmitted();
      }
    } catch (_) { setState(() => _analyzing = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _buildSuccess();
    return Column(children: [
      // Step indicator
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(children: List.generate(4, (i) {
          final done = i < _step;
          final active = i == _step;
          return Expanded(child: Row(children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: done ? AppTheme.hope : active ? AppTheme.govBlue : AppTheme.border,
              child: done
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : Text('${i + 1}', style: TextStyle(color: active ? Colors.white : AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            if (i < 3) Expanded(child: Container(height: 2, color: done ? AppTheme.hope : AppTheme.border, margin: const EdgeInsets.symmetric(horizontal: 4))),
          ]));
        })),
      ),
      Expanded(child: [_buildStep1(), _buildStep2(), _buildStep3(), _buildStep4()][_step]),
    ]);
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ Step 1: Photos with LIVE COLOR THUMBNAILS Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  void _showFullScreenImage(Uint8List bytes) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              clipBehavior: Clip.none,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 0, right: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const LocText('Langkah 1: Muat Naik Gambar', 'Step 1: Upload Damage Photos',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Colors.black)),
      const SizedBox(height: 6),
      const LocText('Muat naik sehingga 5 keping gambar kerosakan banjir harta benda anda', 'Upload up to 5 photos of flood damage to your property',
          style: TextStyle(color: Color(0xFF4B5563), fontSize: 14)),
      const SizedBox(height: 20),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
        itemCount: _photos.length + (_photos.length < 5 ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _photos.length) {
            return GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.govBlueLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.govBlue.withAlpha(60)),
                ),
                child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_photo_alternate_outlined, color: AppTheme.govBlue, size: 32),
                  SizedBox(height: 4),
                  LocText('Tambah Gambar', 'Add Photo', textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.govBlue, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
            );
          }
          // LIVE COLOR THUMBNAIL — works on both web and mobile
          return Stack(children: [
            GestureDetector(
              onTap: () => _showFullScreenImage(_photoBytes[i]),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  _photoBytes[i],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
            // Remove button
            Positioned(
              top: 4, right: 4,
              child: GestureDetector(
                onTap: () => setState(() {
                  _photos.removeAt(i);
                  _photoBytes.removeAt(i);
                }),
                child: Container(
                  width: 22, height: 22,
                  decoration: const BoxDecoration(color: AppTheme.emergency, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
          ]);
        },
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _photos.isNotEmpty ? () => setState(() => _step = 1) : null,
          child: const LocText('Seterusnya: Kedalaman ->', 'Next: Flood Depth ->'),
        ),
      ),
    ]),
  );

  // Ã¢â€â‚¬Ã¢â€â‚¬ Step 2: Flood depth Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  Widget _buildStep2() {
    final isMs = context.watch<LocaleProvider>().locale.languageCode == 'ms';
    const internalDepths = ['Knee', 'Waist', 'Chest', 'Roof Level'];
    final displayDepths = isMs 
        ? ['Paras Lutut', 'Paras Pinggang', 'Paras Dada', 'Paras Bumbung']
        : ['Knee', 'Waist', 'Chest', 'Roof Level'];
    const icons = [Icons.height, Icons.accessibility_new, Icons.person, Icons.roofing];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const LocText('Langkah 2: Kedalaman', 'Step 2: Flood Depth',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Colors.black)),
        const SizedBox(height: 20),
        ...List.generate(internalDepths.length, (i) {
          final sel = _floodDepth == internalDepths[i];
          return GestureDetector(
            onTap: () => setState(() => _floodDepth = internalDepths[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: sel ? AppTheme.govBlueLight : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: sel ? AppTheme.govBlue : AppTheme.border, width: sel ? 2 : 1),
              ),
              child: Row(children: [
                Icon(icons[i], color: sel ? AppTheme.govBlue : AppTheme.textSecondary, size: 24),
                const SizedBox(width: 14),
                Text(displayDepths[i], style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15,
                    color: sel ? AppTheme.govBlue : Colors.black)),
                const Spacer(),
                if (sel) const Icon(Icons.check_circle, color: AppTheme.govBlue, size: 20),
              ]),
            ),
          );
        }),
        const SizedBox(height: 24),
        const LocText('Butiran Tambahan (Pilihan)', 'Additional Details (Optional)',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black)),
        const SizedBox(height: 8),
        TextField(
          controller: _lossesCtrl,
          maxLines: 4,
          maxLength: 500,
          style: const TextStyle(color: Colors.black, fontSize: 14),
          decoration: InputDecoration(
            hintText: isMs ? 'Terangkan situasi anda atau senaraikan barangan yang tidak tersenarai untuk pertimbangan AI...' : 'Describe your situation or list unlisted damaged items to assist the AI judgment...',
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.govBlue, width: 2)),
          ),
        ),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 0), child: const LocText('<- Kembali', '<- Back'))),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(onPressed: () => setState(() => _step = 2), child: const LocText('Seterusnya: Kerugian ->', 'Next: Losses ->'))),
        ]),
      ]),
    );
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ Step 3: Item Entry (Category | Item | Qty rows) Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  static const _categories = ['Furniture','Electronics','Gadgets','Essential','Structural'];

  // One row = {category, itemKey, qty}
  final List<Map<String, dynamic>> _claimRows = [];

  static const int _bwi = 1000;
  static const int _maxCap = 5000;
  static const int _maxQtyPerItem = 2;

  // Items per category (key = keywords.first)
  static final _catItems = <String, List<String>>{
    'Furniture':    ['sofa','bed','dining table','coffee table','wardrobe','bookshelf','chair','mattress','pillow'],
    'Electronics':  ['tv','laptop','computer','fan','air cond','refrigerator','washing machine','microwave','water heater'],
    'Gadgets':      ['phone','tablet'],
    'Essential':    ['gas stove','rice cooker'],
    'Structural':   ['wall','floor','door','roof'],
  };

  int get _itemsSubtotal {
    int total = 0;
    for (final row in _claimRows) {
      final key = row['itemKey'] as String? ?? '';
      final qty = row['qty'] as int? ?? 0;
      if (key.isEmpty) continue;
      final vRow = _valuationTable.firstWhere(
          (r) => r.$1.first == key, orElse: () => (const [], '', 0, 0));
      total += vRow.$4 * qty;
    }
    return total;
  }

  Widget _buildStep3() {
    return Column(children: [
      // Ã¢â€â‚¬Ã¢â€â‚¬ Header Ã¢â€â‚¬Ã¢â€â‚¬
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(children: [
          Icon(Icons.playlist_add_check_rounded, color: AppTheme.govBlue, size: 20),
          SizedBox(width: 8),
          Expanded(child: LocText('Pilih Barangan Yang Hilang / Rosak', 'Select Lost / Damaged Items',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black))),
        ]),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: LocText('Pilih kategori, item, kemudian kuantiti.', 'Choose category, then item, then quantity (max 2 per item).',
            style: TextStyle(color: Color(0xFF4B5563), fontSize: 12)),
      ),
      const SizedBox(height: 10),

      // Ã¢â€â‚¬Ã¢â€â‚¬ Column headers Ã¢â€â‚¬Ã¢â€â‚¬
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Builder(builder: (context) {
          final isMs = context.watch<LocaleProvider>().locale.languageCode == 'ms';
          return Row(children: [
            Expanded(flex: 4, child: Text(isMs ? 'Kategori' : 'Category',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary, letterSpacing: 0.5))),
            const SizedBox(width: 8),
            Expanded(flex: 5, child: Text(isMs ? 'Barangan' : 'Item',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary, letterSpacing: 0.5))),
            const SizedBox(width: 8),
            SizedBox(width: 88, child: Center(child: Text('QTY',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary, letterSpacing: 0.5)))),
            const SizedBox(width: 36),
          ]);
        }),
      ),
      const SizedBox(height: 6),

      // Ã¢â€â‚¬Ã¢â€â‚¬ Rows list Ã¢â€â‚¬Ã¢â€â‚¬
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _claimRows.length + 1, // +1 for "Add" button
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            if (i == _claimRows.length) {
              // Add row button
              return Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 16),
                child: Builder(builder: (context) {
                  final isMs = context.watch<LocaleProvider>().locale.languageCode == 'ms';
                  return OutlinedButton.icon(
                    onPressed: () => setState(() => _claimRows.add({'category': '', 'itemKey': '', 'qty': 1})),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(isMs ? 'Tambah Barangan' : 'Add Item'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.govBlue),
                      foregroundColor: AppTheme.govBlue,
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  );
                }),
              );
            }

            final row = _claimRows[i];
            final cat = row['category'] as String? ?? '';
            final itemKey = row['itemKey'] as String? ?? '';
            final qty = row['qty'] as int? ?? 1;

            return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              // Category button
              Expanded(flex: 4, child: _SelectorButton(
                label: cat.isEmpty ? (context.watch<LocaleProvider>().locale.languageCode == 'ms' ? 'Kategori' : 'Category') : cat,
                isPlaceholder: cat.isEmpty,
                icon: Icons.category_outlined,
                onTap: () => _showCategoryPicker(ctx, i),
              )),
              const SizedBox(width: 8),
              // Item button
              Expanded(flex: 5, child: _SelectorButton(
                label: itemKey.isEmpty ? (context.watch<LocaleProvider>().locale.languageCode == 'ms' ? 'Barangan' : 'Item') : _displayName(itemKey),
                isPlaceholder: itemKey.isEmpty,
                icon: Icons.inventory_2_outlined,
                enabled: cat.isNotEmpty,
                onTap: cat.isEmpty ? null : () => _showItemPicker(ctx, i, cat),
              )),
              const SizedBox(width: 8),
              // Qty stepper
              SizedBox(
                width: 88,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _QtyButton(
                    icon: Icons.remove,
                    enabled: qty > 1,
                    onTap: () => setState(() {
                      _claimRows[i]['qty'] = qty - 1;
                      _syncAssessmentsFromSelected();
                    }),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text('$qty',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                            color: Colors.black)),
                  ),
                  _QtyButton(
                    icon: Icons.add,
                    enabled: qty < _maxQtyPerItem,
                    onTap: () => setState(() {
                      _claimRows[i]['qty'] = qty + 1;
                      _syncAssessmentsFromSelected();
                    }),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              // Delete row
              GestureDetector(
                onTap: () => setState(() {
                  _claimRows.removeAt(i);
                  _syncAssessmentsFromSelected();
                }),
                child: const Icon(Icons.delete_outline, color: Color(0xFF9CA3AF), size: 20),
              ),
            ]);
          },
        ),
      ),

      // Ã¢â€â‚¬Ã¢â€â‚¬ Bottom bar: receipt + nav Ã¢â€â‚¬Ã¢â€â‚¬
      Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: Column(children: [
          // Receipt upload
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickReceipt,
              icon: Icon(
                _receipts.isEmpty ? Icons.receipt_long_outlined : Icons.check_circle_outline,
                color: _receipts.isEmpty ? const Color(0xFF7C3AED) : AppTheme.hope,
                size: 18,
              ),
              label: Builder(builder: (context) {
                  final isMs = context.watch<LocaleProvider>().locale.languageCode == 'ms';
                  return Text(
                    _receipts.isEmpty
                        ? (isMs ? 'Muat Naik Resit (Pilihan)' : 'Upload Receipt (Optional)')
                        : (isMs ? '${_receipts.length} resit dimuat naik (OK)' : '${_receipts.length} receipt${_receipts.length > 1 ? "s" : ""} uploaded (OK)'),
                    style: TextStyle(
                        color: _receipts.isEmpty ? const Color(0xFF7C3AED) : AppTheme.hope,
                        fontSize: 13),
                  );
                }),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: _receipts.isEmpty ? const Color(0xFF7C3AED) : AppTheme.hope),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton(
                onPressed: () => setState(() => _step = 1),
                child: const LocText('<- Kembali', '<- Back'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
                onPressed: () {
                  // Receipt is optional; we just proceed to Review.
                  _syncAssessmentsFromSelected();
                  final total = (_bwi + _itemsSubtotal).clamp(0, _maxCap);
                  if (_finalAmountCtrl.text.isEmpty) {
                    _finalAmountCtrl.text = total.toString();
                  }
                  setState(() => _step = 3);
                },
                child: const LocText('Semakan', 'Review'))),
          ]),
        ]),
      ),
    ]);
  }

  Future<void> _showCategoryPicker(BuildContext ctx, int rowIdx) async {
    final picked = await showModalBottomSheet<String>(
      context: ctx,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) {
        final isMs = sheetCtx.watch<LocaleProvider>().locale.languageCode == 'ms';
        final catLabels = isMs ? {
          'Furniture': 'Perabot', 'Electronics': 'Elektronik',
          'Gadgets': 'Gajet', 'Essential': 'Barangan Penting', 'Structural': 'Struktur',
        } : <String, String>{};
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(isMs ? 'Pilih Kategori' : 'Select Category',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          ..._categories.map((cat) => ListTile(
            leading: Icon(_categoryIcon(cat), color: AppTheme.govBlue),
            title: Text(catLabels[cat] ?? cat, style: const TextStyle(fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(sheetCtx, cat),
          )),
          const SizedBox(height: 12),
        ]);
      },
    );
    if (picked != null) {
      setState(() {
        _claimRows[rowIdx]['category'] = picked;
        _claimRows[rowIdx]['itemKey'] = ''; // reset item when category changes
        _syncAssessmentsFromSelected();
      });
    }
  }

  Future<void> _showItemPicker(BuildContext ctx, int rowIdx, String cat) async {
    final allItems = _catItems[cat] ?? [];
    final existingKeys = _claimRows.asMap().entries
        .where((e) => e.key != rowIdx)
        .map((e) => e.value['itemKey'] as String)
        .toSet();
    final items = allItems.where((k) => !existingKeys.contains(k)).toList();

    final picked = await showModalBottomSheet<String>(
      context: ctx,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(cat, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Semua item dalam kategori ini telah dipilih / All items in this category are already selected.',
                textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF4B5563), fontSize: 13)),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView(shrinkWrap: true, children: items.map((key) => ListTile(
              leading: Icon(_categoryIcon(cat), color: AppTheme.govBlue, size: 20),
              title: Text(_displayName(key), style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, key),
            )).toList()),
          ),
        const SizedBox(height: 12),
      ]),
    );
    if (picked != null) {
      setState(() {
        _claimRows[rowIdx]['itemKey'] = picked;
        _syncAssessmentsFromSelected();
      });
    }
  }

  void _syncAssessmentsFromSelected() {
    _assessments = _claimRows.expand((row) {
      final key = row['itemKey'] as String? ?? '';
      final qty = row['qty'] as int? ?? 0;
      if (key.isEmpty || qty == 0) return <Map<String,dynamic>>[];
      final vRow = _valuationTable.firstWhere(
          (r) => r.$1.first == key, orElse: () => (const [], '', 0, 0));
      return List.generate(qty, (_) => {
        'item': key, 'name': _displayName(key),
        'category': vRow.$2, 'damage_level': 'Partial',
        'estimated_loss': vRow.$4, 'claim_amount': vRow.$4,
        'estimated_cost_myr': vRow.$4, 'condition': 'Flood damaged',
        'loss_pct': 50, 'original_price': vRow.$3,
        'depreciated_value': vRow.$4, 'est_age_years': 3, 'lifespan_years': 10,
        'bwi_included': true,
        'total_claim': (_bwi + _itemsSubtotal).clamp(0, _maxCap),
        'severity': (_bwi + _itemsSubtotal) > 3000 ? 4 : 2,
        'nadma_band': (_bwi + _itemsSubtotal) > 3000 ? 'B' : 'A',
        'description_ms': 'Anggaran MKN Bil. 20',
      });
    }).toList();
  }

  IconData _categoryIcon(String cat) => switch (cat) {
    'Furniture' => Icons.weekend,
    'Electronics' => Icons.devices,
    'Gadgets' => Icons.phone_android,
    'Essential' => Icons.kitchen,
    'Structural' => Icons.home_repair_service,
    _ => Icons.inventory_2_outlined,
  };

  String _displayName(String key) {
    final map = {
      'sofa': 'Sofa / Couch', 'bed': 'Bed Frame', 'dining table': 'Dining Table',
      'coffee table': 'Coffee Table', 'wardrobe': 'Wardrobe / Almari',
      'bookshelf': 'Bookshelf / Rak', 'chair': 'Chair / Kerusi',
      'tv': 'TV / Smart TV', 'laptop': 'Laptop',
      'computer': 'Desktop PC', 'phone': 'Smartphone', 'tablet': 'Tablet / iPad',
      'fan': 'Fan / Kipas', 'air cond': 'Air Conditioner',
      'refrigerator': 'Refrigerator / Peti Ais',
      'gas stove': 'Gas Stove / Dapur', 'washing machine': 'Washing Machine',
      'microwave': 'Microwave', 'water heater': 'Water Heater',
      'mattress': 'Mattress / Tilam', 'pillow': 'Pillow / Bedding',
      'wall': 'Wall / Ceiling / Plaster', 'floor': 'Floor / Tiles',
      'door': 'Door / Window', 'roof': 'Roof / Bumbung',
    };
    return map[key] ?? key;
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ Step 4: Review & Submit Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  Widget _buildStep4() {
    final isMs = context.watch<LocaleProvider>().locale.languageCode == 'ms';
    return SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(isMs ? 'Langkah 4: Semakan & Hantar' : 'Step 4: Review & Submit',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Colors.black)),
      const SizedBox(height: 16),
      _ReviewRow(label: isMs ? 'Gambar' : 'Photos', value: isMs ? '${_photos.length} dimuat naik' : '${_photos.length} uploaded'),
      // Receipt uploads Ã¢â‚¬â€ shown as required
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _receipts.isEmpty ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _receipts.isEmpty ? AppTheme.emergency.withAlpha(80) : AppTheme.hope.withAlpha(80),
          ),
        ),
        child: Row(children: [
          Icon(
            _receipts.isEmpty ? Icons.receipt_long_outlined : Icons.check_circle_outline,
            color: _receipts.isEmpty ? AppTheme.emergency : AppTheme.hope,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _receipts.isEmpty
                  ? 'Receipt / Resit - (Optional, 0 uploaded)'
                  : 'Receipt uploaded: ${_receipts.length} (OK)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: _receipts.isEmpty ? AppTheme.emergency : AppTheme.hope,
              ),
            ),
          ),
        ]),
      ),
      _ReviewRow(
        label: isMs ? 'Paras Air' : 'Flood Depth',
        value: _floodDepth,
      ),
      _ReviewRow(
        label: isMs ? 'Keterangan Kerosakan' : 'Losses Described',
        value: _lossesCtrl.text.trim().isEmpty
            ? (isMs ? 'Tiada' : 'Not Provided')
            : (isMs ? 'Disertakan' : 'Provided'),
      ),
      if (_assessments.isNotEmpty)
        _ReviewRow(label: isMs ? 'Anggaran AI' : 'AI Estimate Total', value: 'RM $_totalCost'),
      _ReviewRow(
        label: isMs ? 'Jumlah Tuntutan Anda (RM)' : 'Your Final Claim (RM)',
        value: _finalAmountCtrl.text.isEmpty
            ? (isMs ? '(!) Belum diisi' : '(!) Not entered')
            : 'RM ${_finalAmountCtrl.text}',
      ),
      const SizedBox(height: 16),
      // Legal declaration
      Container(
        decoration: BoxDecoration(
            color: _declarationChecked ? AppTheme.hope.withAlpha(20) : const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _declarationChecked ? AppTheme.hope : AppTheme.border)),
        child: InkWell(
          onTap: () => setState(() => _declarationChecked = !_declarationChecked),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: _declarationChecked,
                    onChanged: (val) => setState(() => _declarationChecked = val ?? false),
                    activeColor: AppTheme.hope,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isMs
                        ? 'Dengan penghantaran ini, saya mengisytiharkan semua foto dan maklumat yang diberikan adalah benar di bawah Akta Keterangan 1950. Saya faham bahawa walaupun resit adalah pilihan, bukti foto kerosakan yang jelas adalah wajib. Tuntutan palsu akan mengakibatkan tindakan undang-undang.'
                        : 'With this submission, I declare all photos and information provided are truthful under Akta Keterangan 1950. I understand that while receipts are optional, clear photographic evidence of damage is mandatory for appraisal. False claims will result in legal action.',
                    style: const TextStyle(color: Color(0xFF4B5563), fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 2), child: const LocText('<- Kembali', '<- Back'))),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton(
          onPressed: _analyzing ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.hope),
          child: _analyzing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(isMs ? 'HANTAR TUNTUTAN' : 'SUBMIT CLAIM'),
        )),
      ]),
    ]),
  );
  }

  Widget _buildSuccess() {
    final isMs = context.watch<LocaleProvider>().locale.languageCode == 'ms';
    return Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const CircleAvatar(radius: 40, backgroundColor: AppTheme.hope,
          child: Icon(Icons.check_circle, color: Colors.white, size: 48)),
      const SizedBox(height: 24),
      Text(isMs ? 'Tuntutan Dihantar!' : 'Claim Submitted!',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.black)),
      const SizedBox(height: 8),
      Text(isMs ? 'Pegawai JKM akan menghubungi anda dalam masa 72 jam.' : 'JKM officer will contact you within 72 hours.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF4B5563))),
      if (_lastClaimId != null) ...[
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppTheme.govBlueLight, borderRadius: BorderRadius.circular(10)),
          child: Text('${isMs ? 'ID Tuntutan' : 'Claim ID'}: $_lastClaimId',
              style: const TextStyle(color: AppTheme.govBlue, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${isMs ? 'ID Tuntutan' : 'Claim ID'}: $_lastClaimId\n${isMs ? 'Bawa ID ini ke kaunter JKM untuk pengesahan.' : 'Present this ID at the JKM counter for verification.'}',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                backgroundColor: AppTheme.govBlue,
                duration: const Duration(seconds: 5),
                action: SnackBarAction(label: 'OK', textColor: Colors.white, onPressed: () {}),
              ),
            );
          },
          icon: const Icon(Icons.assignment_outlined, color: AppTheme.govBlue),
          label: Text(isMs ? 'Lihat ID Tuntutan' : 'View Claim ID',
              style: const TextStyle(color: AppTheme.govBlue)),
        ),
      ],
    ]),
  ));
  } // end _buildSuccess
} // end _NewClaimWizardState


// â”€â”€â”€ Live Claims Tab (StreamBuilder) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _MyClaimsLive extends StatelessWidget {
  final String userName;
  const _MyClaimsLive({required this.userName});

  String _monthName(int m) => const [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ][m];

  @override

  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      // Ã¢â€â‚¬Ã¢â€â‚¬ FIX: No orderBy Ã¢â‚¬â€ avoids composite index requirement.
      // We sort the results in Dart after fetching.
      // Use 'damage_claims' — same collection GovClaimsScreen reads
      stream: FirebaseFirestore.instance
          .collection('damage_claims')
          .where('user_id', isEqualTo: userName)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.govBlue, strokeWidth: 2));
        }

        final liveDocs = (snap.data?.docs ?? []).where((d) => d.data()['status'] != 'WITHDRAWN').toList();

        // Sort by created_at descending in Dart (avoids Firestore composite index)
        liveDocs.sort((a, b) {
          final aTs = a.data()['created_at'];
          final bTs = b.data()['created_at'];
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return (bTs as Timestamp).compareTo(aTs as Timestamp);
        });

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (liveDocs.isEmpty && snap.hasData)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Column(children: [
                  Icon(Icons.receipt_long_outlined, color: AppTheme.textMuted, size: 48),
                  SizedBox(height: 12),
                  Text('Tiada tuntutan lagi',
                      style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                  SizedBox(height: 6),
                  Text('Hantar tuntutan baru dari tab "New Claim"',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                ]),
              ),

            // Live Firestore claims
            ...liveDocs.map((doc) {
              final d = doc.data();
              final ts = d['created_at'];
              String dateStr = 'Baru dihantar';
              if (ts != null && ts is Timestamp) {
                final dt = ts.toDate().toLocal();
                dateStr = '${dt.day} ${_monthName(dt.month)} ${dt.year}';
              }
              return _LiveClaimCard(
                docId: doc.id,
                claimId: d['claim_id'] ?? doc.id,
                status: d['status'] ?? 'UNDER_REVIEW',
                rejectionReason: d['rejection_reason'] as String?,
                totalCost: (d['total_estimated_cost_myr'] as num?)?.toInt() ?? 0,
                date: dateStr,
                depth: d['flood_depth'] ?? '—',
              );
            }),

            // Static demo history
            const _LiveClaimCard(docId: '', claimId: 'CLM-1A2B3C', status: 'PENDING_INSPECTION',
                totalCost: 12400, date: '22 Mar 2026', depth: 'Waist'),
            const _LiveClaimCard(docId: '', claimId: 'CLM-0F9E8D', status: 'UNDER_REVIEW',
                totalCost: 4200, date: '18 Mar 2026', depth: 'Knee'),
            const _LiveClaimCard(docId: '', claimId: 'CLM-7C6B5A', status: 'APPROVED',
                totalCost: 28900, date: '10 Jan 2026', depth: 'Chest'),
            const _LiveClaimCard(docId: '', claimId: 'CLM-3D4E5F', status: 'REJECTED',
                totalCost: 1800, date: '2 Dec 2025', depth: 'Knee'),
          ],
        );
      },
    );
  }
}

class _LiveClaimCard extends StatefulWidget {
  final String docId, claimId, status, date, depth;
  final String? rejectionReason;
  final int totalCost;
  const _LiveClaimCard({required this.docId, required this.claimId, required this.status,
      this.rejectionReason, required this.totalCost, required this.date, required this.depth});

  @override
  State<_LiveClaimCard> createState() => _LiveClaimCardState();
}

class _LiveClaimCardState extends State<_LiveClaimCard> {
  bool _withdrawing = false;

  Future<void> _deleteClaim() async {
    if (widget.docId.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Claim?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          'Claim ${widget.claimId} will be permanently deleted. This action cannot be undone.',
          style: const TextStyle(color: Color(0xFF4B5563)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const LocText('Batal', 'Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.emergency),
            onPressed: () => Navigator.pop(ctx, true),
            child: const LocText('Padam', 'Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _withdrawing = true);
    try {
      await FirebaseFirestore.instance
          .collection('damage_claims')
          .doc(widget.docId)
          .delete();
      if (mounted) setState(() => _withdrawing = false);
    } catch (e) {
      if (mounted) {
        setState(() => _withdrawing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete claim. Please try again. ($e)')),
        );
      }
    }
  }

  void _viewDetails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ClaimDetailSheet(
        docId: widget.docId,
        claimId: widget.claimId,
        status: widget.status,
        date: widget.date,
        depth: widget.depth,
        totalCost: widget.totalCost,
        rejectionReason: widget.rejectionReason,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final (statusLabel, statusColor, statusIcon) = switch (status) {
      'SUBMITTED'          => ('Request Under Review', AppTheme.warning,   Icons.hourglass_top_outlined),
      'UNDER_REVIEW'       => ('Under Review',         AppTheme.warning,   Icons.hourglass_top_outlined),
      'PENDING_INSPECTION' => ('Pending Inspection',   AppTheme.govBlue,   Icons.home_outlined),
      'APPROVED'           => ('Approved',             AppTheme.hope,      Icons.check_circle_outline),
      'REJECTED'           => ('Rejected',             AppTheme.emergency, Icons.cancel_outlined),
      'WITHDRAWN'          => ('Withdrawn',            AppTheme.textMuted, Icons.remove_circle_outline),
      _                    => ('Pending Review',       AppTheme.warning,   Icons.hourglass_top_outlined),
    };

    const allStatuses = ['UNDER_REVIEW', 'PENDING_INSPECTION', 'APPROVED'];
    final currentIdx = allStatuses.indexOf(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: status == 'WITHDRAWN' ? const Color(0xFFF9FAFB) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: status == 'REJECTED' ? AppTheme.emergency.withAlpha(40) : AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.claimId, style: const TextStyle(fontWeight: FontWeight.w700,
                fontSize: 14, color: Colors.black, fontFamily: 'monospace')),
            Text('${widget.date} · Depth: ${widget.depth}',
                style: const TextStyle(color: Color(0xFF4B5563), fontSize: 12)),
          ])),
          Text('RM ${widget.totalCost}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black)),
        ]),
        const SizedBox(height: 12),

        // Status badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: statusColor.withAlpha(20), borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(statusIcon, color: statusColor, size: 14),
            const SizedBox(width: 6),
            Flexible(
              child: Text(statusLabel,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ]),
        ),

        if (status != 'REJECTED' && status != 'WITHDRAWN' && currentIdx >= 0) ...[
          const SizedBox(height: 16),
          Row(children: List.generate(allStatuses.length * 2 - 1, (i) {
            if (i.isOdd) {
              final stepIdx = i ~/ 2;
              return Expanded(child: Container(height: 2,
                  color: stepIdx < currentIdx ? AppTheme.hope : AppTheme.border));
            }
            final stepIdx = i ~/ 2;
            final done = stepIdx <= currentIdx;
            return CircleAvatar(radius: 10, backgroundColor: done ? AppTheme.hope : AppTheme.border,
                child: Icon(done ? Icons.check : Icons.circle, color: Colors.white, size: 10));
          })),
          const SizedBox(height: 6),
          const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            LocText('Semakan', 'Review', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
            LocText('Pemeriksaan', 'Inspection', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
            LocText('Diluluskan', 'Approved', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
          ]),
        ] else if (status == 'REJECTED') ...[
          const SizedBox(height: 8),
          widget.rejectionReason?.isNotEmpty == true
            ? Text(
                context.watch<LocaleProvider>().locale.languageCode == 'ms' 
                  ? 'Sebab: ${widget.rejectionReason}'
                  : 'Reason: ${widget.rejectionReason}',
                style: const TextStyle(color: Colors.deepPurple, fontSize: 12, fontWeight: FontWeight.bold)
              )
            : const LocText('[Fallback] Sebab: Alamat di luar zon banjir.', '[Fallback] Reason: Address is outside designated flood zone for this event.',
                style: TextStyle(color: Colors.deepPurple, fontSize: 12, fontWeight: FontWeight.bold)),
        ],

        const SizedBox(height: 12),
        // ── View Details button (always visible) ──────────────────────────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _viewDetails,
            icon: const Icon(Icons.visibility_outlined, size: 16),
            label: const LocText('Papar Butiran', 'View Claim Details'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.govBlue,
              side: BorderSide(color: AppTheme.govBlue.withAlpha(120)),
            ),
          ),
        ),

        // Delete button - for SUBMITTED and UNDER_REVIEW Firestore claims
        if ((status == 'SUBMITTED' || status == 'UNDER_REVIEW') && widget.docId.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _withdrawing ? null : _deleteClaim,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.emergency,
                side: BorderSide(color: AppTheme.emergency.withAlpha(120)),
              ),
              icon: _withdrawing
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.emergency))
                  : const Icon(Icons.delete_outline, size: 16),
              label: Text(_withdrawing ? 'Deleting...' : 'Delete Claim'),
            ),
          ),
        ],
      ]),
    );
  }
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Helpers Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬


// ── Claim Detail Bottom Sheet ─────────────────────────────────────────────────

class _ClaimDetailSheet extends StatelessWidget {
  final String docId, claimId, status, date, depth;
  final int totalCost;
  final String? rejectionReason;
  const _ClaimDetailSheet({
    required this.docId, required this.claimId, required this.status,
    required this.date, required this.depth, required this.totalCost,
    this.rejectionReason,
  });

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor, statusIcon) = switch (status) {
      'SUBMITTED'          => ('Request Under Review', AppTheme.warning,   Icons.hourglass_top_outlined),
      'UNDER_REVIEW'       => ('Under Review',         AppTheme.warning,   Icons.hourglass_top_outlined),
      'PENDING_INSPECTION' => ('Pending Inspection',   AppTheme.govBlue,   Icons.home_outlined),
      'APPROVED'           => ('Approved', AppTheme.hope, Icons.check_circle_outline),
      'REJECTED'           => ('Rejected', AppTheme.emergency, Icons.cancel_outlined),
      _                    => ('Pending Review', AppTheme.warning, Icons.hourglass_top_outlined),
    };
    if (docId.isEmpty) return _buildContent(context, statusLabel, statusColor, statusIcon, null);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('damage_claims').doc(docId).snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data();
        return _buildContent(context, statusLabel, statusColor, statusIcon, d);
      },
    );
  }

  Widget _buildContent(BuildContext context, String statusLabel, Color statusColor, IconData statusIcon, Map<String, dynamic>? data) {
    final photos = (data?['photos_b64'] as List?)?.cast<String>() ?? [];
    final receipts = (data?['receipts_b64'] as List?)?.cast<String>() ?? [];
    final items = (data?['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final description = data?['losses_description'] as String? ?? '';
    final floodDepth = data?['flood_depth'] as String? ?? depth;
    final amount = (data?['total_amount'] as num?)?.toInt() ?? totalCost;
    final reason = data?['rejection_reason'] as String? ?? rejectionReason;

    return DraggableScrollableSheet(
      expand: false, initialChildSize: 0.85, maxChildSize: 0.97, minChildSize: 0.5,
      builder: (_, ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)))),
          Row(children: [
            Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: statusColor.withAlpha(20), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.receipt_long_outlined, color: statusColor, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(claimId, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black, fontFamily: 'monospace')),
              Text(date, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('RM $amount', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.black)),
              Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusColor.withAlpha(20), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(statusIcon, color: statusColor, size: 12), const SizedBox(width: 4),
                  Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
                ])),
            ]),
          ]),
          if (status == 'REJECTED' && reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.emergency.withAlpha(15), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.emergency.withAlpha(40))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.info_outline, color: AppTheme.emergency, size: 18),
                  const SizedBox(width: 8),
                  const LocText('Sebab Penolakan', 'Rejection Reason', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.emergency)),
                ]),
                const SizedBox(height: 8),
                Text(reason, style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.4)),
              ]),
            ),
          ],
          const SizedBox(height: 20), const Divider(height: 1), const SizedBox(height: 20),
          _DetailRow(icon: Icons.water, label: 'Flood Depth', value: floodDepth),
          _DetailRow(icon: Icons.photo_library_outlined, label: 'Photos Submitted', value: '${photos.isNotEmpty ? photos.length : (data?['photo_count'] ?? 0)} photo(s)'),
          _DetailRow(icon: Icons.receipt_outlined, label: 'Receipts Submitted', value: '${receipts.isNotEmpty ? receipts.length : (data?['receipt_count'] ?? 0)} receipt(s)'),
          if (items.isNotEmpty) _DetailRow(icon: Icons.inventory_2_outlined, label: 'Claim Items', value: '${items.length} item(s) selected'),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 16),
            const LocText('Deskripsi Tambahan', 'Additional Description', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black)),
            const SizedBox(height: 8),
            Container(width: double.infinity, padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
              child: Text(description, style: const TextStyle(color: Colors.black, fontSize: 13, height: 1.5))),
          ],
          if (items.isNotEmpty) ...[
            const SizedBox(height: 20),
            const LocText('Barangan Direkodkan', 'Selected Damaged Items', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black)),
            const SizedBox(height: 10),
            ...items.map((item) {
              final name = item['item'] as String? ?? 'Item';
              final cost = (item['estimated_cost_myr'] as num?)?.toInt() ?? 0;
              final category = item['category'] as String? ?? '';
              return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: AppTheme.govBlueLight, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.govBlue.withAlpha(40))),
                child: Row(children: [
                  const Icon(Icons.check_circle_outline, color: AppTheme.govBlue, size: 16), const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black)),
                    if (category.isNotEmpty) Text(category, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ])),
                  if (cost > 0) Text('RM $cost', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.govBlue)),
                ]));
            }),
          ],
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(children: [const Icon(Icons.photo_library_outlined, color: AppTheme.govBlue, size: 18), const SizedBox(width: 8),
              const LocText('Gambar Kerosakan', 'Damage Photos', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black)), const Spacer(),
              Text('${photos.length} photo(s)', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))]),
            const SizedBox(height: 10),
            SizedBox(height: 130, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => GestureDetector(onTap: () => _showFullImage(context, photos[i], 'Damage Photo ${i + 1}'),
                child: ClipRRect(borderRadius: BorderRadius.circular(10),
                  child: Image.memory(base64Decode(photos[i]), width: 130, height: 130, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(width: 130, height: 130, color: AppTheme.surface, child: const Icon(Icons.broken_image_outlined, color: AppTheme.textMuted))))))),
          ],
          if (receipts.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(children: [const Icon(Icons.receipt_outlined, color: Color(0xFF7C3AED), size: 18), const SizedBox(width: 8),
              const LocText('Gambar Resit', 'Receipt Images', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black)), const Spacer(),
              Text('${receipts.length} receipt(s)', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))]),
            const SizedBox(height: 10),
            SizedBox(height: 130, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: receipts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => GestureDetector(onTap: () => _showFullImage(context, receipts[i], 'Receipt ${i + 1}'),
                child: ClipRRect(borderRadius: BorderRadius.circular(10),
                  child: Image.memory(base64Decode(receipts[i]), width: 130, height: 130, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(width: 130, height: 130, color: AppTheme.surface, child: const Icon(Icons.broken_image_outlined, color: AppTheme.textMuted))))))),
          ],
          if (photos.isEmpty && receipts.isEmpty && docId.isEmpty) ...[
            const SizedBox(height: 20),
            Container(padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
              child: const Row(children: [Icon(Icons.info_outline, color: AppTheme.textMuted, size: 18), SizedBox(width: 10),
                Expanded(child: Text('This is a demo claim. Photos and receipts are only available for claims submitted through the app.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)))])),
          ],
          const SizedBox(height: 24),
          OutlinedButton(onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
            child: const LocText('Tutup', 'Close')),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, String b64, String title) {
    showDialog(context: context, builder: (_) => Dialog(backgroundColor: Colors.black, insetPadding: const EdgeInsets.all(12),
      child: Stack(children: [
        InteractiveViewer(child: Image.memory(base64Decode(b64), fit: BoxFit.contain)),
        Positioned(top: 8, right: 8, child: GestureDetector(onTap: () => Navigator.pop(context),
          child: Container(width: 32, height: 32, decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
            child: const Icon(Icons.close, color: Colors.white, size: 18)))),
        Positioned(bottom: 12, left: 0, right: 0, child: Center(child: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)))),
      ])));
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _DetailRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Icon(icon, color: AppTheme.govBlue, size: 16), const SizedBox(width: 10),
      Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      const Spacer(),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black)),
    ]),
  );
}
class _SelectorButton extends StatelessWidget {
  final String label;
  final bool isPlaceholder;
  final bool enabled;
  final IconData icon;
  final VoidCallback? onTap;
  const _SelectorButton({required this.label, required this.isPlaceholder,
      required this.icon, this.enabled = true, this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : const Color(0xFFF9FAFB),
          border: Border.all(
            color: isPlaceholder ? const Color(0xFFD1D5DB) : AppTheme.govBlue,
            width: isPlaceholder ? 1 : 1.5,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(icon, size: 14,
              color: isPlaceholder ? const Color(0xFF9CA3AF) : AppTheme.govBlue),
          const SizedBox(width: 5),
          Expanded(child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: isPlaceholder ? const Color(0xFF9CA3AF) : Colors.black,
              ))),
          Icon(Icons.arrow_drop_down,
              size: 16,
              color: isPlaceholder ? const Color(0xFF9CA3AF) : AppTheme.govBlue),
        ]),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.enabled, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: enabled ? AppTheme.govBlue : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: enabled ? Colors.white : const Color(0xFFD1D5DB)),
    ),
  );
}

class _ReviewRow extends StatelessWidget {
  final String label, value;
  const _ReviewRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Color(0xFF4B5563), fontSize: 14)),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(value, textAlign: TextAlign.right, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 14)),
        ),
      ],
    ),
  );
}
