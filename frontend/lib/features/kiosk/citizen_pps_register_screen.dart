import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/locale_provider.dart';

// ── Citizen PPS Registration Screen ───────────────────────────────────────────
// Allows a citizen to register themselves at a PPS (relief centre) by:
// 1. Entering their name & IC
// 2. Selecting the nearest kiosk/PPS based on GPS
// 3. Submitting to Firestore (synced live to the officer's dashboard)

class CitizenPPSRegisterScreen extends StatefulWidget {
  final String userName;
  const CitizenPPSRegisterScreen({super.key, required this.userName});
  @override
  State<CitizenPPSRegisterScreen> createState() => _CitizenPPSRegisterScreenState();
}

// ── Static PPS data (matches gov_pps_screen.dart and pps_kiosk_screen.dart) ──
class _PPSInfo {
  final String id, name, address;
  final double lat, lng;
  const _PPSInfo({required this.id, required this.name, required this.address, required this.lat, required this.lng});
}

// Nationwide PPS dataset — mirrors citizen_home_screen.dart, covers all states
const _ppsList = [
  // SELANGOR
  _PPSInfo(id: 'PPS_001', name: 'Stadium Shah Alam',              address: 'Seksyen 13, Shah Alam, Selangor',             lat: 3.0860, lng: 101.5145),
  _PPSInfo(id: 'PPS_002', name: 'Kompleks Sukan Klang',           address: 'Jalan Kawasan 16, Klang, Selangor',           lat: 3.0413, lng: 101.4437),
  _PPSInfo(id: 'PPS_003', name: 'MBSA Dewan Sri Andalan',         address: 'Seksyen 19, Shah Alam, Selangor',             lat: 3.0627, lng: 101.5322),
  _PPSInfo(id: 'PPS_004', name: 'Stadium MBPJ Petaling Jaya',     address: 'Jalan Kelang Lama, Petaling Jaya',            lat: 3.1063, lng: 101.6359),
  _PPSInfo(id: 'PPS_005', name: 'Dewan Besar MPK Klang',          address: 'Jalan Meru, Klang, Selangor',                 lat: 3.0559, lng: 101.4548),
  // KUALA LUMPUR
  _PPSInfo(id: 'PPS_006', name: 'Dewan Sivik DBKL',               address: 'Jalan Raja Laut, Kuala Lumpur',               lat: 3.1577, lng: 101.6986),
  _PPSInfo(id: 'PPS_007', name: 'Stadium Titiwangsa',              address: 'Jalan Pahang, Titiwangsa, KL',                lat: 3.1784, lng: 101.7073),
  // JOHOR
  _PPSInfo(id: 'PPS_008', name: 'Stadium Larkin Johor Bahru',     address: 'Jalan Garuda, Larkin, JB',                    lat: 1.4927, lng: 103.7401),
  _PPSInfo(id: 'PPS_009', name: 'Dewan Jubli Perak Batu Pahat',   address: 'Jalan Rahmat, Batu Pahat, Johor',             lat: 1.8556, lng: 102.9341),
  _PPSInfo(id: 'PPS_010', name: 'Stadium Kluang',                  address: 'Jalan Genuang, Kluang, Johor',                lat: 2.0274, lng: 103.3197),
  _PPSInfo(id: 'PPS_011', name: 'Dewan Orang Ramai Muar',         address: 'Jalan Haji Abu, Muar, Johor',                 lat: 2.0442, lng: 102.5689),
  // PERAK
  _PPSInfo(id: 'PPS_012', name: 'Stadium Perak Ipoh',              address: 'Jalan Stadium, Ipoh, Perak',                  lat: 4.6033, lng: 101.0829),
  _PPSInfo(id: 'PPS_013', name: 'Dewan Besar MPTI Taiping',       address: 'Jalan Barrack, Taiping, Perak',               lat: 4.8534, lng: 100.7326),
  _PPSInfo(id: 'PPS_014', name: 'Stadium Sungai Siput',            address: 'Jalan Besar, Sungai Siput, Perak',            lat: 4.8435, lng: 101.0605),
  // KEDAH
  _PPSInfo(id: 'PPS_015', name: 'Stadium Darulaman Alor Setar',   address: 'Jalan Stadium, Alor Setar, Kedah',            lat: 6.1248, lng: 100.3673),
  _PPSInfo(id: 'PPS_016', name: 'Dewan MPSAS Sungai Petani',      address: 'Jalan Stadium, Sungai Petani, Kedah',         lat: 5.6479, lng: 100.4895),
  // KELANTAN
  _PPSInfo(id: 'PPS_017', name: 'Stadium Sultan Muhammad IV KB',  address: 'Jalan Hamzah, Kota Bharu, Kelantan',          lat: 6.1254, lng: 102.2380),
  _PPSInfo(id: 'PPS_018', name: 'Dewan Besar MPGK Gua Musang',    address: 'Jalan Hamid, Gua Musang, Kelantan',           lat: 4.8819, lng: 101.9644),
  // TERENGGANU
  _PPSInfo(id: 'PPS_019', name: 'Stadium Sultan Mizan KT',         address: 'Jalan Sultan Mahmud, Kuala Terengganu',       lat: 5.3296, lng: 103.1370),
  _PPSInfo(id: 'PPS_020', name: 'Dewan Besar MPKK Kemaman',       address: 'Jalan Haji Kamarudin, Kemaman',               lat: 4.2332, lng: 103.4194),
  // PAHANG
  _PPSInfo(id: 'PPS_021', name: 'Stadium Darul Makmur Kuantan',   address: 'Jalan Stadium, Kuantan, Pahang',              lat: 3.8185, lng: 103.3252),
  _PPSInfo(id: 'PPS_022', name: 'Dewan Besar MPTN Temerloh',      address: 'Jalan Tengku Hussain, Temerloh, Pahang',      lat: 3.4516, lng: 102.4184),
  // NEGERI SEMBILAN
  _PPSInfo(id: 'PPS_023', name: 'Stadium Tuanku Abdul Halim',     address: 'Jalan Sungai Ujong, Seremban, NS',            lat: 2.7297, lng: 101.9381),
  _PPSInfo(id: 'PPS_024', name: 'Dewan Orang Ramai Port Dickson', address: 'Jalan Pantai, Port Dickson, NS',               lat: 2.5228, lng: 101.7957),
  // MELAKA
  _PPSInfo(id: 'PPS_025', name: 'Stadium Hang Jebat Melaka',      address: 'Jalan Lundang, Melaka Tengah',                lat: 2.2016, lng: 102.2548),
  _PPSInfo(id: 'PPS_026', name: 'Dewan Besar MBJB Jasin',         address: 'Jalan Hj Mohd Zahid, Jasin, Melaka',          lat: 2.3087, lng: 102.4374),
  // PENANG
  _PPSInfo(id: 'PPS_027', name: 'Stadium MBPP Penang',             address: 'Jalan Bagan Jermal, Penang',                  lat: 5.4098, lng: 100.3291),
  _PPSInfo(id: 'PPS_028', name: 'Dewan Serbaguna Seberang Jaya',  address: 'Jalan Perak, Seberang Jaya, Penang',          lat: 5.3991, lng: 100.3983),
  // SABAH
  _PPSInfo(id: 'PPS_029', name: 'Stadium Likas Kota Kinabalu',    address: 'Jalan Kolam, Likas, Kota Kinabalu',           lat: 5.9970, lng: 116.1121),
  _PPSInfo(id: 'PPS_030', name: 'Dewan Bandaran Sandakan',         address: 'Jalan Pryer, Sandakan, Sabah',                lat: 5.8402, lng: 118.1179),
  _PPSInfo(id: 'PPS_031', name: 'Pusat Komuniti Keningau',         address: 'Jalan Apin-Apin, Keningau, Sabah',            lat: 5.3379, lng: 116.1624),
  // SARAWAK
  _PPSInfo(id: 'PPS_032', name: 'Stadium Negeri Sarawak Kuching', address: 'Jalan Bako, Petra Jaya, Kuching',             lat: 1.5596, lng: 110.3544),
  _PPSInfo(id: 'PPS_033', name: 'Stadium Sarawak Sibu',            address: 'Jalan Tun Abang Haji Openg, Sibu',            lat: 2.2936, lng: 111.8189),
  _PPSInfo(id: 'PPS_034', name: 'Pusat Bandaran Miri',             address: 'Jalan Kipas, Miri, Sarawak',                  lat: 4.3995, lng: 113.9914),
  // PERLIS
  _PPSInfo(id: 'PPS_035', name: 'Dewan Besar MPKK Kangar',        address: 'Jalan Hospital, Kangar, Perlis',               lat: 6.4414, lng: 100.1986),
  // PUTRAJAYA
  _PPSInfo(id: 'PPS_036', name: 'Pusat Komuniti Presint 11',       address: 'Presint 11, Putrajaya',                       lat: 2.9249, lng: 101.6841),
  // LABUAN
  _PPSInfo(id: 'PPS_037', name: 'Stadium Labuan',                  address: 'Jalan Batu Manikar, Labuan',                  lat: 5.2769, lng: 115.2389),
];

double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLon = (lon2 - lon1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

class _CitizenPPSRegisterScreenState extends State<CitizenPPSRegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _icCtrl = TextEditingController();
  int _familySize = 1;
  final Set<String> _needs = {};
  _PPSInfo? _selectedPPS;
  bool _locating = false;
  bool _submitting = false;
  bool _submitted = false;
  String? _registrationId;
  double? _userLat, _userLng;

  /// Always returns the 5 closest PPS stations, sorted nearest → farthest.
  List<(_PPSInfo, double?)> get _sortedPPS {
    if (_userLat == null || _userLng == null) {
      return _ppsList.take(5).map((p) => (p, null)).toList();
    }
    final withDist = _ppsList.map((p) {
      final d = _haversineKm(_userLat!, _userLng!, p.lat, p.lng);
      return (p, d as double?);
    }).toList()
      ..sort((a, b) => (a.$2 ?? 99999).compareTo(b.$2 ?? 99999));
    // Top 5 only
    return withDist.take(5).toList();
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.userName;
    _locateUser();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _icCtrl.dispose();
    super.dispose();
  }

  Future<void> _locateUser() async {
    setState(() => _locating = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 8)),
      );
      if (!mounted) return;
      setState(() {
        _userLat = pos.latitude;
        _userLng = pos.longitude;
        // Auto-select nearest PPS
        if (_selectedPPS == null && _sortedPPS.isNotEmpty) {
          _selectedPPS = _sortedPPS.first.$1;
        }
      });
    } catch (_) {
      // GPS failed silently — user can still pick manually
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _submit() async {
    final isMs = Provider.of<LocaleProvider>(context, listen: false).locale.languageCode == 'ms';
    if (_nameCtrl.text.trim().isEmpty) {
      _showError(isMs ? 'Sila masukkan nama penuh anda.' : 'Please enter your full name.');
      return;
    }
    if (_icCtrl.text.trim().isEmpty) {
      _showError(isMs ? 'Sila masukkan nombor Kad Pengenalan/Pasport anda.' : 'Please enter your IC or Passport number.');
      return;
    }
    if (_selectedPPS == null) {
      _showError(isMs ? 'Sila pilih pusat pemindahan (PPS).' : 'Please select a PPS / relief centre.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final id = 'PPS-${DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase()}';
      await FirebaseFirestore.instance.collection('pps_registrations').doc(id).set({
        'registration_id': id,
        'name': _nameCtrl.text.trim(),
        'ic_last4': _icCtrl.text.trim().length >= 4
            ? _icCtrl.text.trim().substring(_icCtrl.text.trim().length - 4)
            : _icCtrl.text.trim(),
        'family_size': _familySize,
        'special_needs': _needs.toList(),
        'language': 'en',
        'pps_id': _selectedPPS!.id,
        'pps_name': _selectedPPS!.name,
        'registered_at': FieldValue.serverTimestamp(),
        'registered_via': 'citizen_app',
      });
      if (mounted) {
        setState(() {
          _submitted = true;
          _registrationId = id.substring(0, 12);
        });
      }
    } catch (e) {
      if (mounted) _showError('Registration failed. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.emergency),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMs = context.watch<LocaleProvider>().locale.languageCode == 'ms';
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isMs ? 'Daftar di Pusat Pemindahan' : 'Register at Relief Centre',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE5E7EB)),
        ),
      ),
      body: _submitted ? _buildSuccessView(isMs) : _buildForm(isMs),
    );
  }

  // ── Success view ────────────────────────────────────────────────────────────
  Widget _buildSuccessView(bool isMs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 100, height: 100,
            decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle, color: AppTheme.hope, size: 60),
          ),
          const SizedBox(height: 24),
          Text(isMs ? 'Pendaftaran Dihantar!' : 'Registration Submitted!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.black)),
          const SizedBox(height: 8),
          Text(isMs ? 'Anda telah didaftarkan di\n${_selectedPPS!.name}' : 'You are registered at\n${_selectedPPS!.name}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15, height: 1.5)),
          const SizedBox(height: 24),
          if (_registrationId != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border)),
              child: Column(children: [
                Text(isMs ? 'ID Pendaftaran' : 'Registration ID', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                const SizedBox(height: 4),
                Text(_registrationId!,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20,
                        color: AppTheme.govBlue, letterSpacing: 2)),
              ]),
            ),
            const SizedBox(height: 8),
            Text(isMs ? 'Simpan ID ini untuk rujukan. Pegawai di PPS telah dimaklumkan.' : 'Save this ID for reference. Officers at the PPS have been notified.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.home_outlined),
              label: Text(isMs ? 'Kembali ke Laman Utama' : 'Back to Home', style: const TextStyle(fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.govBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Registration form ───────────────────────────────────────────────────────
  Widget _buildForm(bool isMs) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Info banner ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.govBlue.withAlpha(60))),
          child: Row(children: [
            const Icon(Icons.info_outline, color: AppTheme.govBlue, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(
              isMs ? 'Daftar di sini untuk memaklumkan ketibaan anda. Data anda disegerakkan secara langsung ke papan pemuka pegawai.' : 'Register here to notify the relief centre authorities of your arrival. Your data is synced live to the officer dashboard.',
              style: const TextStyle(color: AppTheme.govBlue, fontSize: 12, height: 1.5),
            )),
          ]),
        ),
        const SizedBox(height: 24),

        // ── Personal info ────────────────────────────────────────────────────
        _FormLabel(label: isMs ? 'Maklumat Peribadi' : 'Personal Information'),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _nameCtrl,
          label: isMs ? 'Nama Penuh' : 'Full Name',
          hint: 'e.g. Ahmad bin Abdullah',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _icCtrl,
          label: isMs ? 'Nombor Kad Pengenalan' : 'IC / Passport Number',
          hint: 'e.g. 890101-14-5531',
          icon: Icons.credit_card_outlined,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 24),

        // ── Family size ──────────────────────────────────────────────────────
        _FormLabel(label: isMs ? 'Bilangan Ahli Keluarga' : 'Number of Family Members'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _CircleBtn(icon: Icons.remove, onTap: () { if (_familySize > 1) setState(() => _familySize--); }),
            const SizedBox(width: 24),
            Column(children: [
              Text('$_familySize', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.black)),
              Text(isMs ? 'orang' : 'person(s)', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            ]),
            const SizedBox(width: 24),
            _CircleBtn(icon: Icons.add, onTap: () => setState(() => _familySize++)),
          ]),
        ),
        const SizedBox(height: 24),

        // ── Special needs ────────────────────────────────────────────────────
        _FormLabel(label: isMs ? 'Keperluan Khas (tekan untuk pilih)' : 'Special Needs (tap to select)'),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          isMs ? 'Kerusi Roda' : 'Wheelchair', 
          isMs ? 'Warga Emas' : 'Elderly', 
          isMs ? 'Bayi' : 'Infant / Baby', 
          isMs ? 'Oksigen' : 'Oxygen',
          isMs ? 'Dialisis' : 'Dialysis', 
          isMs ? 'Masalah Penglihatan' : 'Visually Impaired', 
          isMs ? 'Masalah Pendengaran' : 'Hearing Impaired',
        ].map((need) {
          final on = _needs.contains(need);
          return GestureDetector(
            onTap: () => setState(() => on ? _needs.remove(need) : _needs.add(need)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: on ? AppTheme.govBlue : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: on ? AppTheme.govBlue : AppTheme.border),
              ),
              child: Text(need,
                  style: TextStyle(
                      color: on ? Colors.white : AppTheme.textSecondary,
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          );
        }).toList()),
        const SizedBox(height: 24),

        // ── PPS / Kiosk selection ────────────────────────────────────────────
        Row(children: [
          _FormLabel(label: isMs ? 'Pilih Pusat Pemindahan (PPS)' : 'Select Relief Centre (PPS)'),
          const Spacer(),
          if (_locating)
            Row(children: [
              const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 6),
              Text(isMs ? 'Mengesan...' : 'Finding location...', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ])
          else if (_userLat != null)
            GestureDetector(
              onTap: _locateUser,
              child: Row(children: [
                const Icon(Icons.my_location, color: AppTheme.govBlue, size: 14),
                const SizedBox(width: 4),
                Text(isMs ? 'Disusun ikut jarak' : 'Sorted by distance', style: const TextStyle(color: AppTheme.govBlue, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            )
          else
            GestureDetector(
              onTap: _locateUser,
              child: Row(children: [
                const Icon(Icons.location_searching, color: AppTheme.textMuted, size: 14),
                const SizedBox(width: 4),
                Text(isMs ? 'Guna lokasi saya' : 'Use my location', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ]),
            ),
        ]),
        const SizedBox(height: 12),
        ..._sortedPPS.map((entry) {
          final (pps, distKm) = entry;
          final isSelected = _selectedPPS?.id == pps.id;
          return GestureDetector(
            onTap: () => setState(() => _selectedPPS = pps),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.govBlue.withAlpha(10) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: isSelected ? AppTheme.govBlue : AppTheme.border,
                    width: isSelected ? 2 : 1),
              ),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.govBlue : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.location_city_outlined,
                      color: isSelected ? Colors.white : AppTheme.textMuted, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(pps.name,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isSelected ? AppTheme.govBlue : Colors.black)),
                  const SizedBox(height: 2),
                  Text(pps.address,
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  if (distKm != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: isSelected ? AppTheme.govBlue.withAlpha(20) : AppTheme.border.withAlpha(60),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('${distKm.toStringAsFixed(1)} km',
                          style: TextStyle(
                              color: isSelected ? AppTheme.govBlue : AppTheme.textSecondary,
                              fontWeight: FontWeight.w700, fontSize: 11)),
                    ),
                  if (isSelected) ...[
                    const SizedBox(height: 4),
                    const Icon(Icons.check_circle, color: AppTheme.govBlue, size: 16),
                  ],
                ]),
              ]),
            ),
          );
        }),
        const SizedBox(height: 28),

        // ── Submit button ────────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.how_to_reg_outlined),
            label: Text(_submitting ? (isMs ? 'Menghantar...' : 'Submitting...') : (isMs ? 'Daftar di PPS' : 'Register at PPS'),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.govBlue,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            isMs ? 'Pendaftaran anda akan dipaparkan terus kepada pegawai bertugas di PPS.' : 'Your registration is instantly visible to officers at the relief centre.',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.black, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.govBlue, size: 20),
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: AppTheme.textSecondary),
        hintStyle: const TextStyle(color: AppTheme.textMuted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.govBlue, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _FormLabel extends StatelessWidget {
  final String label;
  const _FormLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
          color: AppTheme.textMuted, letterSpacing: 0.3));
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
          color: Colors.white, shape: BoxShape.circle,
          border: Border.all(color: AppTheme.border, width: 2)),
      child: Icon(icon, color: Colors.black, size: 22),
    ),
  );
}
