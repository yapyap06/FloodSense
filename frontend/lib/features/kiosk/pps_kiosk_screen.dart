import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// PPS (Pusat Pemindahan Sementara) Relief Centre Kiosk
/// Designed for tablets — large fonts, big touch targets, 4 languages
/// HIGH-CONTRAST LIGHT THEME: White bg, Black text, Light-blue/teal card accents
class PPSKioskScreen extends StatefulWidget {
  const PPSKioskScreen({super.key});
  @override
  State<PPSKioskScreen> createState() => _PPSKioskScreenState();
}

enum _KioskStep { language, scan, family, confirm, done }

class _PPSKioskScreenState extends State<PPSKioskScreen> {
  _KioskStep _step = _KioskStep.language;
  String _lang = 'ms';
  final _nameCtrl = TextEditingController();
  final _icCtrl = TextEditingController();
  int _familySize = 1;
  final Set<String> _needs = {};
  String? _receiptId;

  // Colour constants (Light Theme)
  static const _cBg = Color(0xFFFFFFFF);         // Pure white background
  static const _cSurface = Color(0xFFF0F9FF);    // Very light blue card surface
  static const _cBorder = Color(0xFFBFDBFE);     // Light blue border
  static const _cText = Color(0xFF000000);        // Solid black primary text
  static const _cSecText = Color(0xFF4B5563);    // Dark grey secondary text
  static const _cAccent = Color(0xFF1E40AF);     // Gov blue accent
  static const _cRed = Color(0xFFDC2626);        // Emergency red
  static const _cGreen = Color(0xFF16A34A);      // Success green

  static const _labels = {
    'ms': {
      'welcome': 'Selamat Datang ke\nPusat Pemindahan Sementara',
      'subtitle': 'Sila daftar untuk mendapatkan bantuan',
      'choose_lang': 'Pilih Bahasa',
      'next': 'SETERUSNYA',
      'name': 'Nama Penuh',
      'ic': 'No. Kad Pengenalan',
      'family': 'Bilangan Isi Rumah',
      'needs': 'Keperluan Khas',
      'confirm': 'SAHKAN PENDAFTARAN',
      'done_title': 'Pendaftaran Berjaya!',
      'done_sub': 'Sila tunggu arahan pegawai',
    },
    'en': {
      'welcome': 'Welcome to\nRelief Centre (PPS)',
      'subtitle': 'Please register to receive aid',
      'choose_lang': 'Choose Language',
      'next': 'NEXT',
      'name': 'Full Name',
      'ic': 'IC / Passport Number',
      'family': 'Number of Family Members',
      'needs': 'Special Needs',
      'confirm': 'CONFIRM REGISTRATION',
      'done_title': 'Registration Successful!',
      'done_sub': 'Please await officer instructions',
    },
    'zh': {
      'welcome': '欢迎来到\n疏散临时安置中心',
      'subtitle': '请登记以获取援助',
      'choose_lang': '选择语言',
      'next': '下一步',
      'name': '姓名',
      'ic': '身份证号码',
      'family': '家庭人数',
      'needs': '特殊需求',
      'confirm': '确认登记',
      'done_title': '登记成功！',
      'done_sub': '请等待工作人员指示',
    },
    'ta': {
      'welcome': 'நிவாரண மையத்திற்கு\nவரவேற்கிறோம்',
      'subtitle': 'உதவி பெற பதிவு செய்யவும்',
      'choose_lang': 'மொழி தேர்வு',
      'next': 'அடுத்து',
      'name': 'முழு பெயர்',
      'ic': 'அடையாள அட்டை எண்',
      'family': 'குடும்ப உறுப்பினர்கள்',
      'needs': 'சிறப்பு தேவைகள்',
      'confirm': 'பதிவை உறுதிப்படுத்தவும்',
      'done_title': 'பதிவு வெற்றிகரமாக!',
      'done_sub': 'அதிகாரியின் அறிவுறுத்தலை கவனிக்கவும்',
    },
  };

  String _t(String key) => _labels[_lang]?[key] ?? key;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == _KioskStep.language || _step == _KioskStep.done,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step != _KioskStep.done) {
          setState(() {
            if (_step == _KioskStep.confirm) { _step = _KioskStep.family; }
            else if (_step == _KioskStep.family) { _step = _KioskStep.scan; }
            else if (_step == _KioskStep.scan) { _step = _KioskStep.language; }
          });
        }
      },
      child: Scaffold(
        backgroundColor: _cBg,
        body: SafeArea(
          child: Column(children: [
            _buildKioskHeader(),
            Expanded(child: _buildStep()),
          ]),
        ),
      ),
    );
  }

  Widget _buildKioskHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: _cBg,
        border: Border(bottom: BorderSide(color: _cBorder, width: 1.5)),
      ),
      child: Row(children: [
        // Red cross icon with light bg
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.local_hospital, color: _cRed, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('FloodSense PPS Kiosk',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 20, color: _cText)),
            ),
            Text(
              _step != _KioskStep.language
                  ? 'PPS ${_lang.toUpperCase()} — Langkah ${_step.index}/${_KioskStep.values.length - 2}'
                  : 'Sistem Pendaftaran Digital',
              style: const TextStyle(color: _cSecText, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
        // Step indicator dots (hidden on small screens, or scaled)
        if (_step != _KioskStep.language && _step != _KioskStep.done) ...[
          const SizedBox(width: 8),
          ...List.generate(3, (i) {
            final idx = i + 1;
            final current = _step.index;
            return Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: current > idx
                    ? _cGreen
                    : current == idx
                        ? _cAccent
                        : _cBorder,
              ),
            );
          }),
        ],
        const SizedBox(width: 8),
        if (_step != _KioskStep.language && _step != _KioskStep.done)
          IconButton(
            onPressed: () => setState(() => _step = _KioskStep.language),
            icon: const Icon(Icons.refresh, color: _cSecText, size: 22),
            tooltip: 'Restart',
          ),
      ]),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _KioskStep.language:
        return _buildLanguageStep();
      case _KioskStep.scan:
        return _buildScanStep();
      case _KioskStep.family:
        return _buildFamilyStep();
      case _KioskStep.confirm:
        return _buildConfirmStep();
      case _KioskStep.done:
        return _buildDoneStep();
    }
  }

  // ── Step 0: Language Selection ────────────────────────────────────────────
  Widget _buildLanguageStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.language, color: _cRed, size: 48),
        ),
        const SizedBox(height: 24),
        const Text('FloodSense PPS Kiosk',
            style: TextStyle(
                fontSize: 32, fontWeight: FontWeight.w900, color: _cText)),
        const SizedBox(height: 8),
        const Text(
          'Sistem Pendaftaran Bantuan Banjir\nFlood Relief Registration System',
          textAlign: TextAlign.center,
          style: TextStyle(color: _cSecText, fontSize: 16),
        ),
        const SizedBox(height: 40),
        Text(_t('choose_lang'),
            style: const TextStyle(
                color: _cSecText, fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.w600)),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            _langButton('ms', 'Bahasa Melayu'),
            _langButton('en', 'English'),
            _langButton('zh', '中文'),
            _langButton('ta', 'தமிழ்'),
          ],
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _langButton(String lang, String label) {
    return SizedBox(
      width: 150,
      height: 72,
      child: ElevatedButton(
        onPressed: () => setState(() {
          _lang = lang;
          _step = _KioskStep.scan;
        }),
        style: ElevatedButton.styleFrom(
          backgroundColor: _cSurface,
          foregroundColor: _cText,
          elevation: 0,
          side: const BorderSide(color: _cBorder, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min, children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: _cText)),
          ),
        ]),
      ),
    );
  }

  // ── Step 1: Identity Scan ─────────────────────────────────────────────────
  Widget _buildScanStep() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Scanning MyKad... / Mengimbas MyKad...')));
              Future.delayed(const Duration(milliseconds: 800), () {
                if (!mounted) return;
                setState(() {
                  _nameCtrl.text = 'Ahmad bin Abdullah';
                  _icCtrl.text = '890101-14-5531';
                });
              });
            },
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: _cRed.withAlpha(40), blurRadius: 12, spreadRadius: 2)],
              ),
              child: const Icon(Icons.badge, color: _cRed, size: 40),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Tap Icon to Auto-Scan MyKad (Demo)', 
              style: TextStyle(color: _cRed, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          Text(_t('name'),
              style: const TextStyle(
                  color: _cSecText, fontSize: 18, letterSpacing: 1, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          _kioskField(_nameCtrl, _t('name'), Icons.person),
          const SizedBox(height: 20),
          Text(_t('ic'),
              style: const TextStyle(
                  color: _cSecText, fontSize: 18, letterSpacing: 1, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          _kioskField(_icCtrl, _t('ic'), Icons.credit_card,
              keyboardType: TextInputType.number),
          const SizedBox(height: 40),
          Row(children: [
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 60,
                child: OutlinedButton(
                  onPressed: () => setState(() => _step = _KioskStep.language),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _cSecText,
                    side: const BorderSide(color: _cBorder, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Batal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _bigButton(_t('next'), () {
                if (_nameCtrl.text.trim().isNotEmpty) {
                  setState(() => _step = _KioskStep.family);
                }
              }),
            ),
          ]),
        ]),
        ),
      ),
    );
  }

  // ── Step 2: Family Size ───────────────────────────────────────────────────
  Widget _buildFamilyStep() {
    const needsList = [
      'wheelchair',
      'elderly',
      'infant',
      'oxygen',
      'dialysis',
      'blind_deaf'
    ];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(_t('family'),
              style: const TextStyle(
                  color: _cSecText, fontSize: 18, letterSpacing: 1, fontWeight: FontWeight.w600)),
          const SizedBox(height: 32),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _circleBtn(Icons.remove, () {
              if (_familySize > 1) setState(() => _familySize--);
            }),
            const SizedBox(width: 24),
            Text('$_familySize',
                style: const TextStyle(
                    fontSize: 56, fontWeight: FontWeight.w900, color: _cText)),
            const SizedBox(width: 24),
            _circleBtn(Icons.add, () => setState(() => _familySize++)),
          ]),
          const SizedBox(height: 40),
          Text(_t('needs'),
              style: const TextStyle(
                  color: _cSecText, fontSize: 18, letterSpacing: 1, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: needsList.map((n) {
              final on = _needs.contains(n);
              return GestureDetector(
                onTap: () =>
                    setState(() => on ? _needs.remove(n) : _needs.add(n)),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    // Light teal card when selected; light blue otherwise
                    color: on
                        ? const Color(0xFFCCFBF1)
                        : _cSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: on ? const Color(0xFF0D9488) : _cBorder,
                        width: 2),
                  ),
                  child: Text(n,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: on ? const Color(0xFF0D9488) : _cText)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          Row(children: [
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 60,
                child: OutlinedButton(
                  onPressed: () => setState(() => _step = _KioskStep.scan),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _cSecText,
                    side: const BorderSide(color: _cBorder, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Batal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _bigButton(_t('next'), () => setState(() => _step = _KioskStep.confirm)),
            ),
          ]),
        ]),
        ),
      ),
    );
  }

  // ── Step 3: Confirm ───────────────────────────────────────────────────────
  Widget _buildConfirmStep() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.check_circle_outline, color: _cGreen, size: 44),
          ),
          const SizedBox(height: 24),
          // Confirmation card: white bg, black labels, dark grey values
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: _cSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _cBorder, width: 1.5)),
            child: Column(children: [
              _confirmRow(_t('name'), _nameCtrl.text),
              _confirmRow(
                  'IC',
                  _icCtrl.text.isNotEmpty
                      ? '**** **** ${_icCtrl.text.substring(_icCtrl.text.length > 4 ? _icCtrl.text.length - 4 : 0)}'
                      : '—'),
              _confirmRow(_t('family'), '$_familySize orang'),
              if (_needs.isNotEmpty)
                _confirmRow(_t('needs'), _needs.join(', ')),
            ]),
          ),
          const SizedBox(height: 32),
          Row(children: [
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 60,
                child: OutlinedButton(
                  onPressed: () => setState(() => _step = _KioskStep.family),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _cSecText,
                    side: const BorderSide(color: _cBorder, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Batal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _bigButton(_t('confirm'), _submit, color: _cGreen),
            ),
          ]),
        ]),
        ),
      ),
    );
  }

  /// Each row: label (dark grey) on left, value (solid black) on right
  Widget _confirmRow(String label, String val) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Text('$label  ',
                style: const TextStyle(color: _cSecText, fontSize: 16)),
            Expanded(
              child: Text(
                val,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: _cText, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );

  // ── Step 4: Done ──────────────────────────────────────────────────────────
  Widget _buildDoneStep() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 120,
          height: 120,
          decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7), shape: BoxShape.circle),
          child: const Icon(Icons.check_circle, color: _cGreen, size: 80),
        ),
        const SizedBox(height: 32),
        Text(_t('done_title'),
            style: const TextStyle(
                fontSize: 36, fontWeight: FontWeight.w900, color: _cText)),
        const SizedBox(height: 16),
        Text(_t('done_sub'),
            style: const TextStyle(fontSize: 18, color: _cSecText)),
        const SizedBox(height: 24),
        if (_receiptId != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
                color: _cSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _cBorder, width: 1.5)),
            child: Column(children: [
              const Text('ID Pendaftaran / Registration ID',
                  style: TextStyle(color: _cSecText, fontSize: 13)),
              const SizedBox(height: 4),
              Text(_receiptId!,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _cAccent,
                      letterSpacing: 2)),
            ]),
          ),
          const SizedBox(height: 16),
          const Text('Simpan ID ini untuk rujukan / Save this ID for reference',
              style: TextStyle(color: _cSecText, fontSize: 13)),
        ],
        const SizedBox(height: 48),
        SizedBox(
          width: 300,
          height: 64,
          child: OutlinedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh, color: _cAccent),
            label: const Text('Pendaftaran Baharu / New Registration',
                style: TextStyle(fontSize: 15, color: _cAccent)),
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _cAccent, width: 1.5)),
          ),
        ),
      ]),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _kioskField(TextEditingController c, String hint, IconData icon,
      {TextInputType? keyboardType}) =>
      TextField(
        controller: c,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 20, color: _cText),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _cSecText, fontSize: 18),
          prefixIcon: Icon(icon, color: _cAccent, size: 28),
          filled: true,
          fillColor: _cSurface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _cBorder, width: 1.5)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _cBorder, width: 1.5)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _cAccent, width: 2)),
        ),
      );

  Widget _bigButton(String label, VoidCallback onTap,
      {Color color = _cRed}) =>
      SizedBox(
        width: double.infinity,
        height: 60,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1),
          ),
          child: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
        ),
      );

  Widget _circleBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
              color: _cSurface,
              shape: BoxShape.circle,
              border: Border.all(color: _cBorder, width: 2)),
          child: Icon(icon, color: _cText, size: 30),
        ),
      );

  Future<void> _submit() async {
    try {
      final id =
          'PPS-${DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase()}';
      await FirebaseFirestore.instance.collection('pps_registrations').doc(id).set({
        'registration_id': id,
        'name': _nameCtrl.text.trim(),
        'ic_last4': _icCtrl.text.length >= 4
            ? _icCtrl.text.substring(_icCtrl.text.length - 4)
            : _icCtrl.text,
        'family_size': _familySize,
        'special_needs': _needs.toList(),
        'language': _lang,
        'pps_id': 'PPS_001', // Maps to "Stadium Shah Alam" in GovPPSScreen — must match exactly
        'registered_at': FieldValue.serverTimestamp(),
      });
      setState(() {
        _receiptId = id.substring(0, 12);
        _step = _KioskStep.done;
      });
    } catch (_) {
      setState(() => _step = _KioskStep.done);
    }
  }

  void _reset() {
    _nameCtrl.clear();
    _icCtrl.clear();
    setState(() {
      _step = _KioskStep.language;
      _familySize = 1;
      _needs.clear();
      _receiptId = null;
    });
  }
}
