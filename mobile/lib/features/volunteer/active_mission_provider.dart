import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ActiveMissionProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription? _sub;
  Timer? _ticker;

  Map<String, dynamic>? _activeMissionData;
  String? _activeMissionId;
  Duration _elapsed = Duration.zero;

  Map<String, dynamic>? get activeMission => _activeMissionData;
  String? get missionId => _activeMissionId;
  Duration get elapsed => _elapsed;

  final String uid;

  ActiveMissionProvider(this.uid) {
    if (uid.isNotEmpty) _init(uid);
  }

  void _init(String uid) {
    _sub = _db
        .collection('mission_offers')
        .where('volunteer_id', isEqualTo: uid)
        .where('status', isEqualTo: 'ACCEPTED')
        .limit(1)
        .snapshots()
        .listen((snap) {
      if (snap.docs.isNotEmpty) {
        final doc = snap.docs.first;
        _activeMissionId = doc.id;
        _activeMissionData = doc.data();
        
        if (_activeMissionData!.containsKey('accepted_at') && _activeMissionData!['accepted_at'] != null) {
          final acceptedAt = (_activeMissionData!['accepted_at'] as Timestamp).toDate();
          _startTicker(acceptedAt);
        } else {
          _startTicker(DateTime.now());
        }
        notifyListeners();
      } else {
        _activeMissionId = null;
        _activeMissionData = null;
        _stopTicker();
        notifyListeners();
      }
    });
  }

  void _startTicker(DateTime startTime) {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsed = DateTime.now().difference(startTime);
      notifyListeners();
    });
    _elapsed = DateTime.now().difference(startTime);
    notifyListeners();
  }

  void _stopTicker() {
    _ticker?.cancel();
    _elapsed = Duration.zero;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }
}
