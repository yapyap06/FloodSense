class SOSPayloadBuilder {
  static Map<String, dynamic> build({
    required int batteryPct,
    int headCount = 1,
    List<String> vulnerable = const [],
    String address = 'Unknown location',
  }) {
    return {
      'sos_id': 'SOS-${DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase()}',
      'urgency': 'CRITICAL',
      'status': 'PENDING',
      'head_count': headCount,
      'vulnerable': vulnerable,
      'address_text': address,
      'channel': 'APP',
      'language': 'ms',
      'floor_level': 1,
      'district_id': 'Klang Valley',
      'battery_pct': batteryPct,
      'created_at': DateTime.now().toIso8601String(),
      'source': 'flutter_web',
    };
  }
}
