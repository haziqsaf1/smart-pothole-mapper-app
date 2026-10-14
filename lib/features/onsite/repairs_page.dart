import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/firebase_service.dart';
import '../../core/models/hazard.dart';
import 'package:main_app_spm/core/services/report_generator.dart';

class RepairsPage extends StatefulWidget {
  const RepairsPage({super.key});

  @override
  State<RepairsPage> createState() => _RepairsPageState();
}

class _RepairsPageState extends State<RepairsPage> {
  int _selectedTab = 1; // 0: Pending, 1: In Progress, 2: Fixed

  final DatabaseReference _hazardsRef = DatabaseService.mapApiDb('hazards');

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Repair Tickets',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      StreamBuilder<DatabaseEvent>(
                        stream: _hazardsRef.onValue,
                        builder: (context, snapshot) {
                          int pending = 0;
                          int active = 0;
                          int done = 0;
                          final raw = snapshot.data?.snapshot.value;
                          if (raw is Map) {
                            raw.forEach((key, value) {
                              if (value is Map) {
                                final status = (value['status'] ?? '')
                                    .toString();
                                if (status == 'resolved') {
                                  done++;
                                } else if (status == 'in_progress') {
                                  active++;
                                } else if (status == 'pending') {
                                  pending++;
                                }
                              }
                            });
                          }
                          return Text(
                            '$pending pending • $active active • $done done',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _buildSegmentTab(0, 'Pending'),
                    _buildSegmentTab(1, 'In Progress'),
                    _buildSegmentTab(2, 'Fixed'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<DatabaseEvent>(
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
                        final status = (value['status'] ?? '').toString();

                        if (_selectedTab == 0 && status == 'pending') {
                          hazards.add(hazard);
                        } else if (_selectedTab == 1 &&
                            (status == 'in_progress' || status == 'active')) {
                          hazards.add(hazard);
                        } else if (_selectedTab == 2 && status == 'resolved') {
                          hazards.add(hazard);
                        }
                      }
                    });
                  }

                  hazards.sort(
                    (a, b) =>
                        (b.priorityScore ?? 0).compareTo(a.priorityScore ?? 0),
                  );

                  if (hazards.isEmpty) {
                    return const Center(
                      child: Text(
                        'No tickets in this category',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: hazards.length,
                    itemBuilder: (context, index) {
                      final hazard = hazards[index];
                      return _buildTicketCard(context, hazard, index + 1);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentTab(int index, String title) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2C2C2E) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTicketCard(BuildContext context, Hazard hazard, int rank) {
    final color = _severityColor(hazard.severity);
    return GestureDetector(
      onTap: () => _showDetailModal(context, hazard, rank),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      '#$rank',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      hazard.title.isEmpty ? hazard.id : hazard.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    hazard.severity,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.push_pin,
                  color: Colors.orangeAccent,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  '${hazard.locationName.isEmpty ? '-' : hazard.locationName} • ${_timeAgo(hazard.timestamp)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ((hazard.priorityScore ?? 0) / 100).clamp(0.0, 1.0),
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      if (hazard.assignedTo.isNotEmpty) ...[
                        const Icon(
                          Icons.person_outline,
                          color: Colors.white70,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hazard.assignedTo,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ] else
                        const Text(
                          'Unassigned',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${hazard.priorityScore?.toString() ?? '-'}/100',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(int? timestamp) {
    if (timestamp == null || timestamp <= 0) return '-';
    final difference = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(timestamp),
    );
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return DateFormat(
      'd MMM',
    ).format(DateTime.fromMillisecondsSinceEpoch(timestamp));
  }

  void _showDetailModal(BuildContext context, Hazard hazard, int rank) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _RepairDetailSheet(hazard: hazard, rank: rank),
    );
  }
}

class _RepairDetailSheet extends StatefulWidget {
  final Hazard hazard;
  final int rank;
  const _RepairDetailSheet({required this.hazard, required this.rank});

  @override
  State<_RepairDetailSheet> createState() => _RepairDetailSheetState();
}

class _RepairDetailSheetState extends State<_RepairDetailSheet>
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

  @override
  Widget build(BuildContext context) {
    final hazard = widget.hazard;
    final formattedDate = hazard.timestamp != null && hazard.timestamp! > 0
        ? DateFormat(
            'yyyy-MM-dd HH:mm',
          ).format(DateTime.fromMillisecondsSinceEpoch(hazard.timestamp!))
        : '-';

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
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
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
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
                                hazard.locationName.isEmpty
                                    ? '-'
                                    : hazard.locationName,
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
                      icon: const Icon(
                        Icons.picture_as_pdf,
                        color: Colors.blueAccent,
                      ),
                      tooltip: 'Generate PDF Report',
                      onPressed: () async {
                        try {
                          await ReportGenerator.generateAndPrintReport({
                            'status': hazard.status,
                            'device_id': hazard.deviceId,
                            'location_name': hazard.locationName,
                            'severity': hazard.severity,
                            'priority_score': hazard.priorityScore,
                            'depth_cm': hazard.depthCm,
                            'width_cm': hazard.widthCm,
                            'vibration_g': hazard.vibrationG,
                          });
                        } catch (error) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Could not generate PDF report: $error',
                              ),
                            ),
                          );
                        }
                      },
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
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Work Order ✓'),
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            height: 180,
                            color: Colors.black45,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                hazard.media.isNotEmpty
                                    ? Image.network(
                                        hazard.media.first.thumbnailUrl,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        color: const Color(0xFF2C2C2E),
                                        child: const Center(
                                          child: Icon(
                                            Icons.camera_alt,
                                            color: Colors.white24,
                                            size: 48,
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              _specRow(
                                'GPS LOCATION',
                                '${hazard.latitude?.toStringAsFixed(5) ?? '-'}, ${hazard.longitude?.toStringAsFixed(5) ?? '-'}',
                              ),
                              const Divider(color: Colors.white10),
                              _specRow(
                                'ADDRESS',
                                hazard.locationName.isEmpty
                                    ? '-'
                                    : hazard.locationName,
                              ),
                              const Divider(color: Colors.white10),
                              _specRow(
                                'DIMENSIONS',
                                '${hazard.widthCm?.toStringAsFixed(0) ?? '-'}cm wide • ${hazard.depthCm?.toStringAsFixed(0) ?? '-'}cm deep',
                              ),
                              const Divider(color: Colors.white10),
                              _specRow(
                                'REPORTED BY',
                                hazard.deviceId.isEmpty ? '-' : hazard.deviceId,
                              ),
                              const Divider(color: Colors.white10),
                              _specRow('DETECTED', formattedDate),
                              const Divider(color: Colors.white10),
                              _specRow(
                                'CONFIDENCE',
                                '${hazard.priorityScore?.toString() ?? '-'}%',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _specRow(
                                      'ASSIGNED TO',
                                      hazard.assignedTo.isEmpty
                                          ? '-'
                                          : hazard.assignedTo,
                                    ),
                                    _specRow(
                                      'ASSIGNED AT',
                                      hazard.assignedAt == null ||
                                              hazard.assignedAt! <= 0
                                          ? '-'
                                          : DateFormat(
                                              'yyyy-MM-dd HH:mm',
                                            ).format(
                                              DateTime.fromMillisecondsSinceEpoch(
                                                hazard.assignedAt!,
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      children: [
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
                                'Work Order',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _specRow(
                                'PRIORITY SCORE',
                                '${hazard.priorityScore?.toString() ?? '-'} / 100',
                              ),
                              const Divider(color: Colors.white10),
                              _specRow(
                                'ASSIGNED ENGINE',
                                hazard.assignedEngine.isEmpty
                                    ? '-'
                                    : hazard.assignedEngine,
                              ),
                              const Divider(color: Colors.white10),
                              _specRow(
                                'STATUS',
                                hazard.status.isEmpty ? '-' : hazard.status,
                              ),
                            ],
                          ),
                        ),
                      ],
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ticket marked as Fixed!'),
                          backgroundColor: Colors.green,
                        ),
                      );
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

  Widget _specRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
