import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';

/// Embedded OpenStreetMap widget showing victim + rescuer pins with a connecting polyline.
class SOSMapView extends StatefulWidget {
  final LatLng victimLocation;
  final LatLng? rescuerLocation;
  final String? rescuerName;
  final List<LatLng> reliefCenters;

  const SOSMapView({
    super.key,
    required this.victimLocation,
    this.rescuerLocation,
    this.rescuerName,
    this.reliefCenters = const [],
  });

  @override
  State<SOSMapView> createState() => _SOSMapViewState();
}

class _SOSMapViewState extends State<SOSMapView> {
  final MapController _mapController = MapController();

  LatLngBounds _computeBounds() {
    final all = <LatLng>[widget.victimLocation];
    if (widget.rescuerLocation != null) all.add(widget.rescuerLocation!);
    all.addAll(widget.reliefCenters);
    final lats = all.map((p) => p.latitude).toList();
    final lngs = all.map((p) => p.longitude).toList();
    return LatLngBounds(
      LatLng(lats.reduce((a, b) => a < b ? a : b) - 0.005,
          lngs.reduce((a, b) => a < b ? a : b) - 0.005),
      LatLng(lats.reduce((a, b) => a > b ? a : b) + 0.005,
          lngs.reduce((a, b) => a > b ? a : b) + 0.005),
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[
      // Victim pin (blue)
      Marker(
        point: widget.victimLocation,
        width: 44,
        height: 44,
        child: const Icon(Icons.my_location, color: Color(0xFF1A73E8), size: 40),
      ),
      // Rescuer pin (green)
      if (widget.rescuerLocation != null)
        Marker(
          point: widget.rescuerLocation!,
          width: 44,
          height: 44,
          child: const Icon(Icons.directions_run, color: Color(0xFF16A34A), size: 40),
        ),
      // PPS / Relief centre pins (amber)
      ...widget.reliefCenters.map((loc) => Marker(
            point: loc,
            width: 40,
            height: 40,
            child: const Icon(Icons.home_work, color: Color(0xFFF59E0B), size: 36),
          )),
    ];

    final polylines = widget.rescuerLocation != null
        ? [
            Polyline(
              points: [widget.rescuerLocation!, widget.victimLocation],
              color: AppTheme.govBlue,
              strokeWidth: 4,
            )
          ]
        : <Polyline>[];

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: widget.victimLocation,
          initialZoom: 14,
          onMapReady: () {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                _mapController.fitCamera(
                  CameraFit.bounds(
                    bounds: _computeBounds(),
                    padding: const EdgeInsets.all(60),
                  ),
                );
              }
            });
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.floodsense.floodsense',
          ),
          CircleLayer(circles: [
            CircleMarker(
              point: widget.victimLocation,
              radius: 500,
              useRadiusInMeter: true,
              color: const Color(0x221A73E8),
              borderColor: const Color(0xFF1A73E8),
              borderStrokeWidth: 2,
            ),
          ]),
          PolylineLayer(polylines: polylines),
          MarkerLayer(markers: markers),
        ],
      ),
    );
  }
}
