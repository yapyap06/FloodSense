// Run with: dart run scripts/delete_test_notifications.dart
// This deletes ALL documents from the Firestore 'notifications' collection.
// The government officer will need to re-send any real broadcasts afterward.

import 'dart:io';
import 'dart:developer';

Future<void> main() async {
  log('NOTE: Cannot access Firestore directly from a Dart script without Firebase Admin SDK.');
  log('');
  log('To delete the test notifications, go to:');
  log('  Firebase Console → https://console.firebase.google.com/');
  log('  → Your Project → Firestore Database → "notifications" collection');
  log('  → Select all documents → Delete');
  log('');
  log('OR use Firebase CLI: firebase firestore:delete --recursive notifications --project YOUR_PROJECT_ID');
  exit(0);
}
