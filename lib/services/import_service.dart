import 'dart:convert';
import 'dart:io';
import '../models/patient.dart';

enum ImportMode { replace, merge }

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

class ImportService {
  static Future<ImportResult> parseObsFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return ImportResult.error('File not found');
      }

      final content = await file.readAsString();
      return parseObsData(content);
    } catch (e) {
      return ImportResult.error('Failed to read file: $e');
    }
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
          // Skip invalid patient data but continue with others
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

  static List<String> validateImport(List<Patient> existingPatients, List<Patient> newPatients) {
    final List<String> conflicts = [];

    for (final newPatient in newPatients) {
      // Check for room number conflicts
      final existingPatient = existingPatients
          .where((p) => p.roomNumber.toLowerCase() == newPatient.roomNumber.toLowerCase())
          .firstOrNull;

      if (existingPatient != null) {
        conflicts.add('Room ${newPatient.roomNumber}: ${existingPatient.initials} → ${newPatient.initials}');
      }
    }

    return conflicts;
  }

  static List<Patient> mergePatients(
    List<Patient> existingPatients,
    List<Patient> newPatients,
    ImportMode mode,
  ) {
    switch (mode) {
      case ImportMode.replace:
        return List.from(newPatients);

      case ImportMode.merge:
        final Map<String, Patient> patientMap = {};

        // Add existing patients
        for (final patient in existingPatients) {
          patientMap[patient.roomNumber.toLowerCase()] = patient;
        }

        // Add/replace with new patients
        for (final patient in newPatients) {
          patientMap[patient.roomNumber.toLowerCase()] = patient;
        }

        return patientMap.values.toList();
    }
  }

  static String generateImportSummary(ImportResult result, List<String> conflicts) {
    final buffer = StringBuffer();

    buffer.writeln('Import Summary');
    buffer.writeln('─────────────');
    buffer.writeln('From: ${result.senderName}');
    buffer.writeln('Exported: ${_formatDateTime(result.exportDate)}');
    buffer.writeln('Patients: ${result.patients.length}');

    if (result.notes.isNotEmpty) {
      buffer.writeln('Notes: ${result.notes}');
    }

    if (conflicts.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('⚠️ Room Conflicts:');
      for (final conflict in conflicts) {
        buffer.writeln('  • $conflict');
      }
    }

    return buffer.toString();
  }

  static String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '${dateTime.month}/${dateTime.day}/${dateTime.year} $hour:${dateTime.minute.toString().padLeft(2, '0')} $period';
  }
}