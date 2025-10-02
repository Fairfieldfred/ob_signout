import 'dart:convert';
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import '../models/patient.dart';
import '../models/patient_type.dart';

class ImportResult {
  final bool success;
  final String? error;
  final List<Patient> patients;
  final String senderName;
  final String notes;
  final DateTime exportDate;
  final int patientCount;

  const ImportResult({
    required this.success,
    this.error,
    required this.patients,
    required this.senderName,
    required this.notes,
    required this.exportDate,
    required this.patientCount,
  });

  ImportResult.error(String errorMessage)
      : success = false,
        error = errorMessage,
        patients = const [],
        senderName = '',
        notes = '',
        exportDate = DateTime(1970),
        patientCount = 0;
}

class ShareService {
  static Future<void> shareSignout({
    required List<Patient> patients,
    String? additionalNotes,
  }) async {
    final signoutText = _formatSignoutText(patients, additionalNotes);

    await Share.share(
      signoutText,
      subject: 'OB/GYN Signout - ${_getCurrentDateString()}',
    );
  }

  static Future<void> shareAsFile({
    required List<Patient> patients,
    String? additionalNotes,
  }) async {
    final signoutText = _formatSignoutText(patients, additionalNotes);
    final fileName = 'ob_signout_${_getFileNameDateString()}.txt';

    await Share.shareXFiles(
      [
        XFile.fromData(
          Uint8List.fromList(signoutText.codeUnits),
          name: fileName,
          mimeType: 'text/plain',
        ),
      ],
      subject: 'OB/GYN Signout - ${_getCurrentDateString()}',
    );
  }

  static Future<void> sharePatientData({
    required List<Patient> patients,
    String? senderName,
    String? notes,
  }) async {
    final obsData = _createObsFileData(patients, senderName, notes);
    final fileName = 'signout_${_getFileNameDateString()}.obs';

    await Share.shareXFiles(
      [
        XFile.fromData(
          Uint8List.fromList(utf8.encode(obsData)),
          name: fileName,
          mimeType: 'application/octet-stream',
        ),
      ],
      subject: 'OB Signout Data - ${_getCurrentDateString()}',
      text: 'OB/GYN patient signout data. Open in OB Sign-Out app to import.',
    );
  }

  static String _createObsFileData(List<Patient> patients, String? senderName, String? notes) {
    final obsData = {
      'version': '1.0',
      'appName': 'OB Sign-Out',
      'exportDate': DateTime.now().toIso8601String(),
      'senderName': senderName ?? 'Unknown',
      'notes': notes ?? '',
      'patientCount': patients.length,
      'patients': patients.map((p) => p.toJson()).toList(),
    };

    return jsonEncode(obsData);
  }

  static ImportResult parseObsData(String jsonData) {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonData);

      // Validate file format
      if (data['appName'] != 'OB Sign-Out') {
        return ImportResult.error('Invalid file format - not an OB Sign-Out file');
      }

      if (data['version'] != '1.0') {
        return ImportResult.error('Unsupported file version: ${data['version']}');
      }

      // Parse patients
      final List<dynamic> patientsJson = data['patients'] ?? [];
      final List<Patient> patients = [];

      for (final patientJson in patientsJson) {
        try {
          final patient = Patient.fromJson(patientJson as Map<String, dynamic>);
          patients.add(patient);
        } catch (e) {
          continue;
        }
      }

      if (patients.isEmpty && patientsJson.isNotEmpty) {
        return ImportResult.error('No valid patient data found in file');
      }

      return ImportResult(
        success: true,
        patients: patients,
        senderName: data['senderName'] ?? 'Unknown',
        notes: data['notes'] ?? '',
        exportDate: DateTime.parse(data['exportDate'] ?? DateTime.now().toIso8601String()),
        patientCount: data['patientCount'] ?? patients.length,
      );
    } catch (e) {
      return ImportResult.error('Invalid file format: $e');
    }
  }

  static String _formatSignoutText(List<Patient> patients, String? additionalNotes) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('🏥 OB/GYN SIGNOUT');
    buffer.writeln('Date: ${_getCurrentDateString()}');
    buffer.writeln('Time: ${_getCurrentTimeString()}');
    buffer.writeln('');

    if (patients.isEmpty) {
      buffer.writeln('No patients to sign out.');
      buffer.writeln('');
    } else {
      // Group patients by type
      final groupedPatients = <PatientType, List<Patient>>{};
      for (final patient in patients) {
        groupedPatients.putIfAbsent(patient.type, () => []).add(patient);
      }

      // Sort patients within each group by room number
      for (final type in PatientType.values) {
        final patientsOfType = groupedPatients[type];
        if (patientsOfType != null && patientsOfType.isNotEmpty) {
          patientsOfType.sort((a, b) => a.roomNumber.compareTo(b.roomNumber));
        }
      }

      // Write each section
      for (final type in PatientType.values) {
        final patientsOfType = groupedPatients[type];
        if (patientsOfType != null && patientsOfType.isNotEmpty) {
          buffer.writeln('═══ ${type.displayName.toUpperCase()} (${patientsOfType.length}) ═══');
          buffer.writeln('');

          for (int i = 0; i < patientsOfType.length; i++) {
            final patient = patientsOfType[i];

            // Main patient line with demographics
            final demographics = <String>[];
            if (patient.ageString.isNotEmpty) demographics.add(patient.ageString);
            if (patient.gravidaParaString.isNotEmpty) demographics.add(patient.gravidaParaString);
            if (patient.gestationalAgeString.isNotEmpty) demographics.add('GA: ${patient.gestationalAgeString}');

            final demographicsStr = demographics.isNotEmpty ? ' (${demographics.join(', ')})' : '';
            buffer.writeln('${i + 1}. ${patient.initials}$demographicsStr - Room ${patient.roomNumber}');

            // Add parameters if any
            if (patient.parameters.isNotEmpty) {
              final sortedParams = patient.parameters.entries.toList()
                ..sort((a, b) => a.key.compareTo(b.key));

              for (final param in sortedParams) {
                final value = _formatParameterValue(param.value);
                buffer.writeln('   • ${param.key}: $value');
              }
            }
            buffer.writeln('');
          }
        }
      }
    }

    // Summary
    if (patients.isNotEmpty) {
      buffer.writeln('─── SUMMARY ───');
      final summary = _generateSummary(patients);
      for (final entry in summary.entries) {
        buffer.writeln('${entry.key}: ${entry.value}');
      }
      buffer.writeln('');
    }

    // Additional notes
    if (additionalNotes != null && additionalNotes.trim().isNotEmpty) {
      buffer.writeln('─── ADDITIONAL NOTES ───');
      buffer.writeln(additionalNotes.trim());
      buffer.writeln('');
    }

    // Footer
    buffer.writeln('─────────────────────────');
    buffer.writeln('Generated by OB Signout App');
    buffer.writeln('Privacy Note: No PHI beyond initials and room numbers');

    return buffer.toString();
  }

  static String _formatParameterValue(dynamic value) {
    if (value == null) return 'N/A';
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is DateTime) return '${value.month}/${value.day}/${value.year} ${value.hour}:${value.minute.toString().padLeft(2, '0')}';
    return value.toString();
  }

  static Map<String, dynamic> _generateSummary(List<Patient> patients) {
    final summary = <String, dynamic>{};

    // Total count
    summary['Total Patients'] = patients.length;

    // Count by type
    for (final type in PatientType.values) {
      final count = patients.where((p) => p.type == type).length;
      if (count > 0) {
        summary['${type.displayName} Patients'] = count;
      }
    }

    return summary;
  }

  static String _getCurrentDateString() {
    final now = DateTime.now();
    return '${now.month}/${now.day}/${now.year}';
  }

  static String _getCurrentTimeString() {
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${now.minute.toString().padLeft(2, '0')} $period';
  }

  static String _getFileNameDateString() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  }

  static String formatPatientForPreview(Patient patient) {
    final buffer = StringBuffer();

    // Main patient line with demographics
    final demographics = <String>[];
    if (patient.ageString.isNotEmpty) demographics.add(patient.ageString);
    if (patient.gravidaParaString.isNotEmpty) demographics.add(patient.gravidaParaString);
    if (patient.gestationalAgeString.isNotEmpty) demographics.add('GA: ${patient.gestationalAgeString}');

    final demographicsStr = demographics.isNotEmpty ? ' (${demographics.join(', ')})' : '';
    buffer.writeln('${patient.initials}$demographicsStr - Room ${patient.roomNumber} (${patient.type.displayName})');

    if (patient.parameters.isNotEmpty) {
      final sortedParams = patient.parameters.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      for (final param in sortedParams.take(3)) {  // Show only first 3 parameters
        final value = _formatParameterValue(param.value);
        buffer.writeln('• ${param.key}: $value');
      }

      if (patient.parameters.length > 3) {
        buffer.writeln('• ... and ${patient.parameters.length - 3} more');
      }
    }

    return buffer.toString().trim();
  }
}