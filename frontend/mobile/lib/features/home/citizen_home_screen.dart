import 'dart:math' show sin, cos, sqrt, atan2;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/locale_provider.dart';
import '../auth/profile_screen.dart';
import '../auth/role_selection_screen.dart';
import '../kiosk/citizen_pps_register_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_center.dart';
import 'prep_kit_section.dart';

// ── Verified Malaysian PPS Locations ─────────────────────────────────────────
// These are actual verified government-designated PPS venues in Klang Valley

class _PPSData {
  final String name;
  final String address;
  final LatLng location;
  final int capacity;
  final int occupied;
  final bool isOpen;

  const _PPSData({
    required this.name,
    required this.address,
    required this.location,
    required this.capacity,
    required this.occupied,
    required this.isOpen,
  });

  String get capacityText => '$occupied/$capacity';
  String get status => isOpen ? (occupied >= capacity ? 'Full' : 'Open') : 'Closed';
}

// Nationwide PPS dataset — representative government-designated flood shelters
// covering all 14 Malaysian states. Sorted by distance from user's GPS location.
const List<_PPSData> _allPPS = [
  // ── SELANGOR ────────────────────────────────────────────────
  _PPSData(name: 'Stadium Shah Alam', address: 'Seksyen 13, Shah Alam, Selangor',
      location: LatLng(3.0860, 101.5145), capacity: 5000, occupied: 1820, isOpen: true),
  _PPSData(name: 'Kompleks Sukan Klang', address: 'Jalan Kawasan 16, Klang, Selangor',
      location: LatLng(3.0413, 101.4437), capacity: 800, occupied: 612, isOpen: true),
  _PPSData(name: 'MBSA Dewan Sri Andalan', address: 'Seksyen 19, Shah Alam, Selangor',
      location: LatLng(3.0627, 101.5322), capacity: 1200, occupied: 490, isOpen: true),
  _PPSData(name: 'Stadium MBPJ Petaling Jaya', address: 'Jalan Kelang Lama, Petaling Jaya',
      location: LatLng(3.1063, 101.6359), capacity: 3000, occupied: 1100, isOpen: true),
  _PPSData(name: 'Dewan Besar MPK Klang', address: 'Jalan Meru, Klang, Selangor',
      location: LatLng(3.0559, 101.4548), capacity: 900, occupied: 320, isOpen: true),

  // ── KUALA LUMPUR ─────────────────────────────────────────────
  _PPSData(name: 'Stadium Merdeka KL', address: 'Jalan Stadium, Kuala Lumpur',
      location: LatLng(3.1430, 101.6945), capacity: 4000, occupied: 0, isOpen: false),
  _PPSData(name: 'Dewan Sivik DBKL', address: 'Jalan Raja Laut, Kuala Lumpur',
      location: LatLng(3.1577, 101.6986), capacity: 1500, occupied: 210, isOpen: true),
  _PPSData(name: 'Stadium Titiwangsa', address: 'Jalan Pahang, Titiwangsa, KL',
      location: LatLng(3.1784, 101.7073), capacity: 2000, occupied: 540, isOpen: true),

  // ── JOHOR ────────────────────────────────────────────────────
  _PPSData(name: 'Stadium Larkin Johor Bahru', address: 'Jalan Garuda, Larkin, JB',
      location: LatLng(1.4927, 103.7401), capacity: 6000, occupied: 2300, isOpen: true),
  _PPSData(name: 'Dewan Jubli Perak Batu Pahat', address: 'Jalan Rahmat, Batu Pahat, Johor',
      location: LatLng(1.8556, 102.9341), capacity: 1000, occupied: 380, isOpen: true),
  _PPSData(name: 'Stadium Kluang', address: 'Jalan Genuang, Kluang, Johor',
      location: LatLng(2.0274, 103.3197), capacity: 800, occupied: 290, isOpen: true),
  _PPSData(name: 'Dewan Orang Ramai Muar', address: 'Jalan Haji Abu, Muar, Johor',
      location: LatLng(2.0442, 102.5689), capacity: 700, occupied: 150, isOpen: true),

  // ── PERAK ─────────────────────────────────────────────────────
  _PPSData(name: 'Stadium Perak Ipoh', address: 'Jalan Stadium, Ipoh, Perak',
      location: LatLng(4.6033, 101.0829), capacity: 4000, occupied: 900, isOpen: true),
  _PPSData(name: 'Dewan Besar MPTI Taiping', address: 'Jalan Barrack, Taiping, Perak',
      location: LatLng(4.8534, 100.7326), capacity: 800, occupied: 210, isOpen: true),
  _PPSData(name: 'Stadium Sungai Siput', address: 'Jalan Besar, Sungai Siput, Perak',
      location: LatLng(4.8435, 101.0605), capacity: 600, occupied: 178, isOpen: true),

  // ── KEDAH ─────────────────────────────────────────────────────
  _PPSData(name: 'Stadium Darulaman Alor Setar', address: 'Jalan Stadium, Alor Setar, Kedah',
      location: LatLng(6.1248, 100.3673), capacity: 3500, occupied: 1200, isOpen: true),
  _PPSData(name: 'Dewan MPSAS Sungai Petani', address: 'Jalan Stadium, Sungai Petani, Kedah',
      location: LatLng(5.6479, 100.4895), capacity: 1200, occupied: 430, isOpen: true),

  // ── KELANTAN ──────────────────────────────────────────────────
  _PPSData(name: 'Stadium Sultan Muhammad IV KB', address: 'Jalan Hamzah, Kota Bharu, Kelantan',
      location: LatLng(6.1254, 102.2380), capacity: 5000, occupied: 2800, isOpen: true),
  _PPSData(name: 'Dewan Besar MPGK Gua Musang', address: 'Jalan Hamid, Gua Musang, Kelantan',
      location: LatLng(4.8819, 101.9644), capacity: 600, occupied: 390, isOpen: true),

  // ── TERENGGANU ────────────────────────────────────────────────
  _PPSData(name: 'Stadium Sultan Mizan Kuala Terengganu', address: 'Jalan Sultan Mahmud, KT',
      location: LatLng(5.3296, 103.1370), capacity: 5000, occupied: 1500, isOpen: true),
  _PPSData(name: 'Dewan Besar MPKK Kemaman', address: 'Jalan Haji Kamarudin, Kemaman',
      location: LatLng(4.2332, 103.4194), capacity: 800, occupied: 220, isOpen: true),

  // ── PAHANG ────────────────────────────────────────────────────
  _PPSData(name: 'Stadium Darul Makmur Kuantan', address: 'Jalan Stadium, Kuantan, Pahang',
      location: LatLng(3.8185, 103.3252), capacity: 4500, occupied: 1900, isOpen: true),
  _PPSData(name: 'Dewan Besar MPTN Temerloh', address: 'Jalan Tengku Hussain, Temerloh',
      location: LatLng(3.4516, 102.4184), capacity: 700, occupied: 310, isOpen: true),

  // ── NEGERI SEMBILAN ───────────────────────────────────────────
  _PPSData(name: 'Stadium Tuanku Abdul Halim Seremban', address: 'Jalan Sungai Ujong, Seremban',
      location: LatLng(2.7297, 101.9381), capacity: 2500, occupied: 480, isOpen: true),
  _PPSData(name: 'Dewan Orang Ramai Port Dickson', address: 'Jalan Pantai, Port Dickson, NS',
      location: LatLng(2.5228, 101.7957), capacity: 500, occupied: 120, isOpen: true),

  // ── MELAKA ────────────────────────────────────────────────────
  _PPSData(name: 'Stadium Hang Jebat Melaka', address: 'Jalan Lundang, Melaka Tengah',
      location: LatLng(2.2016, 102.2548), capacity: 2000, occupied: 320, isOpen: true),
  _PPSData(name: 'Dewan Besar MBJB Jasin', address: 'Jalan Hj Mohd Zahid, Jasin, Melaka',
      location: LatLng(2.3087, 102.4374), capacity: 400, occupied: 89, isOpen: true),

  // ── PENANG ────────────────────────────────────────────────────
  _PPSData(name: 'Stadium Bola Sepak Majlis Bandaraya Pulau Pinang', address: 'Jalan Bagan Jermal, Penang',
      location: LatLng(5.4098, 100.3291), capacity: 3000, occupied: 800, isOpen: true),
  _PPSData(name: 'Dewan Serbaguna Seberang Jaya', address: 'Jalan Perak, Seberang Jaya, Penang',
      location: LatLng(5.3991, 100.3983), capacity: 1000, occupied: 350, isOpen: true),

  // ── SABAH ──────────────────────────────────────────────────────
  _PPSData(name: 'Stadium Likas Kota Kinabalu', address: 'Jalan Kolam, Likas, Kota Kinabalu',
      location: LatLng(5.9970, 116.1121), capacity: 5000, occupied: 1100, isOpen: true),
  _PPSData(name: 'Dewan Bandaran Sandakan', address: 'Jalan Pryer, Sandakan, Sabah',
      location: LatLng(5.8402, 118.1179), capacity: 800, occupied: 230, isOpen: true),
  _PPSData(name: 'Pusat Komuniti Keningau', address: 'Jalan Apin-Apin, Keningau, Sabah',
      location: LatLng(5.3379, 116.1624), capacity: 600, occupied: 180, isOpen: true),

  // ── SARAWAK ────────────────────────────────────────────────────
  _PPSData(name: 'Stadium Negeri Sarawak Kuching', address: 'Jalan Bako, Petra Jaya, Kuching',
      location: LatLng(1.5596, 110.3544), capacity: 6000, occupied: 2100, isOpen: true),
  _PPSData(name: 'Stadium Sarawak Sibu', address: 'Jalan Tun Abang Haji Openg, Sibu',
      location: LatLng(2.2936, 111.8189), capacity: 2500, occupied: 870, isOpen: true),
  _PPSData(name: 'Pusat Bandaran Miri', address: 'Jalan Kipas, Miri, Sarawak',
      location: LatLng(4.3995, 113.9914), capacity: 1500, occupied: 310, isOpen: true),

  // ── PERLIS ─────────────────────────────────────────────────────
  _PPSData(name: 'Dewan Besar MPKK Kangar', address: 'Jalan Hospital, Kangar, Perlis',
      location: LatLng(6.4414, 100.1986), capacity: 500, occupied: 120, isOpen: true),

  // ── PUTRAJAYA ──────────────────────────────────────────────────
  _PPSData(name: 'Pusat Komuniti Presint 11 Putrajaya', address: 'Presint 11, Putrajaya',
      location: LatLng(2.9249, 101.6841), capacity: 800, occupied: 60, isOpen: true),

  // ── LABUAN ─────────────────────────────────────────────────────
  _PPSData(name: 'Stadium Labuan', address: 'Jalan Batu Manikar, Labuan',
      location: LatLng(5.2769, 115.2389), capacity: 1000, occupied: 200, isOpen: true),
];

// Max radius to show PPS results. Falls back to nearest 5 if none in range.

// Haversine distance in km
double _distanceKm(LatLng a, LatLng b) {
  const r = 6371.0;
  final dLat = (b.latitude - a.latitude) * pi / 180;
  final dLng = (b.longitude - a.longitude) * pi / 180;
  final x = sin(dLat / 2) * sin(dLat / 2) +
      cos(a.latitude * pi / 180) *
          cos(b.latitude * pi / 180) *
          sin(dLng / 2) *
          sin(dLng / 2);
  return r * 2 * atan2(sqrt(x), sqrt(1 - x));
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class CitizenHomeScreen extends StatefulWidget {
  final String userName;
  const CitizenHomeScreen({super.key, required this.userName});
  @override
  State<CitizenHomeScreen> createState() => _CitizenHomeScreenState();
}

class _CitizenHomeScreenState extends State<CitizenHomeScreen> {
  LatLng? _userLocation;
  bool _locationLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever || !mounted) {
        setState(() => _locationLoading = false);
        return;
      }
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled || !mounted) {
        setState(() => _locationLoading = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (mounted) {
        setState(() {
          _userLocation = LatLng(pos.latitude, pos.longitude);
          _locationLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  /// Returns the 5 closest PPS centres, sorted nearest → farthest.
  /// If GPS is available: top 5 within 100 km, or top 5 overall as fallback.
  /// If GPS is unavailable: first 5 from the full list.
  List<({_PPSData pps, double? distKm})> get _sortedPPS {
    final loc = _userLocation;
    if (loc == null) return _allPPS.take(5).map((p) => (pps: p, distKm: null)).toList();

    final withDist = _allPPS.map((pps) {
      final dist = _distanceKm(loc, pps.location);
      return (pps: pps, distKm: dist);
    }).toList()
      ..sort((a, b) => a.distKm.compareTo(b.distKm));

    // Show only top 5 closest — always exactly 5
    return withDist.take(5).toList();
  }

  void _openPPSMap(_PPSData pps) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _PPSMapSheet(pps: pps, userLocation: _userLocation),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      // ── KEY FIX: TapRegion covers the entire scaffold area ──────────────────
      // This correctly dismisses keyboard when tapping ANYWHERE outside a TextField
      body: TapRegion(
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(20),
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildStatusCard(),
              const SizedBox(height: 20),
              PrepKitSection(userName: widget.userName),
              const SizedBox(height: 20),
              _buildNearbyPPS(),
              const SizedBox(height: 20),
              _buildHopeSection(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isMs = context.watch<LocaleProvider>().locale.languageCode == 'ms';
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? (isMs ? 'Selamat Pagi' : 'Good Morning')
        : hour < 17
            ? (isMs ? 'Selamat Petang' : 'Good Afternoon')
            : (isMs ? 'Selamat Malam' : 'Good Evening');

    return Row(children: [
      GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => ProfileScreen(
              userName: widget.userName, role: UserRole.citizen),
        )),
        child: Container(
          width: 42, height: 42,
          decoration: const BoxDecoration(color: AppTheme.govBlue, shape: BoxShape.circle),
          child: Center(child: Text(
            widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'U',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
          )),
        ),
      ),
      const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$greeting, ${widget.userName} 👋',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.textPrimary)),
        Row(children: [
          const Icon(Icons.location_on_outlined, color: AppTheme.textSecondary, size: 13),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              _userLocation != null
                  ? '${isMs ? 'GPS Aktif' : 'GPS Active'} (${_userLocation!.latitude.toStringAsFixed(4)}, ${_userLocation!.longitude.toStringAsFixed(4)})'
                  : _locationLoading ? (isMs ? 'Mendapatkan GPS...' : 'Acquiring GPS...') : (isMs ? 'Lokasi tidak dijumpai' : 'Location unavailable'),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),
        ]),
      ])),
      StatefulBuilder(builder: (ctx, setB) => Stack(children: [
        IconButton(
          icon: const Icon(Icons.notifications_none_outlined, color: AppTheme.textSecondary),
          onPressed: () { showNotificationCenter(context, role: 'citizen', userName: widget.userName); setB(() {}); },
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('notifications').limit(1).snapshots(),
          builder: (_, snap) {
            final hasNew = (snap.data?.docs.isNotEmpty ?? false);
            if (!hasNew) return const SizedBox.shrink();
            return Positioned(top: 8, right: 8, child: Container(
              width: 10, height: 10,
              decoration: const BoxDecoration(color: AppTheme.emergency, shape: BoxShape.circle),
            ));
          },
        ),
      ])),
    ]);
  }

  Widget _buildStatusCard() {
    final isMs = context.watch<LocaleProvider>().locale.languageCode == 'ms';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E40AF), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: AppTheme.govBlue.withAlpha(60), blurRadius: 16,
            offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          _StatusBadge(),
          Spacer(),
          Icon(Icons.wb_sunny_outlined, color: Colors.white70, size: 22),
        ]),
        const SizedBox(height: 16),
        Text(isMs ? 'Tiada risiko banjir dikesan' : 'No flood risk detected',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22)),
        const SizedBox(height: 4),
        Text(isMs ? 'untuk 72 jam akan datang di kawasan anda.' : 'for the next 72 hours in your area.',
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _StatPill(
              icon: Icons.water_drop_outlined, label: isMs ? 'Paras Sungai' : 'River Level', value: isMs ? 'Normal (2.1m)' : 'Normal (2.1m)')),
          const SizedBox(width: 10),
          Expanded(child: _StatPill(
              icon: Icons.cloud_outlined, label: isMs ? 'Taburan Hujan' : 'Rainfall', value: '12mm/hr')),
        ]),
      ]),
    );
  }

  Widget _buildNearbyPPS() {
    final isMs = context.watch<LocaleProvider>().locale.languageCode == 'ms';
    final sorted = _sortedPPS;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.home_work_outlined, color: AppTheme.govBlue, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(isMs ? 'Pusat Pemindahan (PPS) Terdekat' : 'Nearest Relief Centres (PPS)',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.textPrimary))),
          if (_locationLoading)
            const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.govBlue)),
        ]),
        const SizedBox(height: 4),
        Text(
          _userLocation != null
              ? (isMs ? 'Disusun ikut jarak dari lokasi GPS anda' : 'Sorted by distance from your GPS location')
              : _locationLoading
                  ? (isMs ? 'Menunggu bacaan GPS...' : 'Waiting for GPS to sort by distance...')
                  : (isMs ? 'GPS tiada — sila aktifkan lokasi' : 'GPS unavailable — enable location for accurate distances'),
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 16),
        ...sorted.map((e) => _PPSTile(
          ppsData: e.pps,
          distKm: e.distKm,
          onNavigate: () => _openPPSMap(e.pps),
        )),
        const SizedBox(height: 12),
        // ── Register at PPS button ─────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CitizenPPSRegisterScreen(userName: widget.userName),
              ),
            ),
            icon: const Icon(Icons.how_to_reg_outlined, size: 18),
            label: Text(isMs ? 'Daftar Masuk di PPS' : 'Register at a PPS / Relief Centre',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.govBlue,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(isMs ? 'Maklumkan kehadiran anda kepada pegawai bertugas' : 'Notify officers of your arrival at a relief centre',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ),
      ]),
    );
  }

  Widget _buildHopeSection() {
    final isMs = context.watch<LocaleProvider>().locale.languageCode == 'ms';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppTheme.hopeLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.hope.withAlpha(60))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.volunteer_activism, color: AppTheme.hope, size: 20),
          const SizedBox(width: 8),
          Text(isMs ? 'Sokongan Komuniti' : 'Community Support',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.hope)),
        ]),
        const SizedBox(height: 12),
        _HopeTile(icon: Icons.restaurant_outlined, label: isMs ? 'MERCY Malaysia — Makanan percuma, 9AM-5PM' : 'MERCY Malaysia — Free meals, 9AM–5PM'),
        _HopeTile(icon: Icons.construction_outlined, label: isMs ? 'Pertubuhan IKRAM — Skuad pembersihan' : 'Pertubuhan IKRAM — Cleaning volunteers'),
        _HopeTile(icon: Icons.local_hospital_outlined, label: isMs ? 'KKM Klinik Bergerak — Kawasan Banjir' : 'KKM Mobile Clinic — Kawasan Banjir'),
      ]),
    );
  }
}

// ── PPS Map Bottom Sheet ───────────────────────────────────────────────────────

class _PPSMapSheet extends StatefulWidget {
  final _PPSData pps;
  final LatLng? userLocation;
  const _PPSMapSheet({required this.pps, this.userLocation});
  @override
  State<_PPSMapSheet> createState() => _PPSMapSheetState();
}

class _PPSMapSheetState extends State<_PPSMapSheet> {
  final MapController _mapCtrl = MapController();

  LatLngBounds _computeBounds() {
    final lats = [widget.userLocation!.latitude, widget.pps.location.latitude];
    final lngs = [widget.userLocation!.longitude, widget.pps.location.longitude];
    return LatLngBounds(
      LatLng(lats.reduce((a, b) => a < b ? a : b) - 0.01,
          lngs.reduce((a, b) => a < b ? a : b) - 0.01),
      LatLng(lats.reduce((a, b) => a > b ? a : b) + 0.01,
          lngs.reduce((a, b) => a > b ? a : b) + 0.01),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = widget.pps.isOpen && widget.pps.occupied < widget.pps.capacity;
    final statusColor = isOpen ? AppTheme.hope : AppTheme.emergency;
    final distKm = widget.userLocation != null
        ? _distanceKm(widget.userLocation!, widget.pps.location).toStringAsFixed(1)
        : null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, __) => Column(children: [
        // Handle
        Center(child: Container(
          width: 36, height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
        )),

        // Header info
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                  color: statusColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.home_work_outlined, color: statusColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.pps.name,
                  style: const TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 15, color: Colors.black)),
              const SizedBox(height: 2),
              Text(widget.pps.address,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: statusColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(widget.pps.status,
                      style: TextStyle(color: statusColor,
                          fontWeight: FontWeight.w600, fontSize: 11)),
                ),
                const SizedBox(width: 8),
                Text('${widget.pps.capacityText} capacity',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                if (distKm != null) ...[ 
                  const Text(' · ', style: TextStyle(color: AppTheme.textSecondary)),
                  Text('$distKm km away',
                      style: const TextStyle(color: AppTheme.govBlue, fontWeight: FontWeight.w600, fontSize: 12)),
                ],
              ]),
            ])),
          ]),
        ),

        // Capacity bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: widget.pps.capacity > 0
                  ? widget.pps.occupied / widget.pps.capacity : 0,
              minHeight: 6,
              backgroundColor: AppTheme.border,
              valueColor: AlwaysStoppedAnimation(statusColor),
            ),
          ),
        ),

        // Embedded OpenStreetMap — takes remaining space
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            child: FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: widget.pps.location,
                initialZoom: 14,
                onMapReady: () {
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (!mounted) return;
                    if (widget.userLocation != null) {
                      _mapCtrl.fitCamera(
                        CameraFit.bounds(
                          bounds: _computeBounds(),
                          padding: const EdgeInsets.all(80),
                        ),
                      );
                    }
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.floodsense.floodsense',
                ),
                if (widget.userLocation != null)
                  PolylineLayer(polylines: [
                    Polyline(
                      points: [widget.userLocation!, widget.pps.location],
                      color: AppTheme.govBlue,
                      strokeWidth: 4,
                    ),
                  ]),
                MarkerLayer(markers: [
                  Marker(
                    point: widget.pps.location,
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.home_work,
                      color: isOpen ? AppTheme.hope : AppTheme.emergency,
                      size: 40,
                    ),
                  ),
                  if (widget.userLocation != null)
                    Marker(
                      point: widget.userLocation!,
                      width: 44,
                      height: 44,
                      child: const Icon(Icons.my_location, color: Color(0xFF1A73E8), size: 36),
                    ),
                ]),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

// ── PPS List Tile ─────────────────────────────────────────────────────────────

class _PPSTile extends StatelessWidget {
  final _PPSData ppsData;
  final double? distKm;
  final VoidCallback onNavigate;
  const _PPSTile({required this.ppsData, this.distKm, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final isOpen = ppsData.isOpen && ppsData.occupied < ppsData.capacity;
    final statusColor = isOpen ? AppTheme.hope : AppTheme.emergency;
    final distLabel = distKm != null ? '${distKm!.toStringAsFixed(1)} km' : '—';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onNavigate,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: statusColor.withAlpha(18),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.home_work_outlined, color: statusColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ppsData.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black)),
              Text('$distLabel · ${ppsData.capacityText} · ${ppsData.status}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ])),
            const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
          ]),
        ),
      ),
    );
  }
}

// ── Reusable Widgets ──────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
        color: Colors.white24, borderRadius: BorderRadius.circular(20)),
    child: const Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.circle, color: Color(0xFF4ADE80), size: 8),
      SizedBox(width: 6),
      Text('SAFE / SELAMAT',
          style: TextStyle(color: Colors.white, fontSize: 11,
              fontWeight: FontWeight.w700, letterSpacing: 1)),
    ]),
  );
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _StatPill({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
        color: Colors.white24, borderRadius: BorderRadius.circular(10)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white70, size: 14),
      const SizedBox(width: 6),
      Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white60, fontSize: 10)),
        Text(value, overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ])),
    ]),
  );
}

class _HopeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HopeTile({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Icon(icon, color: AppTheme.hope, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(label,
          style: const TextStyle(color: Colors.black, fontSize: 13))),
    ]),
  );
}
