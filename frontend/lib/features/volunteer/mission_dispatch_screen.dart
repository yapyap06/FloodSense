import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/locale_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import 'volunteer_repository.dart';
import '../../core/widgets/loc_text.dart';

/// Shown after a volunteer taps ACCEPT on a mission offer.
/// Light-theme design with an embedded map showing the route to the victim.
class MissionDispatchScreen extends StatefulWidget {
  final String missionId;
  final Map<String, dynamic> data;
  final String volunteerId;
  const MissionDispatchScreen({
    super.key,
    required this.missionId,
    required this.data,
    required this.volunteerId,
  });

  @override
  State<MissionDispatchScreen> createState() => _MissionDispatchScreenState();
}

class _MissionDispatchScreenState extends State<MissionDispatchScreen> {
  final _repo = VolunteerRepository();
  bool _completing = false;
  int _missionStep = 0; // 0 = Accepted, 1 = Arrived
  Timer? _localTimer;
  Duration _elapsed = Duration.zero;
  StreamSubscription<QuerySnapshot>? _incidentSub;
  StreamSubscription<Position>? _gpsSub;

  @override
  void initState() {
    super.initState();
    _listenToCancellation();
    _startGPSStream();

    // If mission is already accepted, start the timer
    final status = widget.data['status'] as String? ?? 'OFFERED';
    if (status == 'ACCEPTED') {
      _startLocalTimer();
    }
  }

  void _startGPSStream() {
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3, // Update every 3 meters
      ),
    ).listen((pos) async {
      final sosId = widget.data['sos_id'] as String? ?? '';
      if (sosId.isEmpty || !mounted) return;
      
      try {
        final querySnap = await FirebaseFirestore.instance
            .collection('incidents')
            .where('sos_id', isEqualTo: sosId)
            .get();
        for (var doc in querySnap.docs) {
          await doc.reference.update({
            'rescuer_lat': pos.latitude,
            'rescuer_lng': pos.longitude,
            'rescuer_heading': pos.heading,
          });
        }
      } catch (e) {
        debugPrint('[MissionDispatch] GPS stream update error: $e');
      }
    });
  }

  void _listenToCancellation() {
    final sosId = widget.data['sos_id'] as String? ?? '';
    if (sosId.isNotEmpty) {
      _incidentSub = FirebaseFirestore.instance
          .collection('incidents')
          .where('sos_id', isEqualTo: sosId)
          .snapshots()
          .listen((snap) {
        if (snap.docs.isNotEmpty) {
          final data = snap.docs.first.data();
          final status = data['status'] as String?;
          if (status == 'CANCELLED') {
            _showCancelledAlert();
          }
        }
      });
    }
  }

  void _showCancelledAlert() {
    if (!mounted) return;
    _incidentSub?.cancel();
    _localTimer?.cancel();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const LocText('Misi Dibatalkan', 'Mission Cancelled', style: TextStyle(color: AppTheme.emergency)),
        content: const LocText(
            'Mangsa telah membatalkan permohonan SOS ini.',
            'The victim has cancelled this SOS request.'),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // close dispatch screen
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.emergency),
            child: const LocText('Tutup', 'Close'),
          ),
        ],
      ),
    );
  }

  void _startLocalTimer() {
    _localTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  @override
  void dispose() {
    _localTimer?.cancel();
    _incidentSub?.cancel();
    _gpsSub?.cancel();
    super.dispose();
  }

  Future<void> _accept() async {
    await _repo.respondToMission(
      widget.volunteerId,
      widget.missionId,
      'ACCEPTED',
      widget.data['sos_id'] as String? ?? '',
    );
  }

  Future<void> _markComplete() async {
    setState(() => _completing = true);
    try {
      final sosId = widget.data['sos_id'] as String? ?? '';
      final headCount = widget.data['head_count'] ?? 1;
      
      // Update mission offer — include head_count so the dashboard can sum it
      await FirebaseFirestore.instance
          .collection('mission_offers')
          .doc(widget.missionId)
          .update({
            'status': 'COMPLETED',
            'head_count': headCount,
            'completed_at': FieldValue.serverTimestamp(),
          }).catchError((_) {});
      
      // Set volunteer back to AVAILABLE
      await FirebaseFirestore.instance
          .collection('volunteers')
          .doc(widget.volunteerId)
          .update({'status': 'AVAILABLE'}).catchError((_) {});
      
      // Mark the incident as RESOLVED (query by sos_id field, not doc ID)
      if (sosId.isNotEmpty) {
        final querySnap = await FirebaseFirestore.instance
            .collection('incidents')
            .where('sos_id', isEqualTo: sosId)
            .get();
        for (var doc in querySnap.docs) {
          await doc.reference.update({
            'status': 'RESOLVED',
            'resolved_at': FieldValue.serverTimestamp(),
          });
        }
      }

      _localTimer?.cancel();
      _gpsSub?.cancel();
      if (mounted) {
        setState(() => _missionStep = 2);
        
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
              const LocText(
                'Misi Selesai!',
                'Mission Completed!',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.black),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const LocText(
                'Terima kasih atas bantuan anda. Laporan telah direkodkan. Sila maklumkan kepada komander operasi di lapangan.',
                'Thank you for your assistance. The report has been recorded. Please notify the field operations commander.',
                style: TextStyle(color: Color(0xFF4B5563), fontSize: 13, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ]),
            actions: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.hope,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const LocText('Kembali ke Dashboard', 'Return to Dashboard', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
        if (mounted) Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  Future<void> _requestBackup() async {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const LocText('Bantuan Tambahan Diminta', 'Backup Requested', style: TextStyle(color: AppTheme.emergency)),
        content: const LocText(
            'Notifikasi kecemasan telah dihantar kepada APM dan sukarelawan berdekatan.\n\nSila pastikan keselamatan anda terjamin. Bertahan di lokasi.',
            'Emergency notification has been sent to APM and nearby volunteers.\n\nPlease ensure your safety is guaranteed. Hold your position.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.emergency),
            child: const LocText('Tutup', 'Close'),
          ),
        ],
      ),
    );
    try {
      final sosId = widget.data['sos_id'] as String? ?? '';
      if (sosId.isNotEmpty) {
        final querySnap = await FirebaseFirestore.instance.collection('incidents').where('sos_id', isEqualTo: sosId).get();
        for (var doc in querySnap.docs) {
           doc.reference.update({'urgency': 'CRITICAL', 'backup_requested': true});
        }
      }
    } catch (_) {}
  }

  Future<void> _nextStep() async {
    if (_missionStep == 0) {
      if (mounted) setState(() => _missionStep = 1);
      // For self-initiated SOS taps (MIS- prefix), only accept when volunteer
      // confirms they are physically going to the location (I Already Arrived).
      if (widget.missionId.startsWith('MIS-')) {
        await _accept();
      }
    } else {
      await _markComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMs = context.watch<LocaleProvider>().locale.languageCode == 'ms';
    final elapsed = _elapsed;
    final m = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    final elapsedStr = '${elapsed.inHours > 0 ? '${elapsed.inHours}:' : ''}$m:$s';

    final docLat = (widget.data['lat'] as num?)?.toDouble();
    final docLng = (widget.data['lng'] as num?)?.toDouble();
    String address = (widget.data['address_text'] as String? ?? widget.data['address'] as String? ?? '').trim();
    bool hasAlpha = RegExp(r'[a-zA-Z0-9]').hasMatch(address);
    bool isUnknown = !hasAlpha || 
                     address.toLowerCase().contains('unknown') || 
                     address.toLowerCase().contains('tidak diketahui') ||
                     address.toLowerCase() == 'null';
    
    if (isUnknown) {
      if (docLat != null && docLng != null) {
        address = 'GPS (${docLat.toStringAsFixed(5)}, ${docLng.toStringAsFixed(5)})';
      } else {
        address = isMs ? 'Lokasi GPS tidak diketahui' : 'GPS location unknown';
      }
    }
    final headCount = widget.data['head_count'] ?? '?';
    final vulnerable = (widget.data['vulnerable'] as List?)?.cast<String>() ?? [];
    final description = widget.data['description'] as String? ?? '';
    final situations = (widget.data['situations'] as List?)?.cast<String>() ?? [];
    final contactName = widget.data['contact_name'] as String? ?? '-';
    final phone = widget.data['phone'] as String? ?? '-';
    final createdAtTs = widget.data['created_at'];
    final String submittedAt = createdAtTs is Timestamp
        ? _fmtTs(createdAtTs)
        : '-';
    // Victim location from Firestore or demo fallback
    final lat = docLat ?? 3.0738;
    final lng = docLng ?? 101.5183;
    final victimPin = LatLng(lat, lng);
    // Volunteer is slightly offset (would be real GPS in production)
    final volunteerPin = LatLng(lat + 0.012, lng - 0.008);

    // bilingual situation labels
    final situationLabels = <String, String>{
      'Trapped': isMs ? 'Terperangkap' : 'Trapped',
      'Medical Emergency': isMs ? 'Kecemasan Perubatan' : 'Medical Emergency',
      'Infant/Elderly': isMs ? 'Kanak-kanak/Warga Emas' : 'Infant/Elderly',
      'Need Boat': isMs ? 'Perlu Bot' : 'Need Boat',
      'No Food/Water': isMs ? 'Tiada Makanan/Air' : 'No Food/Water',
      'Other': isMs ? 'Lain-lain' : 'Other',
    };

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const LocText('Misi Aktif', 'Active Mission',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.border),
        ),
      ),
      body: Column(children: [
        // ── Timer banner ─────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          color: AppTheme.emergencyLight,
          child: Column(children: [
            const LocText('MASA BERLALU', 'TIME ELAPSED',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11, letterSpacing: 1.5)),
            const SizedBox(height: 4),
            Text(elapsedStr,
                style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.emergency,
                    fontFeatures: [FontFeature.tabularFigures()])),
          ]),
        ),

        Expanded(
          child: ListView(padding: const EdgeInsets.all(20), children: [

            // ── Embedded Navigation Map ──────────────────────────────────────
            _sectionLabel(isMs ? 'PETA LALUAN' : 'ROUTE MAP'),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 200,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(
                      (victimPin.latitude + volunteerPin.latitude) / 2,
                      (victimPin.longitude + volunteerPin.longitude) / 2,
                    ),
                    initialZoom: 13,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.floodsense.floodsense',
                    ),
                    PolylineLayer(polylines: [
                      Polyline(
                        points: [volunteerPin, victimPin],
                        color: AppTheme.govBlue,
                        strokeWidth: 4,
                      ),
                    ]),
                    MarkerLayer(markers: [
                      Marker(
                        point: victimPin,
                        width: 44, height: 44,
                        child: const Icon(Icons.location_pin, color: AppTheme.emergency, size: 44),
                      ),
                      Marker(
                        point: volunteerPin,
                        width: 40, height: 40,
                        child: const Icon(Icons.directions_run, color: AppTheme.govBlue, size: 36),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            // ── Commander's Task ─────────────────────────────────────────────
            _sectionLabel(isMs ? 'TUGASAN KOMANDER' : "COMMANDER'S TASK"),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF9C3), // Light yellow for focus
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFACC15), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.data['mission_title'] as String? ?? (isMs ? 'Misi Menyelamat' : 'Rescue Mission'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.data['mission_instruction'] as String? ?? (isMs ? 'Tiada arahan khusus' : 'No specific instructions provided'),
                    style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Location ─────────────────────────────────────────────────────
            _sectionLabel(isMs ? 'LOKASI' : 'LOCATION'),
            const SizedBox(height: 8),
            _infoCard(icon: Icons.location_on, color: AppTheme.emergency, label: address),
            const SizedBox(height: 16),

            // ── Victims ──────────────────────────────────────────────────────
            _sectionLabel(isMs ? 'MANGSA' : 'VICTIMS'),
            const SizedBox(height: 8),
            _infoCard(icon: Icons.people, color: AppTheme.warning, label: isMs ? '$headCount orang' : '$headCount people'),
            if (vulnerable.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: vulnerable.map((g) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppTheme.warningLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.warning.withAlpha(80))),
                child: Text(g, style: const TextStyle(color: AppTheme.warning, fontSize: 12, fontWeight: FontWeight.w600)),
              )).toList()),
            ],
            const SizedBox(height: 16),

            // ── Citizen Details ──────────────────────────────────────────
            _sectionLabel(isMs ? 'MAKLUMAT MANGSA' : 'CITIZEN DETAILS'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.govBlueLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.govBlue.withAlpha(40)),
              ),
              child: Column(
                children: [
                  _dispatchContactRow(
                    icon: Icons.person_outline,
                    label: isMs ? 'Nama / ID Pengguna' : 'Name / User ID',
                    value: contactName,
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 16, color: AppTheme.govBlue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMs ? 'Nombor Telefon' : 'Phone Number',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              phone,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (phone != '-')
                        ElevatedButton.icon(
                          onPressed: () async {
                            final uri = Uri(scheme: 'tel', path: phone);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            } else if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isMs
                                      ? 'Tidak dapat membuat panggilan ke $phone'
                                      : 'Cannot place call to $phone'),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.call, size: 14),
                          label: Text(isMs ? 'Hubungi' : 'Call',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.hope,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                    ],
                  ),
                  if (submittedAt != '-') ...[
                    const Divider(height: 20),
                    _dispatchContactRow(
                      icon: Icons.access_time_outlined,
                      label: isMs ? 'Masa SOS Dihantar' : 'SOS Submitted At',
                      value: submittedAt,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Situations ───────────────────────────────────────────────
            if (situations.isNotEmpty) ...[
              _sectionLabel(isMs ? 'SITUASI' : 'SITUATIONS'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 6,
                children: situations.map((s) {
                  final label = situationLabels[s] ?? s;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.warningLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.warning.withAlpha(80)),
                    ),
                    child: Text(label, style: const TextStyle(
                        color: AppTheme.warning, fontSize: 12, fontWeight: FontWeight.w600)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // ── Description ───────────────────────────────────────────────
            if (description.isNotEmpty) ...[
              _sectionLabel(isMs ? 'PENERANGAN MANGSA' : 'VICTIM DESCRIPTION'),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes_outlined, size: 18, color: AppTheme.govBlue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        description,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Status ────────────────────────────────────────────────
            _sectionLabel(isMs ? 'STATUS OPERASI' : 'OPERATION STATUS'),
            const SizedBox(height: 8),
            _buildMissionStepper(),
            const SizedBox(height: 20),

            // ── Notes ────────────────────────────────────────────────────────
            _sectionLabel(isMs ? 'CATATAN PENTING' : 'IMPORTANT NOTES'),
            const SizedBox(height: 8),
            ...(isMs ? [
                    'Pakai jaket keselamatan',
                    'Hubungi 999 jika perlu sokongan tambahan',
                    'Rakam video pendek sebagai bukti',
                ] : [
                    'Wear safety jacket',
                    'Call 999 if backup needed',
                    'Record short video as proof',
                ]).map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.chevron_right, color: AppTheme.govBlue, size: 18),
                const SizedBox(width: 4),
                Expanded(child: Text(t, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
              ]),
            )),
          ]),
        ),

        // ── Action button ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('mission_offers').doc(widget.missionId).snapshots(),
            builder: (context, snapshot) {
              final status = snapshot.data?.data()?['status'] as String? ?? widget.data['status'] ?? 'OFFERED';
              
              if (status == 'OFFERED') {
                return Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          await _repo.respondToMission(widget.volunteerId, widget.missionId, 'DECLINED', widget.data['sos_id'] ?? '');
                          if (mounted) navigator.pop();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.emergency,
                          side: const BorderSide(color: AppTheme.emergency),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const LocText('Tolak Misi', 'Reject Mission'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          await _accept();
                          _startLocalTimer();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.hope,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const LocText('Terima Misi', 'Accept Mission'),
                      ),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _completing ? null : _nextStep,
                      icon: _completing
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(_missionStep == 0 ? Icons.directions_car : Icons.check_circle),
                      label: Text(_missionStep == 0 
                          ? (isMs ? 'SAYA TELAH TIBA' : 'I HAVE ARRIVED') 
                          : (isMs ? 'MISI SELESAI' : 'MISSION COMPLETE'),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _missionStep == 0 ? AppTheme.govBlue : AppTheme.hope,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: _requestBackup,
                      icon: const Icon(Icons.group_add, size: 20),
                      label: const LocText('Minta Bantuan', 'Request Backup', style: TextStyle(fontWeight: FontWeight.w700)),
                      style: TextButton.styleFrom(foregroundColor: AppTheme.emergency),
                    ),
                  ),
                ],
              );
            }
          ),
        ),
      ]),
    );
  }

  Widget _sectionLabel(String t) => Text(t,
      style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w600));

  Widget _infoCard({required IconData icon, required Color color, required String label}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border)),
    child: Row(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 14))),
    ]),
  );

  /// Compact label+value row used inside the citizen-details card
  Widget _dispatchContactRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.govBlue),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted)),
              const SizedBox(height: 1),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }

  /// Format a Firestore Timestamp to "dd/mm/yyyy  HH:MM"
  String _fmtTs(Timestamp ts) {
    final dt = ts.toDate().toLocal();
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year}  $h:$min';
  }

  Widget _buildMissionStepper() {
    final isMs = context.watch<LocaleProvider>().locale.languageCode == 'ms';
    final stepsMs = [
      (Icons.radar, 'Misi Diterima', 'Menuju ke lokasi mangsa'),
      (Icons.location_on, 'Tiba di Lokasi', 'Menyelamat & menilai keadaan'),
      (Icons.check_circle, 'Misi Selesai', 'Laporan sedia dihantar'),
    ];
    final stepsEn = [
      (Icons.radar, 'Mission Accepted', 'Heading to victim location'),
      (Icons.location_on, 'Arrived at Location', 'Rescuing & assessing situation'),
      (Icons.check_circle, 'Mission Completed', 'Report ready to be sent'),
    ];
    final steps = isMs ? stepsMs : stepsEn;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border)),
      child: Column(
        children: List.generate(steps.length, (i) {
          final isActive = i <= _missionStep;
          final isCurrent = i == _missionStep;
          final isDone = i < _missionStep;

          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: isActive ? AppTheme.hope : AppTheme.border,
                child: Icon(isDone ? Icons.check : steps[i].$1, color: Colors.white, size: 12),
              ),
              if (i < 2)
                Container(
                  width: 2, height: 28,
                  color: isActive ? AppTheme.hope.withAlpha(80) : AppTheme.border,
                ),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(steps[i].$2, style: TextStyle(
                      color: isActive ? Colors.black : AppTheme.textSecondary,
                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600, fontSize: 13)),
                  Text(steps[i].$3, style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11)),
                ]),
              ),
            ),
          ]);
        }),
      ),
    );
  }
}
