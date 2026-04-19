// Web stub for offline queue — on Flutter Web we delegate directly to Firestore.
// On mobile (future), this would use sqflite for persistence.
import 'package:cloud_firestore/cloud_firestore.dart';

class OfflineQueue {
  /// On web, we attempt direct Firestore write.
  /// In production mobile, this would persist locally and retry.
  static Future<void> enqueue(Map<String, dynamic> payload) async {
    await FirebaseFirestore.instance.collection('incidents').add(payload);
  }

  static Future<void> flushQueue() async {}
  static Future<int> get pendingCount async => 0;
}
