import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HouseholdProfile {
  final String fullName;
  final String address;
  final int householdSize;
  final List<String> vulnerableGroups;
  final String? phone;

  HouseholdProfile({
    required this.fullName,
    required this.address,
    required this.householdSize,
    required this.vulnerableGroups,
    this.phone,
  });

  factory HouseholdProfile.fromMap(Map<String, dynamic> m) => HouseholdProfile(
        fullName: m['full_name'] ?? '',
        address: m['address'] ?? '',
        householdSize: m['household_size'] ?? 1,
        vulnerableGroups: List<String>.from(m['vulnerable_groups'] ?? []),
        phone: m['phone'],
      );

  Map<String, dynamic> toMap() => {
        'full_name': fullName,
        'address': address,
        'household_size': householdSize,
        'vulnerable_groups': vulnerableGroups,
        'phone': phone,
        'updated_at': FieldValue.serverTimestamp(),
      };
}

class ProfileRepository {
  final _db = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

  Future<HouseholdProfile?> loadProfile() async {
    try {
      final doc = await _db.collection('users').doc(_uid).collection('profile').doc('household').get();
      if (!doc.exists) return null;
      return HouseholdProfile.fromMap(doc.data()!);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProfile(HouseholdProfile profile) async {
    await _db.collection('users').doc(_uid).collection('profile').doc('household').set(profile.toMap());
  }
}
