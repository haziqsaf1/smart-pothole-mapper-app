import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/comp_status.dart';
import '../../core/services/firebase_service.dart';
import '../../core/models/hazard.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  String _selectedFileFilter = 'All';
  bool _iotSectionExpanded = true;
  final User? _user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic> _userProfile = {};

  final DatabaseReference _hazardsRef = DatabaseService.mapApiDb('hazards');
  final DatabaseReference _filesRef = DatabaseService.mapApiDb('reports_audit');

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = _user;
    if (user == null) return;
    try {
      final document = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      setState(() => _userProfile = document.data() ?? {});
    } catch (_) {
      // Keep the authenticated Firebase identity when the profile is unavailable.
    }
  }

  String get _displayName =>
      (_userProfile['display_name'] ??
              _userProfile['name'] ??
              _userProfile['full_name'] ??
              _user?.displayName ??
              _user?.email ??
              '')
          .toString();

  Set<String> get _userIdentifiers =>
      {
            _user?.uid,
            _user?.email,
            _user?.displayName,
            _userProfile['display_name']?.toString(),
            _userProfile['name']?.toString(),
            _userProfile['full_name']?.toString(),
          }
          .whereType<String>()
          .map((value) => value.trim().toLowerCase())
          .where((value) => value.isNotEmpty)
          .toSet();

  String _formatTimestamp(dynamic value) {
    final milliseconds = value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '');
    if (milliseconds == null || milliseconds <= 0) return '-';
    return DateFormat(
      'yyyy-MM-dd HH:mm',
    ).format(DateTime.fromMillisecondsSinceEpoch(milliseconds));
  }

  // Sign out handler with dialog confirmation
  Future<void> _handleSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Confirm Sign Out',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to sign out of your session?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Sign Out',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldSignOut == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: StreamBuilder<DatabaseEvent>(
          stream: _hazardsRef.onValue,
          builder: (context, hazardSnapshot) {
            int activeCount = 0;
            int fixedCount = 0;
            int highSevCount = 0;
            final assignedProjects = <Hazard>[];
            final rawHazards = hazardSnapshot.data?.snapshot.value;

            if (rawHazards is Map) {
              rawHazards.forEach((key, value) {
                if (value is Map) {
                  final hazard = Hazard.fromMap(key.toString(), value);
                  final status = (value['status'] ?? '').toString();
                  final assignedTo = (value['assigned_to'] ?? '')
                      .toString()
                      .trim()
                      .toLowerCase();

                  if (status == 'resolved') {
                    fixedCount++;
                  } else if (status == 'pending' ||
                      status == 'in_progress' ||
                      status == 'active') {
                    activeCount++;
                  }

                  if (hazard.severity.toLowerCase() == 'serious' ||
                      hazard.severity.toLowerCase() == 'critical') {
                    highSevCount++;
                  }

                  if (_userIdentifiers.contains(assignedTo)) {
                    if (status != 'resolved') {
                      assignedProjects.add(hazard);
                    }
                  }
                }
              });
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                const Text(
                  'Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C2C2E),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Icon(
                              Icons.workspace_premium,
                              color: Colors.blueAccent,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _displayName.isEmpty
                                    ? 'No signed-in user'
                                    : _displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if ((_userProfile['role'] ?? '')
                                  .toString()
                                  .isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.purpleAccent.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.purpleAccent.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    _userProfile['role'].toString(),
                                    style: const TextStyle(
                                      color: Colors.purpleAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildMetricBox(
                            '$activeCount',
                            'Active',
                            Colors.blueAccent,
                          ),
                          const SizedBox(width: 8),
                          _buildMetricBox(
                            '$fixedCount',
                            'Fixed',
                            Colors.greenAccent,
                          ),
                          const SizedBox(width: 8),
                          _buildMetricBox(
                            '$highSevCount',
                            'High-sev',
                            Colors.redAccent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'MY PROJECTS',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                assignedProjects.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.assignment_outlined,
                              color: Colors.amber,
                              size: 32,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'No projects assigned',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Head to Repairs to self-assign or pick up a ticket.',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: assignedProjects.map((proj) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C1C1E),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      proj.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      proj.locationName,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
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
                                    color: Colors.blueAccent.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${proj.priorityScore?.toString() ?? '-'}/100',
                                    style: const TextStyle(
                                      color: Colors.blueAccent,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'FILES',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    StreamBuilder<DatabaseEvent>(
                      stream: _filesRef.onValue,
                      builder: (context, fileSnap) {
                        int fileCount = 0;
                        final rawFiles = fileSnap.data?.snapshot.value;
                        if (rawFiles is Map) fileCount = rawFiles.length;
                        return Text(
                          '$fileCount saved',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFileChip('All'),
                      _buildFileChip('Work Order'),
                      _buildFileChip('Audit Report'),
                      _buildFileChip('PDF Report'),
                      _buildFileChip('CSV Export'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                StreamBuilder<DatabaseEvent>(
                  stream: _filesRef.onValue,
                  builder: (context, fileSnap) {
                    final files = <Map<String, dynamic>>[];
                    final rawFiles = fileSnap.data?.snapshot.value;
                    if (rawFiles is Map) {
                      rawFiles.forEach((key, value) {
                        if (value is Map) {
                          final type = (value['type'] ?? '').toString();
                          if (_selectedFileFilter == 'All' ||
                              type.toLowerCase().contains(
                                _selectedFileFilter.toLowerCase(),
                              )) {
                            files.add({
                              'title': value['title'] ?? key,
                              'type': type,
                              'size': value['size']?.toString() ?? '',
                              'time': _formatTimestamp(value['timestamp']),
                            });
                          }
                        }
                      });
                    }
                    if (files.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No saved reports or files found.',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      );
                    }
                    return Column(
                      children: files
                          .map((file) => _buildFileCard(file))
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'DEVICE STATUS & NETWORK',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _iotSectionExpanded = !_iotSectionExpanded;
                        });
                      },
                      child: Row(
                        children: [
                          Icon(
                            _iotSectionExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: Colors.grey,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_iotSectionExpanded) ...[
                  const SizedBox(height: 10),
                  const DeviceStatusSection(),
                ],

                const SizedBox(height: 32),

                // Added Sign Out Button
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                      foregroundColor: Colors.redAccent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: Colors.redAccent.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    onPressed: _handleSignOut,
                    icon: const Icon(Icons.logout, size: 20),
                    label: const Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMetricBox(String count, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF161618),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileChip(String label) {
    final isSelected = _selectedFileFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: const Color(0xFF3B82F6),
        backgroundColor: const Color(0xFF1C1C1E),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.grey,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white10),
        ),
        onSelected: (val) {
          setState(() {
            _selectedFileFilter = label;
          });
        },
      ),
    );
  }

  Widget _buildFileCard(Map<String, dynamic> file) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.insert_drive_file,
              color: Colors.blueAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file['title'].toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        file['type'].toString().isEmpty
                            ? '-'
                            : file['type'].toString(),
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (file['size'].toString().isNotEmpty ||
                        file['time'].toString().isNotEmpty)
                      Text(
                        [file['size'], file['time']]
                            .where((value) => value.toString().isNotEmpty)
                            .join(' • '),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
