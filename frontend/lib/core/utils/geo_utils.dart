import 'package:latlong2/latlong.dart';

/// Resolves a Malaysian state from a LatLng coordinate using simple heuristics.
String getMalaysianState(LatLng loc) {
  final lat = loc.latitude;
  final lng = loc.longitude;
  
  // East Malaysia
  if (lng > 110.0) {
    if (lat > 5.5) return 'Sabah';
    return 'Sarawak';
  }
  
  // West Malaysia
  if (lat < 2.5) return 'Johor';
  if (lat < 2.8) return 'Melaka';
  if (lat < 3.0) return 'Negeri Sembilan';
  if (lat > 5.5) return 'Kedah/Perlis';
  if (lat > 4.5) {
    if (lng > 102.0) return 'Kelantan/Terengganu';
    return 'Perak/Penang';
  }
  if (lat > 3.5) return 'Pahang';
  
  return 'Selangor'; // Includes KL/Putrajaya
}
