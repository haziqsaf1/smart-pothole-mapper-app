/// Represents a single photo or video captured for a hazard, stored under
/// `hazards/{hazardId}/media/{mediaId}` in the Realtime Database.
class MediaItem {
  final String id;
  final String hazardId;
  final String type; // "photo" | "video"
  final String url;
  final String thumbnailUrl;
  final int durationSec; // only meaningful for videos
  final String caption;
  final int capturedAt; // epoch millis
  final String severity; // inherited from parent hazard
  final String locationName; // inherited from parent hazard

  MediaItem({
    required this.id,
    required this.hazardId,
    required this.type,
    required this.url,
    required this.thumbnailUrl,
    required this.durationSec,
    required this.caption,
    required this.capturedAt,
    required this.severity,
    required this.locationName,
  });

  bool get isVideo => type == 'video';

  factory MediaItem.fromMap(
    String id,
    Map<dynamic, dynamic> map, {
    required String hazardId,
    required String severity,
    required String locationName,
  }) {
    return MediaItem(
      id: id,
      hazardId: hazardId,
      type: (map['type'] ?? '').toString().toLowerCase(),
      url: (map['url'] ?? '').toString(),
      thumbnailUrl: (map['thumbnail_url'] ?? map['url'] ?? '').toString(),
      durationSec: _toInt(map['duration_sec']),
      caption: (map['caption'] ?? '').toString(),
      capturedAt: _toInt(map['captured_at']),
      severity: severity,
      locationName: locationName,
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }
}
