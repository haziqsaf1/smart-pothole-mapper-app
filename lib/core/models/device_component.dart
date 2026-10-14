/// A generic wrapper for one entry under `device_status/{componentKey}`,
/// e.g. the ESP32 controller, the GPS module, the MQTT broker, etc.
/// Every field besides name/role/status is kept in [details] so each
/// component can carry its own extra attributes without a rigid schema.
class DeviceComponent {
  final String name;
  final String role;
  final String status;
  final Map<String, dynamic> details;

  DeviceComponent({
    required this.name,
    required this.role,
    required this.status,
    required this.details,
  });

  factory DeviceComponent.fromMap(Map<dynamic, dynamic> map) {
    final details = <String, dynamic>{};
    map.forEach((key, value) {
      final k = key.toString();
      if (k != 'name' && k != 'role' && k != 'status') {
        details[k] = value;
      }
    });
    return DeviceComponent(
      name: (map['name'] ?? '').toString(),
      role: (map['role'] ?? '').toString(),
      status: (map['status'] ?? '').toString(),
      details: details,
    );
  }
}
