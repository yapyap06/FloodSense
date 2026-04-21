import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/data/agent_service.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/utils/geo_utils.dart';
import 'sos_map_view.dart';

enum _SOSStep { idle, situation, location, sent }

class SOSScreen extends StatefulWidget {
  final String contactName;
  final String phone;
  const SOSScreen({super.key, required this.contactName, required this.phone});
  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen> with TickerProviderStateMixin {
  _SOSStep _step = _SOSStep.idle;
  final _situations = <String>{};
  final _otherCtrl = TextEditingController();
  final _manualLocationCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  bool _showOtherField = false;
  bool _sending = false;
  String? _incidentId;
  int _peopleCount = 1;

  // GPS state
  LatLng? _currentPosition;
  bool _gpsLoading = false;
  String? _gpsError;
  bool _isManualLocation = false;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Default fallback (Klang Valley centroid) only used if GPS totally fails
  static const _fallbackLatLng = LatLng(3.0738, 101.5183); // Klang Valley centroid

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    // Check if the user already has an active SOS
    _checkExistingSOS();
  }

  Future<void> _checkExistingSOS() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('incidents')
          .where('sender_phone', isEqualTo: widget.phone)
          .get();

      if (snap.docs.isNotEmpty && mounted) {
        final activeDocs = snap.docs.where((d) {
          final s = d.data()['status'] as String? ?? '';
          return s == 'PENDING' || s == 'ASSIGNED' || s == 'DISPATCHED';
        }).toList();

        if (activeDocs.isNotEmpty) {
          activeDocs.sort((a, b) {
            final aTs = a.data()['created_at'] as Timestamp?;
            final bTs = b.data()['created_at'] as Timestamp?;
            if (aTs == null && bTs == null) return 0;
            if (aTs == null) return 1;
            if (bTs == null) return -1;
            return bTs.compareTo(aTs);
          });
          
          setState(() {
            _incidentId = activeDocs.first.data()['sos_id'] as String? ?? activeDocs.first.id;
            _step = _SOSStep.sent; // Skip directly to the sent/status screen
          });
        }
      }
    } catch (e) {
      debugPrint('[SOSScreen] Error checking active SOS: $e');
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _otherCtrl.dispose();
    _manualLocationCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  // ── GPS ──────────────────────────────────────────────────────────────────
  Future<void> _fetchLocation() async {
    setState(() { _gpsLoading = true; _gpsError = null; });

    // 1. Check & request permission
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied) {
      setState(() {
        _gpsError = 'Location permission denied. Please allow location access in your browser and try again.';
        _gpsLoading = false;
        _currentPosition = _fallbackLatLng;
      });
      return;
    }

    // 2. Check if location services are enabled on device
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _gpsError = 'Location services are off. Please enable GPS.';
        _gpsLoading = false;
        _currentPosition = _fallbackLatLng;
      });
      return;
    }

    // 3. Build platform-specific settings.
    // On web: WebSettings with maximumAge: Duration.zero forces the browser
    // to request a FRESH position — not a stale cached/IP-based estimate.
    // On mobile: use high-accuracy native GPS.
    final LocationSettings locationSettings;
    if (kIsWeb) {
      locationSettings = WebSettings(
        accuracy: LocationAccuracy.high,
        maximumAge: Duration.zero, // ← critical: forces fresh reading
        distanceFilter: 0,
      );
    } else {
      locationSettings = LocationSettings(
        accuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 20),
      );
    }

    // 4. Get position
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(pos.latitude, pos.longitude);
          _gpsLoading = false;
          _gpsError = null;
          _isManualLocation = false;
        });
      }
    } catch (e) {
      debugPrint('[SOSScreen] GPS error: $e');
      if (mounted) {
        setState(() {
          _gpsError = 'GPS failed — tap the map to set your location manually.';
          _gpsLoading = false;
          _currentPosition = _fallbackLatLng;
        });
      }
    }
  }

  // Two-step cancel confirmation
  Future<void> _confirmCancel() async {
    final keepSOS = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel SOS?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'Help may have already been dispatched to your location.\nAre you sure you want to cancel?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keep SOS'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel Anyway',
                style: TextStyle(color: AppTheme.emergency)),
          ),
        ],
      ),
    );
    if (keepSOS == false) {
      setState(() {
        _step = _SOSStep.idle;
        _situations.clear();
        _showOtherField = false;
        _currentPosition = null;
        _manualLocationCtrl.clear();
        _incidentId = null;
      });
    }
  }

  Future<void> _confirmNewSOS() async {
    final act = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Batal SOS Terdahulu? / Cancel Current SOS?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'Anda pasti ingin membatalkan laporan SOS sedia ada untuk membuat permohonan baharu?\n\nAre you sure you want to cancel your active SOS to create a new one?',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: AppTheme.emergency),
                child: const FittedBox(
                  fit: BoxFit.scaleDown, 
                  child: Text('Batal & Baharu / Cancel & New')
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Kekal / Keep', style: TextStyle(color: AppTheme.textSecondary)),
              ),
            ],
          ),
        ],
      ),
    );
    if (act == true) {
      if (_incidentId != null) {
        FirebaseFirestore.instance
            .collection('incidents')
            .where('sos_id', isEqualTo: _incidentId)
            .get()
            .then((snap) {
          for (var doc in snap.docs) {
            doc.reference.update({'status': 'CANCELLED'});
          }
        }).catchError((_) {});

        // Also cancel any mission offers linked to this SOS
        FirebaseFirestore.instance
            .collection('mission_offers')
            .where('sos_id', isEqualTo: _incidentId)
            .get()
            .then((snap) {
          for (var doc in snap.docs) {
             doc.reference.update({'status': 'CANCELLED'});
          }
        }).catchError((_) {});
      }
      setState(() {
        _step = _SOSStep.idle;
        _situations.clear();
        _showOtherField = false;
        _currentPosition = null;
        _manualLocationCtrl.clear();
        _incidentId = null;
      });
    }
  }

  Future<void> _withdrawSOS() async {
    final act = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Batal Permohonan? / Cancel SOS?', style: TextStyle(color: AppTheme.emergency)),
        content: const Text(
          'Anda pasti ingin membatalkan permohonan SOS ini?\n\nAre you sure you want to withdraw this active SOS?',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Kembali / Back', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.emergency),
            child: const Text('Batal / Withdraw'),
          ),
        ],
      ),
    );
    if (act == true && _incidentId != null) {
      FirebaseFirestore.instance
          .collection('incidents')
          .where('sos_id', isEqualTo: _incidentId)
          .get()
          .then((snap) {
        for (var doc in snap.docs) {
          doc.reference.update({'status': 'CANCELLED'});
        }
      }).catchError((_) {});

      // Also cancel any mission offers linked to this SOS
      FirebaseFirestore.instance
          .collection('mission_offers')
          .where('sos_id', isEqualTo: _incidentId)
          .get()
          .then((snap) {
        for (var doc in snap.docs) {
           doc.reference.update({'status': 'CANCELLED'});
        }
      }).catchError((_) {});
      
      if (mounted) {
        setState(() {
          _step = _SOSStep.idle;
          _situations.clear();
          _showOtherField = false;
          _currentPosition = null;
          _manualLocationCtrl.clear();
          _incidentId = null;
        });
      }
    }
  }

  Future<void> _submitSOS() async {
    setState(() => _sending = true);
    HapticFeedback.heavyImpact();
    final loc = _currentPosition ?? _fallbackLatLng;

    final sits = Set<String>.from(_situations);
    if (_showOtherField && _otherCtrl.text.trim().isNotEmpty) {
      sits.add(_otherCtrl.text.trim());
    }
    final address = _manualLocationCtrl.text.trim().isNotEmpty
        ? _manualLocationCtrl.text.trim()
        : 'GPS (${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)})';
    final description = _descriptionCtrl.text.trim();
    final rawMessage =
        'SOS! ${sits.join(', ')}. People: $_peopleCount. ${description.isNotEmpty ? 'Notes: $description. ' : ''}Location: $address. Lat: ${loc.latitude}, Lng: ${loc.longitude}.';

    try {
      final agentService = AgentService();
      final serverOnline = await agentService.isServerOnline();

      if (serverOnline) {
        final response = await agentService.submitSOS(
          rawMessage: rawMessage,
          channel: 'app',
          senderPhone: widget.phone,
          lat: loc.latitude,
          lng: loc.longitude,
        );
        // Patch the extra fields that the agent may not persist
        if (response.sosId != null) {
          FirebaseFirestore.instance
              .collection('incidents')
              .where('sos_id', isEqualTo: response.sosId)
              .get()
              .then((snap) {
            for (final doc in snap.docs) {
              doc.reference.update({
                'head_count': _peopleCount,
                'headcount': _peopleCount,
                'description': description,
                'situations': sits.toList(),
              });
            }
          }).catchError((_) {});
        }
        if (mounted) {
          setState(() {
            _incidentId = response.sosId ?? 'SOS-${DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase()}';
            _step = _SOSStep.sent;
            _sending = false;
          });
        }
      } else {
        final id = 'SOS-${DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase()}';
        FirebaseFirestore.instance.collection('incidents').add({
          'sos_id': id,
          'urgency': 'CRITICAL',
          'status': 'PENDING',
          'headcount': _peopleCount,
          'head_count': _peopleCount,
          'description': description,
          'situations': sits.toList(),
          'vulnerable': sits.where((s) => s == 'Infant/Elderly').toList(),
          'location': GeoPoint(loc.latitude, loc.longitude),
          'lat': loc.latitude,
          'lng': loc.longitude,
          'address': address,
          'address_text': address,
          'contact_name': widget.contactName,
          'sender_phone': widget.phone,
          'battery_level': 0,
          'channel': 'FLUTTER_APP_OFFLINE',
          'language': 'ms',
          'district_id': 'Klang Valley',
          'state': _getMalaysianState(loc),
          'created_at': Timestamp.now(),
        });
        if (mounted) {
          setState(() {
            _incidentId = id;
            _step = _SOSStep.sent;
            _sending = false;
          });
        }
      }
    } catch (e) {
      debugPrint('[SOSScreen] Submit error: $e');
      if (mounted) setState(() => _sending = false);
    }
  }

  String _getMalaysianState(LatLng loc) => getMalaysianState(loc);

  @override
  Widget build(BuildContext context) {
    final isMs = context.watch<LocaleProvider>().locale.languageCode == 'ms';
    final isEmergency = _step != _SOSStep.idle;
    return Scaffold(
      backgroundColor:
          isEmergency ? const Color(0xFFFFF7F7) : AppTheme.bgBase,
      appBar: AppBar(
        backgroundColor:
            isEmergency ? const Color(0xFFFEF2F2) : AppTheme.surface,
        title: Text(isMs ? 'Kecemasan SOS' : 'Emergency SOS'),
        leading: _step == _SOSStep.location || _step == _SOSStep.situation
            ? IconButton(
                icon: const Icon(Icons.arrow_back), onPressed: _confirmCancel)
            : null,
        actions: [
          if (_step == _SOSStep.sent)
            TextButton(
              onPressed: _confirmNewSOS,
              child: Text(isMs ? 'SOS Baharu' : 'New SOS',
                  style: const TextStyle(color: AppTheme.textSecondary)),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        child: _buildStep(isMs),
      ),
    );
  }

  Widget _buildStep(bool isMs) {
    switch (_step) {
      case _SOSStep.idle:
        return _buildIdle(isMs);
      case _SOSStep.situation:
        return _buildSituation(isMs);
      case _SOSStep.location:
        return _buildLocation(isMs);
      case _SOSStep.sent:
        return _buildSent(isMs);
    }
  }

  // ── Idle ─────────────────────────────────────────────────────────────────
  Widget _buildIdle(bool isMs) => Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppTheme.warningLight,
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
              isMs ? 'AMARAN: Paras air meningkat. Sedia untuk berpindah.' : 'WARNING: Water levels rising in Sg. Klang. Prepare for evacuation.',
              style: const TextStyle(
                  color: Color(0xFF92400E),
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            )),
          ]),
        ),
        Expanded(
            child: Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
              Text(isMs ? 'TEKAN LAMA UNTUK BANTUAN' : 'HOLD TO CALL FOR HELP',
                  style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      letterSpacing: 2)),
              const SizedBox(height: 48),
              ScaleTransition(
                scale: _pulseAnim,
                child: GestureDetector(
                  onTap: () {
                    setState(() => _step = _SOSStep.situation);
                    _fetchLocation(); // start GPS fetch in background
                  },
                  onLongPress: () {
                    HapticFeedback.heavyImpact();
                    setState(() => _step = _SOSStep.situation);
                    _fetchLocation();
                  },
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.emergency,
                      boxShadow: [
                        BoxShadow(
                            color: AppTheme.emergency.withAlpha(80),
                            blurRadius: 48,
                            spreadRadius: 16)
                      ],
                    ),
                    child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sos, color: Colors.white, size: 72),
                          SizedBox(height: 4),
                          Text('SOS',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 28,
                                  letterSpacing: 4)),
                        ]),
                  ),
                ),
              ),
              const SizedBox(height: 48),
              Text(isMs 
                  ? 'Sistem akan memproses SOS anda → sukarelawan dihantar.' 
                  : 'System parses your SOS → dispatches nearest volunteer.',
                  style:
                      const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            ]))),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.border))),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _InfoTile(icon: Icons.sms_outlined, label: isMs ? 'SMS 15888\nTiada internet' : 'SMS 15888\nNo internet'),
                _InfoTile(icon: Icons.chat_outlined, label: isMs ? 'Panduan Keselamatan\nMod luring' : 'Safety Guide\nOffline mode'),
                _InfoTile(icon: Icons.cloud_done_outlined, label: isMs ? 'Firebase\nMasa Nyata' : 'Firebase\nReal-time'),
              ]),
        ),
      ]);

  // ── Situation ─────────────────────────────────────────────────────────────
  Widget _buildSituation(bool isMs) {
    final options = isMs 
        ? ['Terperangkap', 'Kecemasan Perubatan', 'Kanak-kanak/Warga Emas', 'Perlu Bot', 'Tiada Makanan/Air', 'Other']
        : ['Trapped', 'Medical Emergency', 'Infant/Elderly', 'Need Boat', 'No Food/Water', 'Other'];
    final originalOptions = ['Trapped', 'Medical Emergency', 'Infant/Elderly', 'Need Boat', 'No Food/Water', 'Other'];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isMs ? 'Apakah situasi anda?' : 'What is your situation?',
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 6),
        Text(isMs ? 'Pilih semua yang berkaitan' : 'Select all that apply / Pilih semua yang berkaitan',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        const SizedBox(height: 24),
        ...List.generate(options.length, (i) {
          final opt = options[i];
          final origOpt = originalOptions[i];
          final sel = origOpt == 'Other' ? _showOtherField : _situations.contains(origOpt);
          return GestureDetector(
            onTap: () {
              if (origOpt == 'Other') {
                setState(() => _showOtherField = !_showOtherField);
              } else {
                setState(() => sel ? _situations.remove(origOpt) : _situations.add(origOpt));
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: sel ? AppTheme.emergencyLight : AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: sel ? AppTheme.emergency : AppTheme.border,
                    width: sel ? 2 : 1),
              ),
              child: Row(children: [
                Icon(_situationIcon(origOpt),
                    color: sel ? AppTheme.emergency : AppTheme.textSecondary,
                    size: 22),
                const SizedBox(width: 14),
                Text(origOpt == 'Other' ? (isMs ? 'Lain-lain' : 'Other') : opt,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: sel ? AppTheme.emergency : AppTheme.textPrimary)),
                const Spacer(),
                if (sel) const Icon(Icons.check_circle, color: AppTheme.emergency, size: 20),
              ]),
            ),
          );
        }),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _showOtherField
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: _otherCtrl,
                    autofocus: true,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.black, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: isMs ? 'Taip kecemasan khusus anda di sini...' : 'Type your specific emergency here...',
                      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                      prefixIcon: const Icon(Icons.edit_outlined, color: AppTheme.govBlue),
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
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => setState(() => _step = _SOSStep.location),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emergency),
            child: Text(isMs ? 'Sahkan Situasi →' : 'Confirm Situation →'),
          ),
        ),
      ]),
    );
  }

  IconData _situationIcon(String s) {
    switch (s) {
      case 'Trapped':
        return Icons.lock_outline;
      case 'Medical Emergency':
        return Icons.medical_services_outlined;
      case 'Infant/Elderly':
        return Icons.child_care;
      case 'Need Boat':
        return Icons.directions_boat_outlined;
      case 'No Food/Water':
        return Icons.water_drop_outlined;
      default:
        return Icons.help_outline;
    }
  }

  // ── Location ──────────────────────────────────────────────────────────────
  Widget _buildLocation(bool isMs) {
    final loc = _currentPosition ?? _fallbackLatLng;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isMs ? 'Sahkan Lokasi Anda' : 'Confirm Your Location',
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 6),
        Text(
          _gpsLoading
              ? (isMs ? 'Mendapatkan GPS...' : 'Getting your GPS position...')
              : _isManualLocation
                  ? (isMs ? 'Lokasi dilaras secara manual' : 'Location manually adjusted')
                  : (_currentPosition != null && _currentPosition != _fallbackLatLng)
                      ? (isMs ? 'GPS dikesan & dikunci' : 'GPS detected & locked')
                      : (isMs ? 'Menggunakan fallback kawasan' : 'Using area fallback'),
          style: TextStyle(
              color: (_gpsError != null && !_isManualLocation) ? AppTheme.warning : _isManualLocation ? AppTheme.govBlue : AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: _isManualLocation ? FontWeight.w600 : FontWeight.normal),
        ),
        if (!_gpsLoading) ...[
          const SizedBox(height: 4),
          Text(
            isMs ? 'Sentuh peta untuk melaras pin' : 'Tap the map to adjust the pin',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ],
        const SizedBox(height: 20),

        // ── Embedded OpenStreetMap ─────────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 220,
            child: _gpsLoading
                ? Container(
                    color: AppTheme.surface,
                    child: Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(strokeWidth: 2),
                            const SizedBox(height: 16),
                            Text(isMs ? 'Mencari lokasi anda...' : 'Finding your location...',
                                style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13)),
                          ]),
                    ),
                  )
                : _OSMLocationMap(
                    location: loc,
                    onTap: (point) {
                      setState(() {
                        _currentPosition = point;
                        _isManualLocation = true;
                      });
                    },
                  ),
          ),
        ),
        const SizedBox(height: 14),

        // ── Manual Location Fallback ───────────────────────────────────────
        TextField(
          controller: _manualLocationCtrl,
          decoration: InputDecoration(
            hintText: isMs ? 'Taip mercu tanda aras...' : 'Type your specific landmark or exact address...',
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            prefixIcon: const Icon(Icons.location_city, color: AppTheme.govBlue),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
        const SizedBox(height: 14),

        // Location chip
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border)),
          child: Row(children: [
            Icon(
              _gpsLoading
                  ? Icons.gps_not_fixed
                  : _gpsError != null
                      ? Icons.warning_amber_rounded
                      : Icons.my_location,
              color: _gpsError != null ? AppTheme.warning : AppTheme.govBlue,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                    _gpsLoading
                        ? (isMs ? 'Mendapatkan signal GPS...' : 'Acquiring GPS signal...')
                        : _gpsError != null
                            ? (isMs ? 'Zon alternatif diaktifkan' : 'Area fallback active')
                            : (isMs ? 'Lokasi GPS Aktif' : 'GPS Location Active'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _gpsLoading
                        ? (isMs ? 'Sila tunggu' : 'Please wait')
                        : _currentPosition != null
                            ? '${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}'
                            : (isMs ? 'Menggunakan koordinat kawasan' : 'Using area coordinates'),
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ])),
            if (!_gpsLoading)
              Icon(
                _gpsError != null ? Icons.circle : Icons.circle,
                color: _gpsError != null ? AppTheme.warning : AppTheme.hope,
                size: 10,
              ),
          ]),
        ),

        // Retry GPS button if error
        if (_gpsError != null && !_gpsLoading) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _fetchLocation,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(isMs ? 'Cuba GPS Semula' : 'Retry GPS'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.govBlue),
          ),
        ],

        const SizedBox(height: 20),

        // ── Number of people selector ──────────────────────────────────────
        Text(
          isMs ? 'Bilangan orang yang memerlukan bantuan' : 'Number of people needing help',
          style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(5, (index) {
            final count = index + 1;
            final selected = _peopleCount == count;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _peopleCount = count),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 52,
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.emergency : AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? AppTheme.emergency : AppTheme.border,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$count',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: selected ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        isMs ? 'org' : 'pax',
                        style: TextStyle(
                          fontSize: 10,
                          color: selected ? Colors.white70 : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),

        // ── Description field ──────────────────────────────────────────────
        Text(
          isMs ? 'Penerangan tambahan (pilihan)' : 'Additional description (optional)',
          style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionCtrl,
          maxLines: 3,
          maxLength: 200,
          style: const TextStyle(color: Colors.black, fontSize: 14),
          decoration: InputDecoration(
            hintText: isMs
                ? 'Contoh: Kami terperangkap di tingkat 2, ada warga emas...'
                : 'e.g. We are on the 2nd floor, there is an elderly person...',
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            prefixIcon: const Icon(Icons.description_outlined, color: AppTheme.govBlue),
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
            counterStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
          ),
        ),

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_sending || _gpsLoading) ? null : _submitSOS,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.sos, size: 20),
            label: Text(_sending
                ? (isMs ? 'Menghantar SOS...' : 'Sending SOS...')
                : _gpsLoading
                    ? (isMs ? 'Menunggu GPS...' : 'Waiting for GPS...')
                    : (isMs ? 'HANTAR SOS SEKARANG' : 'SEND SOS NOW')),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emergency,
                padding: const EdgeInsets.symmetric(vertical: 18)),
          ),
        ),
      ]),
    );
  }

  // ── Sent ─────────────────────────────────────────────────────────────────
  Widget _buildSent(bool isMs) {
    if (_incidentId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('incidents')
          .where('sos_id', isEqualTo: _incidentId)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = docs.first.data() as Map<String, dynamic>;
        final status = data['status'] as String? ?? 'PENDING';
        final rescuerLat = data['rescuer_lat'] as double?;
        final rescuerLng = data['rescuer_lng'] as double?;
        
        final loc = _currentPosition ?? _fallbackLatLng;
        
        bool volunteerIsNear = false;
        double? distanceMeters;
        if (rescuerLat != null && rescuerLng != null) {
          distanceMeters = Geolocator.distanceBetween(
              loc.latitude, loc.longitude, rescuerLat, rescuerLng);
          if (distanceMeters < 150) {
            volunteerIsNear = true;
          }
        }
        
        final steps = [
          (isMs ? 'SOS Diterima' : 'SOS Received', isMs ? 'Membaca permohonan...' : 'Processing request...', AppTheme.hope, Icons.sos),
        ];

        if (status == 'ASSIGNED' || status == 'DISPATCHED' || status == 'RESCUED' || status == 'RESOLVED') {
          steps.add((isMs ? 'Bantuan Dihantar' : 'Rescue Assigned', isMs ? 'Sukarelawan sedang dalam perjalanan!' : 'Volunteer is on the way!', AppTheme.warning, Icons.directions_run));
        }
        if (status == 'RESCUED' || status == 'RESOLVED') {
          steps.add((isMs ? 'Misi Selesai' : 'Mission Complete', isMs ? 'Mangsa berjaya diselamatkan.' : 'Victim successfully rescued.', AppTheme.hope, Icons.check_circle));
        }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (status == 'RESOLVED')
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.hope,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: AppTheme.hope.withAlpha(80), blurRadius: 10, spreadRadius: 2),
              ],
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isMs ? 'BANTUAN SUDAH TIBA!' : 'HELP HAS ARRIVED!', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(isMs ? 'Misi menyelamat telah selesai. Terima kasih kepada sukarelawan.' : 'Rescue mission complete. Thank you to the volunteers.',
                        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3)),
                  ],
                ),
              ),
            ]),
          ),

        if (volunteerIsNear && status != 'RESCUED' && status != 'RESOLVED')
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.emergency,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: AppTheme.emergency.withAlpha(80), blurRadius: 10, spreadRadius: 2),
              ],
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SUKARELAWAN HAMPIR TIBA!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text('Jarak: ${distanceMeters!.toStringAsFixed(0)} meter. Sila bersedia dan pastikan anda boleh dilihat dari luar.',
                        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3)),
                  ],
                ),
              ),
            ]),
          ),
          
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: AppTheme.hopeLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.hope.withAlpha(60))),
          child: Column(children: [
            const CircleAvatar(
                radius: 32,
                backgroundColor: AppTheme.hope,
                child: Icon(Icons.check, color: Colors.white, size: 36)),
            const SizedBox(height: 16),
            Text(isMs ? 'Bantuan sedang tiba!' : 'Help is on the way!',
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: AppTheme.hope)),
            const SizedBox(height: 4),
            Text(isMs ? 'Bantuan sedang menuju ke lokasi anda.' : 'Help is heading to your location right now.',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            if (_incidentId != null) ...[
              const SizedBox(height: 8),
              Text('Ref: $_incidentId',
                  style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      fontFamily: 'monospace')),
            ],
          ]),
        ),
        const SizedBox(height: 16),

        if (status != 'PENDING') ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (status == 'RESCUED' || status == 'RESOLVED') ? AppTheme.hope : AppTheme.govBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Icon((status == 'RESCUED' || status == 'RESOLVED') ? Icons.check_circle : Icons.directions_run, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text((status == 'RESCUED' || status == 'RESOLVED') 
                          ? (isMs ? 'Penyelamatan Selesai!' : 'Rescue Complete!') 
                          : (isMs ? 'Bantuan Dihantar!' : 'Help Assigned!'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15)),
                    const SizedBox(height: 2),
                    Text((status == 'RESCUED' || status == 'RESOLVED') 
                          ? (isMs ? 'Misi menyelamat telah ditanda selesai.' : 'The rescue mission has been marked completed by the volunteer.') 
                          : (isMs ? 'Sukarelawan sedang dalam perjalanan.' : 'A volunteer has accepted the mission and is en-route.'),
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ])),
            ]),
          ),
          const SizedBox(height: 16),
        ],

        // ── Rescue map using real GPS location ─────────────────────────────
        ClipRect(
          child: SizedBox(
            height: 220,
            child: SOSMapView(
              victimLocation: loc,
              rescuerLocation: rescuerLat != null && rescuerLng != null
                  ? LatLng(rescuerLat, rescuerLng)
                  : LatLng(loc.latitude + 0.0064, loc.longitude - 0.0062),
              rescuerName: 'Rescue Volunteer',
              reliefCenters: [
                LatLng(loc.latitude - 0.0027, loc.longitude + 0.0067),
                LatLng(loc.latitude - 0.0058, loc.longitude - 0.0083),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        Text(isMs ? 'Status Penyelamatan Masa Nyata' : 'Live Rescue Status',
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 14),
        ...steps.asMap().entries.map((e) {
          final i = e.key;
          final s = e.value;
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              CircleAvatar(
                  radius: 18,
                  backgroundColor: s.$3,
                  child: Icon(s.$4, color: Colors.white, size: 18)),
              if (i < steps.length - 1)
                Container(width: 2, height: 36, color: AppTheme.border),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.$1,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppTheme.textPrimary)),
                      Text(s.$2,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                    ]),
              ),
            ),
          ]);
        }),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppTheme.govBlueLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.govBlue.withAlpha(40))),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.smart_toy_outlined,
                      color: AppTheme.govBlue, size: 20),
                  const SizedBox(width: 8),
                  Text(isMs ? 'Panduan Kecemasan AI' : 'AI Emergency Guide',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.govBlue)),
                ]),
                const SizedBox(height: 8),
                Text(
                    isMs
                        ? '• Kekal di tingkat paling tinggi\n• Jangan sentuh soket elektrik\n• Kibarkan kain lurus dari tingkap\n• Simpan bateri — guna Mod Kapal Terbang'
                        : '• Stay on the highest floor\n• Do not touch electrical sockets\n• Wave a bright cloth from the window\n• Keep phone battery — use Airplane Mode',
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        height: 1.6)),
              ]),
        ),
        if (status == 'PENDING' || status == 'ASSIGNED') ...[
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _withdrawSOS,
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Tarik Balik SOS / Withdraw SOS', style: TextStyle(fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.emergency,
                side: const BorderSide(color: AppTheme.emergency),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ]),
    );
    });
  }
}

/// OpenStreetMap location widget — shows SOS pin centred on [location].
class _OSMLocationMap extends StatefulWidget {
  final LatLng location;
  final Function(LatLng)? onTap;
  const _OSMLocationMap({required this.location, this.onTap});

  @override
  State<_OSMLocationMap> createState() => _OSMLocationMapState();
}

class _OSMLocationMapState extends State<_OSMLocationMap> {
  final MapController _ctrl = MapController();

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _ctrl,
      options: MapOptions(
        initialCenter: widget.location,
        initialZoom: 16,
        onTap: (tapPosition, point) {
          if (widget.onTap != null) {
            widget.onTap!(point);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.floodsense.floodsense',
        ),
        MarkerLayer(markers: [
          Marker(
            point: widget.location,
            width: 44,
            height: 44,
            child: const Icon(Icons.location_pin, color: Colors.red, size: 44),
          ),
        ]),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Column(children: [
        Icon(icon, color: AppTheme.textSecondary, size: 20),
        const SizedBox(height: 4),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
      ]);
}
