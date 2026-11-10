import 'media_item.dart';

/// Represents a single road-hazard record stored under `hazards/{hazardId}`
/// in the "Map-API" Firebase Realtime Database.
class Hazard {
  final String id;
  final String deviceId;
  final double? latitude;
  final double? longitude;
  final String severity; // "critical" | "moderate" | "minor"
  final int? timestamp; // epoch millis
  final double? vibrationG;
  final double? widthCm;
  final double? depthCm;
  final String locationName;
  final String title;
  final String description;
  final int? priorityScore;
  final String status; // "pending" | "in_progress" | "resolved"
  final String assignedTo;
  final int? assignedAt;
  final String assignedEngine;
  final List<MediaItem> media;

  Hazard({
    required this.id,
    required this.deviceId,
    required this.latitude,
    required this.longitude,
    required this.severity,
    required this.timestamp,
    required this.vibrationG,
    required this.widthCm,
    required this.depthCm,
    required this.locationName,
    required this.title,
    required this.description,
    required this.priorityScore,
    required this.status,
    required this.assignedTo,
    required this.assignedAt,
    required this.assignedEngine,
    required this.media,
  });

  factory Hazard.fromMap(String id, Map<dynamic, dynamic> map) {
    final mediaMap = map['media'] as Map<dynamic, dynamic>?;
    final mediaList = <MediaItem>[];
    if (mediaMap != null) {
      mediaMap.forEach((key, value) {
        if (value is! Map) return;
        final item = MediaItem.fromMap(
          key.toString(),
          Map<dynamic, dynamic>.from(value),
          hazardId: id,
          severity: (map['severity'] ?? '').toString(),
          locationName: (map['location_name'] ?? '').toString(),
        );
        if (item.thumbnailUrl.isNotEmpty) mediaList.add(item);
      });
    }

    return Hazard(
      id: id,
      deviceId: (map['device_id'] ?? '').toString(),
      latitude: _toDouble(map['latitude']),
      longitude: _toDouble(map['longitude']),
      severity: (map['severity'] ?? '').toString().toLowerCase(),
      timestamp: _toInt(map['timestamp']),
      vibrationG: _toDouble(map['vibration_g']),
      widthCm: _toDouble(map['width_cm']),
      depthCm: _toDouble(map['depth_cm']),
      locationName: (map['location_name'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      priorityScore: _toInt(map['priority_score']),
      status: (map['status'] ?? '').toString(),
      assignedTo: (map['assigned_to'] ?? '').toString(),
      assignedAt: _toInt(map['assigned_at']),
      assignedEngine: (map['assigned_engine'] ?? '').toString(),
      media: mediaList,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}
