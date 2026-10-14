import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

import 'device_component.dart';

/// Displays device, network, battery, and storage status in the profile.
class DeviceStatusSection extends StatefulWidget {
  const DeviceStatusSection({super.key});

  @override
  State<DeviceStatusSection> createState() => _DeviceStatusSectionState();
}

class _DeviceStatusSectionState extends State<DeviceStatusSection> {
  final DatabaseReference _deviceRef = DatabaseService.mapApiDb(
    'device_status',
  );

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'connected':
      case 'active':
      case 'healthy':
      case 'gps_lock':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      case 'offline':
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    if (status.toLowerCase() == 'gps_lock') return 'GPS Lock';
    if (status.isEmpty) return 'Unknown';
    return status[0].toUpperCase() + status.substring(1);
  }

  String _formatUptime(dynamic seconds) {
    if (seconds == null) return '-';
    final total = seconds is int
        ? seconds
        : int.tryParse(seconds.toString()) ?? 0;
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: _deviceRef.onValue,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Unable to load device status: ${snapshot.error}',
              style: const TextStyle(color: Colors.redAccent),
              textAlign: TextAlign.center,
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final raw = snapshot.data?.snapshot.value;
        if (raw is! Map) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No device data', style: TextStyle(color: Colors.grey)),
          );
        }

        DeviceComponent? component(String key) {
          final value = raw[key];
          if (value is! Map) return null;
          return DeviceComponent.fromMap(value);
        }

        final esp32 = component('esp32');
        final gps = component('gps');
        final vibrationSensor = component('vibration_sensor');
        final mqtt = component('mqtt');
        final sim = component('sim');
        final storagePercent = raw['storage_percent_used'];
        final batteryPercent = raw['battery_percent'];
        final batteryCharging = raw['battery_charging'] == true;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionLabel('IOT DEVICE'),
            const SizedBox(height: 8),
            if (esp32 != null)
              _DeviceTile(
                icon: Icons.developer_board,
                component: esp32,
                statusColor: _statusColor(esp32.status),
                statusLabel: _statusLabel(esp32.status),
                subtitle:
                    'Uptime: ${_formatUptime(esp32.details['uptime_sec'])} • Last ping: ${esp32.details['last_ping_sec_ago'] ?? '-'}s ago',
              ),
            if (gps != null)
              _DeviceTile(
                icon: Icons.gps_fixed,
                component: gps,
                statusColor: _statusColor(gps.status),
                statusLabel: _statusLabel(gps.status),
                subtitle:
                    '${gps.details['satellites'] ?? '-'} satellites • Accuracy ±${gps.details['accuracy_m'] ?? '-'}m',
              ),
            if (vibrationSensor != null)
              _DeviceTile(
                icon: Icons.vibration,
                component: vibrationSensor,
                statusColor: _statusColor(vibrationSensor.status),
                statusLabel: _statusLabel(vibrationSensor.status),
                subtitle:
                    'Sampling at ${vibrationSensor.details['sampling_hz'] ?? '-'}Hz',
              ),
            const SizedBox(height: 20),
            const _SectionLabel('NETWORK CONNECTION'),
            const SizedBox(height: 8),
            if (mqtt != null)
              _DeviceTile(
                icon: Icons.cloud_outlined,
                component: mqtt,
                statusColor: _statusColor(mqtt.status),
                statusLabel: _statusLabel(mqtt.status),
                subtitle:
                    '${mqtt.details['host'] ?? ''}\n${mqtt.details['note'] ?? ''}',
              ),
            if (sim != null)
              _DeviceTile(
                icon: Icons.sim_card_outlined,
                component: sim,
                statusColor: _statusColor(sim.status),
                statusLabel: _statusLabel(sim.status),
                subtitle:
                    '${sim.details['carrier'] ?? ''} • Signal: ${sim.details['signal_dbm'] ?? '-'} dBm • ${sim.details['data_used_mb'] ?? '-'} MB used',
              ),
            const SizedBox(height: 20),
            const _SectionLabel('DEVICE STATUS'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _StatusCard(
                    icon: Icons.sd_card_outlined,
                    iconColor: Colors.pinkAccent,
                    label: 'Storage',
                    value: storagePercent != null
                        ? '$storagePercent% used'
                        : '-',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatusCard(
                    icon: Icons.battery_charging_full,
                    iconColor: Colors.greenAccent,
                    label: 'Battery',
                    value: batteryPercent != null
                        ? '$batteryPercent%${batteryCharging ? ' • Charging' : ''}'
                        : '-',
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.grey,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final IconData icon;
  final DeviceComponent component;
  final Color statusColor;
  final String statusLabel;
  final String subtitle;

  const _DeviceTile({
    required this.icon,
    required this.component,
    required this.statusColor,
    required this.statusLabel,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.lightBlueAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  component.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  component.role,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(color: statusColor, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatusCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
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
