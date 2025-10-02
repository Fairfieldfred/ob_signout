// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:ob_signout/models/patient.dart';
import 'package:ob_signout/models/patient_type.dart';

void main() {
  group('Patient Model Tests', () {
    test('Patient creation and serialization', () {
      final patient = Patient(
        id: 'test-id',
        initials: 'JD',
        roomNumber: 'L&D 5',
        type: PatientType.labor,
      );

      expect(patient.initials, 'JD');
      expect(patient.roomNumber, 'L&D 5');
      expect(patient.type, PatientType.labor);
      expect(patient.parameters, isEmpty);

      // Test JSON serialization
      final json = patient.toJson();
      expect(json['initials'], 'JD');
      expect(json['type'], 'labor');

      // Test JSON deserialization
      final recreatedPatient = Patient.fromJson(json);
      expect(recreatedPatient.initials, patient.initials);
      expect(recreatedPatient.type, patient.type);
    });

    test('Patient parameter management', () {
      final patient = Patient(
        id: 'test-id',
        initials: 'AB',
        roomNumber: 'PP 3',
        type: PatientType.postpartum,
      );

      // Add parameter
      patient.updateParameter('Blood Pressure', '120/80');
      expect(patient.parameters['Blood Pressure'], '120/80');

      // Update parameter
      patient.updateParameter('Blood Pressure', '130/85');
      expect(patient.parameters['Blood Pressure'], '130/85');

      // Remove parameter
      patient.removeParameter('Blood Pressure');
      expect(patient.parameters.containsKey('Blood Pressure'), false);
    });
  });

  group('PatientType Tests', () {
    test('PatientType display names', () {
      expect(PatientType.labor.displayName, 'Labor');
      expect(PatientType.postpartum.displayName, 'Postpartum');
      expect(PatientType.gynPostOp.displayName, 'GYN Post-op');
      expect(PatientType.consult.displayName, 'Consult');
    });

    test('PatientType short names', () {
      expect(PatientType.labor.shortName, 'L');
      expect(PatientType.postpartum.shortName, 'PP');
      expect(PatientType.gynPostOp.shortName, 'GYN');
      expect(PatientType.consult.shortName, 'CON');
    });
  });
}
