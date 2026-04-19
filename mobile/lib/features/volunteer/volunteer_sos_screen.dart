import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../core/providers/locale_provider.dart';
import 'mission_dispatch_screen.dart';
import '../../core/utils/geo_utils.dart';
import '../../core/widgets/loc_text.dart';

/// Volunteer SOS Dispatch / Ops Map Screen
/// Shows a live map of active SOS cases + volunteer's real-time GPS position.
/// Volunteers can tap a case to navigate to MissionDispatchScreen.
class VolunteerSOSScreen extends StatefulWidget {
  final String userName;
  const VolunteerSOSScreen({super.key, this.userName = 'Sukarelawan Pengguna'});

  @override
  State<VolunteerSOSScreen> createState() => _VolunteerSOSScreenState();
}

class _VolunteerSOSScreenState extends State<VolunteerSOSScreen> {
  // Fallback centre (Klang area) — used only before GPS is acquired
  static const _fallbackCenter = LatLng(3.0738, 101.5183);

  // Controller so we can animate the map to track the user
  final _mapController = MapController();

  // Real-time volunteer position (null until GPS is ready)
  LatLng? _volPosition;

  // GPS stream subscription
  StreamSubscription<Position>? _positionSub;

  // Whether we are still waiting for the first GPS fix
  bool _locating = true;
  String? _locError;

  // Track if we should auto-follow the user's position on the map
  bool _followUser = true;



  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  // ── Location tracking ─────────────────────────────────────────────────────
  Future<void> _startLocationTracking() async {
    // 1. Check & request permission
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied) {
      if (mounted) {
        setState(() {
          _locating = false;
          _locError = 'Location permission denied. Showing demo position.';
          _volPosition = _fallbackCenter;
        });
      }
      return;
    }

    // 2. Check if location service is enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          _locating = false;
          _locError = 'Location services disabled. Showing demo position.';
          _volPosition = _fallbackCenter;
        });
      }
      return;
    }

    // 3. Get initial fast fix
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (mounted) {
        setState(() {
          _locating = false;
          _volPosition = LatLng(pos.latitude, pos.longitude);
        });
        if (_followUser) {
          _mapController.move(_volPosition!, 14.5);
        }
      }
    } catch (_) {
      // Fall through to stream — maybe we get updates later
      if (mounted) setState(() => _locating = false);
    }

    // 4. Subscribe to continuous position updates
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // update every 5 metres of movement
      ),
    ).listen(
      (pos) {
        if (!mounted) return;
        final newPos = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _volPosition = newPos;
          _locating = false;
          _locError = null;
        });
        // Auto-pan the map if follow mode is on
        if (_followUser) {
          _mapController.move(newPos, _mapController.camera.zoom);
        }
      },
      onError: (_) {
        if (mounted && _volPosition == null) {
          setState(() {
            _locating = false;
            _locError = 'GPS unavailable. Showing approximate position.';
            _volPosition = _fallbackCenter;
          });
        }
      },
    );
  }

  bool _showMap = true;

  @override
  Widget build(BuildContext context) {
    final isMs = context.watch<LocaleProvider>().locale.languageCode == 'ms';

    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const LocText('Gerak Balas SOS', 'SOS Dispatch',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 16)),
          Text(isMs ? 'Kes aktif memerlukan bantuan anda' : 'Active cases require your assistance',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ]),
        actions: [
          // Follow-user toggle
          IconButton(
            icon: Icon(
              _followUser ? Icons.my_location : Icons.location_searching,
              color: _followUser ? AppTheme.govBlue : AppTheme.textMuted,
            ),
            tooltip: _followUser 
                ? (isMs ? 'Mengikuti lokasi anda' : 'Following your location') 
                : (isMs ? 'Sentuh untuk ke lokasi anda' : 'Tap to re-centre'),
            onPressed: () {
              setState(() => _followUser = true);
              if (_volPosition != null) {
                _mapController.move(_volPosition!, 14.5);
              }
            },
          ),
          // Toggle map / list view
          IconButton(
            icon: Icon(_showMap ? Icons.list_alt : Icons.map_outlined,
                color: AppTheme.govBlue),
            tooltip: _showMap 
                ? (isMs ? 'Pandangan Senarai' : 'List View') 
                : (isMs ? 'Pandangan Peta' : 'Map View'),
            onPressed: () => setState(() => _showMap = !_showMap),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('incidents')
            .where('status', isEqualTo: 'PENDING')
            .snapshots(),
        builder: (context, snapshot) {
          final liveCases = <_SOSCase>[];
          if (snapshot.hasData) {
            // Spread offsets so that Firestore docs without lat/lng don't stack
            final rng = math.Random(42); // fixed seed = deterministic offsets
            int offsetIdx = 0;
            for (var doc in snapshot.data!.docs) {
              final d = doc.data() as Map<String, dynamic>;
              final urgencyStr = d['urgency'] as String? ?? 'SEDERHANA';
              final cColor = urgencyStr == 'CRITICAL' || urgencyStr == 'KRITIKAL'
                  ? AppTheme.emergency
                  : urgencyStr == 'HIGH' || urgencyStr == 'TINGGI'
                      ? AppTheme.warning
                      : AppTheme.govBlue;
              final vul = (d['vulnerable'] as List?)?.cast<String>().join(', ') ?? '';

              // 1. Try to read explicit lat/lng doubles
              double? docLat = (d['lat'] as num?)?.toDouble();
              double? docLng = (d['lng'] as num?)?.toDouble();

              // 2. Try to read from 'location' GeoPoint if doubles are missing
              if (docLat == null || docLng == null) {
                final locField = d['location'];
                if (locField is GeoPoint) {
                  docLat = locField.latitude;
                  docLng = locField.longitude;
                }
              }

              // 3. Fallback to a FIXED point (not the volunteer) if still null
              if (docLat == null || docLng == null) {
                // Use deterministic offsets around a FIXED base (Klang Valley centroid)
                docLat = _fallbackCenter.latitude + (rng.nextDouble() * 0.05 - 0.025) + (offsetIdx * 0.005);
                docLng = _fallbackCenter.longitude + (rng.nextDouble() * 0.05 - 0.025) + (offsetIdx * 0.005);
              }
              offsetIdx++;

              // Compute rough distance in km
              final volLat = _volPosition?.latitude ?? _fallbackCenter.latitude;
              final volLng = _volPosition?.longitude ?? _fallbackCenter.longitude;
              final distKm = _roughDistKm(volLat, volLng, docLat, docLng);

              liveCases.add(_SOSCase(
                id: d['sos_id'] ?? doc.id,
                address: d['address_text'] ?? (isMs ? 'Lokasi tidak diketahui' : 'Location unknown'),
                pax: d['head_count'] ?? 1,
                vulnerable: vul,
                urgency: urgencyStr,
                urgencyColor: cColor,
                lat: docLat,
                lng: docLng,
                state: d['state'] as String?,
                distanceKm: distKm.toStringAsFixed(1),
              ));
            }
          }

          // ── Filter by Local State ────────────────────────────────────────
          final String volState = _getMalaysianState(_volPosition ?? _fallbackCenter);
          
          final allCases = liveCases.where((c) {
             // Extract state from the document in the loop above? Yes.
             // But for existing data without 'state' field, we show them if they are close enough (< 100km)
             // to avoid blank screen during migration.
             if (c.state != null) {
               return c.state == volState;
             }
             // Fallback for old data
             return double.parse(c.distanceKm) < 100.0;
          }).toList();

          // Sort: nearest first
          allCases.sort((a, b) =>
                double.parse(a.distanceKm).compareTo(double.parse(b.distanceKm)));

          return Column(children: [
            // ── GPS status / State Info bar ────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.govBlueLight.withAlpha(20),
              child: Row(children: [
                const Icon(Icons.my_location, size: 14, color: AppTheme.govBlue),
                const SizedBox(width: 8),
                Text(
                  '${isMs ? 'Zon Operasi' : 'Operational Zone'}: $volState',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppTheme.govBlue),
                ),
                const Spacer(),
                Text(
                  '${allCases.length} ${isMs ? 'kes aktif' : 'active cases'}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ]),
            ),
            if (_locating)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppTheme.govBlueLight,
                child: Row(children: [
                  const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.govBlue),
                  ),
                  const SizedBox(width: 10),
                  Text(isMs ? 'Mendapatkan lokasi GPS anda…' : 'Acquiring your GPS location…',
                      style: const TextStyle(color: AppTheme.govBlue, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              )
            else if (_locError != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppTheme.warningLight,
                child: Row(children: [
                  const Icon(Icons.location_off_outlined, color: AppTheme.warning, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_locError!,
                      style: const TextStyle(color: AppTheme.warning, fontSize: 12))),
                ]),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: const Color(0xFFECFDF5),
                child: Row(children: [
                  const Icon(Icons.location_on, color: AppTheme.hope, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    '${isMs ? 'GPS aktif' : 'GPS active'} — ${_volPosition!.latitude.toStringAsFixed(5)}, '
                    '${_volPosition!.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(color: AppTheme.hope, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ]),
              ),

            // ── Active SOS count banner ────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: AppTheme.emergencyLight,
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: AppTheme.emergency, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isMs ? '${allCases.length} kes SOS aktif memerlukan sukarelawan segera' : '${allCases.length} active SOS cases require immediate volunteers',
                    style: const TextStyle(
                        color: AppTheme.emergency, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: AppTheme.emergency, borderRadius: BorderRadius.circular(20)),
                  child: Text('${allCases.length} AKTIF',
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w800, fontSize: 10)),
                ),
              ]),
            ),

            Expanded(child: _showMap ? _buildMapView(allCases, isMs) : _buildListView(allCases)),
          ]);
        },
      ),
    );
  }

  // ── Map view with victim pins + live volunteer pin ─────────────────────────
  Widget _buildMapView(List<_SOSCase> cases, bool isMs) {
    final center = _volPosition ?? _fallbackCenter;

    return Column(children: [
      Expanded(
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 13.0,
            // When user pans manually, stop auto-following
            onPositionChanged: (_, hasGesture) {
              if (hasGesture && _followUser) {
                setState(() => _followUser = false);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.floodsense.floodsense',
            ),
            // Lines from volunteer to each SOS case
            PolylineLayer(
              polylines: cases.map((c) => Polyline(
                points: [center, LatLng(c.lat, c.lng)],
                color: c.urgencyColor.withAlpha(70),
                strokeWidth: 2,
              )).toList(),
            ),
            MarkerLayer(markers: [
              // ── Live volunteer pin ──
              Marker(
                point: center,
                width: 56, height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Pulse ring
                    if (_volPosition != null)
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.hope.withAlpha(40),
                          border: Border.all(color: AppTheme.hope, width: 2),
                        ),
                      ),
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: AppTheme.hope,
                      child: Icon(Icons.directions_run, color: Colors.white, size: 18),
                    ),
                  ],
                ),
              ),
              // ── SOS case pins ──
              ...cases.map((c) => Marker(
                point: LatLng(c.lat, c.lng),
                width: 60, height: 60,
                child: GestureDetector(
                  onTap: () => _openDispatch(context, c),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: c.urgencyColor,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [BoxShadow(
                            color: c.urgencyColor.withAlpha(80),
                            blurRadius: 4, offset: const Offset(0, 2),
                          )]),
                      child: Text(
                        c.id.length > 4 ? c.id.substring(c.id.length - 4) : c.id,
                        style: const TextStyle(color: Colors.white,
                            fontSize: 8, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Icon(Icons.location_pin, color: c.urgencyColor, size: 32),
                  ]),
                ),
              )),
            ]),
          ],
        ),
      ),
      // Compact case list below map
      Container(
        height: 140,
        color: Colors.white,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemCount: cases.length,
          itemBuilder: (_, i) {
            final c = cases[i];
            return GestureDetector(
              onTap: () => _openDispatch(context, c),
              child: Container(
                width: 220,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.urgencyColor.withAlpha(10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.urgencyColor.withAlpha(80)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: c.urgencyColor.withAlpha(20),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(c.urgency,
                          style: TextStyle(color: c.urgencyColor,
                              fontSize: 9, fontWeight: FontWeight.w800)),
                    ),
                    const Spacer(),
                    Text('${c.distanceKm} km',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ]),
                  const SizedBox(height: 6),
                  Text(c.address, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600,
                          fontSize: 12, color: Colors.black)),
                  const SizedBox(height: 4),
                  Text('${c.pax} ${isMs ? 'orang' : 'people'}${c.vulnerable.isNotEmpty ? ' • ${c.vulnerable}' : ''}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  // ── List view ─────────────────────────────────────────────────────────────
  Widget _buildListView(List<_SOSCase> cases) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemCount: cases.length,
      itemBuilder: (_, i) => _SOSCaseTile(
          c: cases[i], onAccept: () => _openDispatch(context, cases[i])),
    );
  }

  Future<void> _openDispatch(BuildContext context, _SOSCase c) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('volunteers')
          .doc(widget.userName)
          .get();
      final isActive = doc.data()?['standing_consent'] == true;

      if (!isActive && context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const LocText('Status Tidak Aktif', 'Inactive Status',
                style: TextStyle(color: AppTheme.emergency)),
            content: const LocText(
              'Anda tidak membenarkan tawaran misi buat masa ini.\n\n'
              'Sila aktifkan "Kebenaran Tetap" di halaman utama (Home) '
              'sebelum mula menerima misi menyelamat.',
              'You are not accepting mission offers currently.\n\n'
              'Please enable "Standing Consent" on the Home page '
              'before receiving rescue missions.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(backgroundColor: AppTheme.emergency),
                child: const LocText('Faham', 'Understood'),
              ),
            ],
          ),
        );
        return;
      }
    } catch (_) {}

    if (!context.mounted) return;

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => MissionDispatchScreen(
        missionId: 'MIS-${c.id}',
        data: {
          'sos_id': c.id,
          'address': c.address,
          'head_count': c.pax,
          'vulnerable': c.vulnerable.isNotEmpty ? [c.vulnerable] : [],
          'lat': c.lat,
          'lng': c.lng,
          'distance_km': c.distanceKm,
        },
      ),
    ));
  }

  /// Haversine-based rough distance in km
  double _roughDistKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0; // Earth radius km
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _deg2rad(double deg) => deg * math.pi / 180;

  String _getMalaysianState(LatLng loc) => getMalaysianState(loc);
}

// ── Data model ────────────────────────────────────────────────────────────────
class _SOSCase {
  final String id, address, vulnerable, urgency, distanceKm;
  final String? state;
  final int pax;
  final Color urgencyColor;
  final double lat, lng;
  const _SOSCase({
    required this.id, required this.address, required this.vulnerable,
    required this.urgency, required this.urgencyColor, required this.pax,
    required this.lat, required this.lng, required this.distanceKm,
    this.state,
  });
}

// ── Compact SOS tile ──────────────────────────────────────────────────────────
class _SOSCaseTile extends StatelessWidget {
  final _SOSCase c;
  final VoidCallback onAccept;
  const _SOSCaseTile({required this.c, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    final isMs = context.watch<LocaleProvider>().locale.languageCode == 'ms';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.urgencyColor.withAlpha(60)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 6, color: c.urgencyColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: c.urgencyColor.withAlpha(20),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(c.urgency,
                          style: TextStyle(color: c.urgencyColor,
                              fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.5)),
                    ),
                    const SizedBox(width: 8),
                    Text(c.id,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppTheme.govBlueLight,
                          borderRadius: BorderRadius.circular(6)),
                      child: Text('${c.distanceKm} km',
                          style: const TextStyle(color: AppTheme.govBlue,
                              fontWeight: FontWeight.w700, fontSize: 11)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 3),
                    Expanded(child: Text(c.address,
                        style: const TextStyle(fontWeight: FontWeight.w600,
                            fontSize: 13, color: Colors.black))),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.people_outline, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 3),
                    Text('${c.pax} ${isMs ? 'orang' : 'people'}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    if (c.vulnerable.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppTheme.warningLight,
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(c.vulnerable,
                            style: const TextStyle(color: AppTheme.warning,
                                fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onAccept,
                      icon: const Icon(Icons.directions_run, size: 16),
                      label: const LocText('Terima & Pergi', 'Accept & Go',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.urgencyColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
