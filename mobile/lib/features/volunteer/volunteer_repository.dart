import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for a volunteer's profile
class VolunteerProfile {
  final String uid;
  final String name;
  final String icNumber;
  final String phone;
  final List<String> skills;
  final String vehicleType;
  final int vehicleCapacity;
  final bool standingConsent;
  final String status; // AVAILABLE, ON_MISSION, UNAVAILABLE

  VolunteerProfile({
    required this.uid,
    required this.name,
    required this.icNumber,
    required this.phone,
    required this.skills,
    required this.vehicleType,
    required this.vehicleCapacity,
    required this.standingConsent,
    this.status = 'AVAILABLE',
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'ic_number_last4': icNumber.length >= 4 ? icNumber.substring(icNumber.length - 4) : icNumber,
        'phone': phone,
        'skills': skills,
        'vehicle_type': vehicleType,
        'vehicle_capacity': vehicleCapacity,
        'standing_consent': standingConsent,
        'status': status,
        'apm_verified': false,
        'updated_at': FieldValue.serverTimestamp(),
      };
}

class VolunteerRepository {
  final _db = FirebaseFirestore.instance;

  Future<void> save(String uid, VolunteerProfile v) =>
      _db.collection('volunteers').doc(uid).set(v.toMap(), SetOptions(merge: true));

  Stream<DocumentSnapshot<Map<String, dynamic>>> watch(String uid) =>
      _db.collection('volunteers').doc(uid).snapshots();

  Future<void> updateStatus(String uid, String status) =>
      _db.collection('volunteers').doc(uid).update({'status': status});

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMissionOffers(String uid) => _db
      .collection('mission_offers')
      .where('volunteer_id', isEqualTo: uid)
      .where('status', isEqualTo: 'OFFERED')
      .snapshots();

  Future<void> respondToMission(String missionId, String response, String sosId) async {
    final updates = <String, dynamic>{'status': response};
    if (response == 'ACCEPTED') {
      updates['accepted_at'] = FieldValue.serverTimestamp();
    }
    await _db.collection('mission_offers').doc(missionId).set(updates, SetOptions(merge: true));
    if (response == 'ACCEPTED') {
      await _db.collection('incidents').doc(sosId).update({
        'assigned_volunteer': missionId,
        // Use 'ASSIGNED' to match GovSOSScreen filter chips (PENDING/ASSIGNED/RESOLVED)
        'status': 'ASSIGNED',
      });
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchCompletedMissions(String uid) => _db
      .collection('mission_offers')
      .where('volunteer_id', isEqualTo: uid)
      .where('status', isEqualTo: 'COMPLETED')
      .snapshots();

  Future<void> updateConsent(String uid, bool consent) =>
      _db.collection('volunteers').doc(uid).set({'standing_consent': consent}, SetOptions(merge: true));
}
