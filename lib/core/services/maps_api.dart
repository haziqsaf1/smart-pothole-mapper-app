import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'firebase_service.dart';

import '../models/hazard.dart';

/// Map tab. Reads every child under `hazards/` in the "Map-API" Realtime
/// Database in real time and plots one marker per hazard, colored by
/// severity, plus a blue "My Phone" marker from the device's live GPS.

void fetchMapData() async {
  final ref = DatabaseService.mapApiDb('hazards'); // targets "Map-API" database
  await ref.get();
}

class MapsApiPage extends StatefulWidget {
  const MapsApiPage({super.key});

  @override
  State<MapsApiPage> createState() => _MapsApiPageState();
}

class _MapsApiPageState extends State<MapsApiPage> {
  final DatabaseReference _hazardsRef = DatabaseService.mapApiDb('hazards');

  final MapController _mapController = MapController();

  LatLng? _myPosition;
  StreamSubscription<Position>? _positionSub;
  bool _hasCenteredOnUser = false;

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  Future<void> _startLocationTracking() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return; // Map still works, it just won't show "My Phone".
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((position) {
          if (!mounted) return;
          final newPos = LatLng(position.latitude, position.longitude);

          setState(() {
            _myPosition = newPos;
          });

          if (!_hasCenteredOnUser) {
            _hasCenteredOnUser = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _mapController.move(newPos, 16.2);
            });
          }
        });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'critical':
        return const Color(0xFFE53935);
      case 'moderate':
        return const Color(0xFFFB8C00);
      case 'minor':
        return const Color(0xFFFDD835);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DatabaseEvent>(
        stream: _hazardsRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Unable to load hazards: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final hazards = <Hazard>[];
          final raw = snapshot.data?.snapshot.value;
          if (raw is Map) {
            raw.forEach((key, value) {
              if (value is Map) {
                final hazard = Hazard.fromMap(key.toString(), value);
                final latitude = hazard.latitude;
                final longitude = hazard.longitude;
                if (latitude != null &&
                    longitude != null &&
                    latitude >= -90 &&
                    latitude <= 90 &&
                    longitude >= -180 &&
                    longitude <= 180) {
                  hazards.add(hazard);
                }
              }
            });
          }

          // Sort hazards by highest priority score first
          hazards.sort(
            (a, b) => (b.priorityScore ?? 0).compareTo(a.priorityScore ?? 0),
          );

          if (_myPosition == null && hazards.isEmpty) {
            return const Center(
              child: Text(
                'No hazard coordinates or device location available.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final markers = <Marker>[
            for (int i = 0; i < hazards.length; i++)
              Marker(
                point: LatLng(hazards[i].latitude!, hazards[i].longitude!),
                width: 52,
                height: 52,
                child: GestureDetector(
                  onTap: () =>
                      _showHazardDetailSheet(context, hazards[i], i + 1),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Main Hazard Marker Icon
                      Center(
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _severityColor(hazards[i].severity),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(color: Colors.black45, blurRadius: 4),
                            ],
                          ),
                          child: const Icon(
                            Icons.warning,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      // Priority Rank Badge Circle (#1, #2, #3...)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 22,
                            minHeight: 22,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: const [
                              BoxShadow(color: Colors.black38, blurRadius: 2),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '#${i + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_myPosition != null)
              Marker(
                point: _myPosition!,
                width: 22,
                height: 22,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 4),
                    ],
                  ),
                ),
              ),
          ];

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter:
                      _myPosition ??
                      LatLng(hazards.first.latitude!, hazards.first.longitude!),
                  initialZoom: 16.2,
                  minZoom: 2,
                  maxZoom: 19.5,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.main_app_spm',
                  ),
                  MarkerLayer(markers: markers),
                ],
              ),

              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: _HeaderBanner(hazardCount: hazards.length),
              ),
              Positioned(
                right: 16,
                bottom: 90,
                child: FloatingActionButton(
                  heroTag: 'recenter',
                  backgroundColor: const Color(0xFF1C1C1E),
                  onPressed: () {
                    final target =
                        _myPosition ??
                        LatLng(
                          hazards.first.latitude!,
                          hazards.first.longitude!,
                        );
                    _mapController.move(target, 16.2);
                  },
                  child: const Icon(
                    Icons.my_location,
                    color: Color(0xFF3B82F6),
                  ),
                ),
              ),
              const Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: _Legend(),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showHazardDetailSheet(BuildContext context, Hazard hazard, int rank) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) =>
          _HazardDetailBottomSheet(hazard: hazard, rank: rank),
    );
  }
}

class _HazardDetailBottomSheet extends StatefulWidget {
  final Hazard hazard;
  final int rank;

  const _HazardDetailBottomSheet({required this.hazard, required this.rank});

  @override
  State<_HazardDetailBottomSheet> createState() =>
      _HazardDetailBottomSheetState();
}

class _HazardDetailBottomSheetState extends State<_HazardDetailBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
      case 'serious':
        return const Color(0xFFE53935);
      case 'moderate':
        return const Color(0xFFFB8C00);
      case 'minor':
        return const Color(0xFFFDD835);
      default:
        return Colors.grey;
    }
  }

  String _timeAgo(int? timestampMs) {
    if (timestampMs == null || timestampMs <= 0) return '-';
    final diff = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(timestampMs),
    );
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat(
      'd MMM',
    ).format(DateTime.fromMillisecondsSinceEpoch(timestampMs));
  }

  @override
  Widget build(BuildContext context) {
    final hazard = widget.hazard;
    final color = _severityColor(hazard.severity);
    final formattedDate = hazard.timestamp != null && hazard.timestamp! > 0
        ? DateFormat(
            'yyyy-MM-dd HH:mm',
          ).format(DateTime.fromMillisecondsSinceEpoch(hazard.timestamp!))
        : '-';

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF161618),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hazard.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                Icons.push_pin,
                                color: Colors.orangeAccent,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${hazard.locationName} • ${_timeAgo(hazard.timestamp)}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF3B82F6),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFF3B82F6),
                tabs: [
                  const Tab(text: 'Details'),
                  Tab(text: 'Evidence (${hazard.media.length})'),
                ],
              ),
              const Divider(height: 1, color: Colors.white10),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      children: [
                        if (hazard.description.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.redAccent.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              hazard.description,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        _InfoCard(
                          icon: Icons.track_changes,
                          iconColor: Colors.redAccent,
                          title: 'How sure are we?',
                          value: hazard.priorityScore == null
                              ? '-'
                              : '${hazard.priorityScore}% confident',
                        ),
                        const SizedBox(height: 10),
                        _InfoCard(
                          icon: Icons.straighten,
                          iconColor: Colors.amberAccent,
                          title: 'Size of damage',
                          value:
                              '${hazard.widthCm?.toStringAsFixed(0) ?? '-'} cm wide • ${hazard.depthCm?.toStringAsFixed(0) ?? '-'} cm deep',
                        ),
                        const SizedBox(height: 10),
                        _InfoCard(
                          icon: Icons.access_time,
                          iconColor: Colors.lightBlueAccent,
                          title: 'Detected at',
                          value: formattedDate,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Vibration',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    hazard.vibrationG?.toStringAsFixed(2) ??
                                        '-',
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'G',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    hazard.media.isEmpty
                        ? const Center(
                            child: Text(
                              'No evidence photos attached',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : GridView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.all(20),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                            itemCount: hazard.media.length,
                            itemBuilder: (context, index) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  hazard.media[index].thumbnailUrl,
                                  fit: BoxFit.cover,
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF161618),
                  border: Border(top: BorderSide(color: Colors.white10)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E2923),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Colors.greenAccent),
                      ),
                    ),
                    onPressed: () async {
                      await DatabaseService.mapApiDb(
                        'hazards/${hazard.id}',
                      ).update({'status': 'resolved'});
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check, color: Colors.greenAccent),
                        SizedBox(width: 8),
                        Text(
                          'Mark as Fixed',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBanner extends StatelessWidget {
  final int hazardCount;
  const _HeaderBanner({required this.hazardCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hazard Map',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Live Database',
                style: TextStyle(color: Colors.greenAccent, fontSize: 12),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red),
            ),
            child: Text(
              '$hazardCount Hazards Detected',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget dot(Color color, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          dot(const Color(0xFF3B82F6), 'My Device'),
          dot(const Color(0xFFE53935), 'Critical'),
          dot(const Color(0xFFFB8C00), 'Moderate'),
          dot(const Color(0xFFFDD835), 'Minor'),
        ],
      ),
    );
  }
}
