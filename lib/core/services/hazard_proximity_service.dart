import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'firebase_service.dart';
import 'notification_service.dart';

class HazardProximityService {
  final DatabaseReference _hazardsRef = DatabaseService.mapApiDb('hazards');

  StreamSubscription<Position>? _positionStream;
  List<Map<String, dynamic>> _cachedHazards = [];

  /// Initialize location streaming and database syncing
  void startMonitoring({double warningRadiusMeters = 200.0}) async {
    if (kIsWeb) return;

    // 1. Verify location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    // 2. Fetch hazards from Realtime Database and keep synced
    _hazardsRef.onValue.listen((event) {
      final data = event.snapshot.value;
      final List<Map<String, dynamic>> tempHazards = [];

      if (data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            final latitude = double.tryParse(
              value['latitude']?.toString() ?? '',
            );
            final longitude = double.tryParse(
              value['longitude']?.toString() ?? '',
            );
            if (latitude == null ||
                longitude == null ||
                latitude < -90 ||
                latitude > 90 ||
                longitude < -180 ||
                longitude > 180) {
              return;
            }
            tempHazards.add({
              'id': key.toString(),
              'lat': latitude,
              'lng': longitude,
              'severity': (value['severity'] ?? '').toString(),
              'locationName': (value['location_name'] ?? '').toString(),
            });
          }
        });
      }
      _cachedHazards = tempHazards;
    });

    // 3. Start high-accuracy GPS tracking stream
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Check distance every 10 meters moved
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position userPosition) {
            _checkProximity(userPosition, warningRadiusMeters);
          },
        );
  }

  /// Calculate distance to all known potholes
  void _checkProximity(Position userPosition, double warningRadius) {
    for (final hazard in _cachedHazards) {
      final double distanceInMeters = Geolocator.distanceBetween(
        userPosition.latitude,
        userPosition.longitude,
        hazard['lat'],
        hazard['lng'],
      );

      // Trigger warning if within alert zone
      if (distanceInMeters <= warningRadius) {
        final int distanceRounded = distanceInMeters.round();
        final String severity = (hazard['severity'] as String).toUpperCase();
        final String locationName = hazard['locationName'] as String;

        NotificationService.showHazardWarning(
          hazardId: hazard['id'],
          title: severity.isEmpty
              ? 'Hazard nearby'
              : 'Hazard nearby ($severity)',
          body: locationName.isEmpty
              ? 'Hazard detected $distanceRounded meters away.'
              : 'Hazard detected $distanceRounded meters away near $locationName.',
        );
      }
    }
  }

  /// Clean up streams when app stops monitoring
  void stopMonitoring() {
    _positionStream?.cancel();
  }
}
