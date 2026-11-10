// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:main_app_spm/core/models/hazard.dart';

void main() {
  test('missing hazard fields are not replaced with sample values', () {
    final hazard = Hazard.fromMap('record-1', {});

    expect(hazard.id, 'record-1');
    expect(hazard.latitude, isNull);
    expect(hazard.longitude, isNull);
    expect(hazard.vibrationG, isNull);
    expect(hazard.widthCm, isNull);
    expect(hazard.depthCm, isNull);
    expect(hazard.priorityScore, isNull);
    expect(hazard.title, isEmpty);
    expect(hazard.locationName, isEmpty);
    expect(hazard.status, isEmpty);
  });

  test('hazard fields are populated from the database record', () {
    final hazard = Hazard.fromMap('record-2', {
      'latitude': 3.14,
      'longitude': 101.7,
      'severity': 'critical',
      'timestamp': 1720000000000,
      'vibration_g': 1.25,
      'width_cm': 40,
      'depth_cm': 8,
      'location_name': 'North entrance',
      'title': 'Road damage',
      'description': 'Surface damage near the entrance.',
      'priority_score': 85,
      'status': 'in_progress',
      'assigned_to': 'maintenance-user',
    });

    expect(hazard.latitude, 3.14);
    expect(hazard.longitude, 101.7);
    expect(hazard.severity, 'critical');
    expect(hazard.vibrationG, 1.25);
    expect(hazard.locationName, 'North entrance');
    expect(hazard.description, 'Surface damage near the entrance.');
    expect(hazard.priorityScore, 85);
    expect(hazard.status, 'in_progress');
    expect(hazard.assignedTo, 'maintenance-user');
  });
}
