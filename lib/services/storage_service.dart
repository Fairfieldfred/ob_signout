import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/patient.dart';
import '../models/patient_type.dart';

class StorageService {
  static const String _patientsBoxName = 'patients';
  static const Uuid _uuid = Uuid();

  Box<Patient> get _patientsBox => Hive.box<Patient>(_patientsBoxName);

  Future<List<Patient>> getAllPatients() async {
    return _patientsBox.values.toList();
  }

  Future<List<Patient>> getPatientsByType(PatientType type) async {
    return _patientsBox.values
        .where((patient) => patient.type == type)
        .toList();
  }

  Future<Patient?> getPatient(String id) async {
    return _patientsBox.values
        .where((patient) => patient.id == id)
        .firstOrNull;
  }

  Future<String> savePatient(Patient patient) async {
    if (patient.id.isEmpty) {
      patient.id = _uuid.v4();
    }

    await _patientsBox.put(patient.id, patient);
    return patient.id;
  }

  Future<void> updatePatient(Patient patient) async {
    patient.updatedAt = DateTime.now();
    await _patientsBox.put(patient.id, patient);
  }

  Future<void> deletePatient(String id) async {
    await _patientsBox.delete(id);
  }

  Future<void> deleteAllPatients() async {
    await _patientsBox.clear();
  }

  Future<bool> isRoomNumberTaken(String roomNumber, [String? excludePatientId]) async {
    return _patientsBox.values.any((patient) =>
        patient.roomNumber.toLowerCase() == roomNumber.toLowerCase() &&
        patient.id != excludePatientId);
  }

  Future<int> getPatientCount() async {
    return _patientsBox.length;
  }

  Future<Map<PatientType, int>> getPatientCountsByType() async {
    final patients = await getAllPatients();
    final Map<PatientType, int> counts = {};

    for (final type in PatientType.values) {
      counts[type] = patients.where((p) => p.type == type).length;
    }

    return counts;
  }

  Stream<BoxEvent> watchPatients() {
    return _patientsBox.watch();
  }

  Future<List<Patient>> sortPatients({
    List<Patient>? patients,
    bool sortByType = false,
    bool sortByRoom = false,
    bool ascending = true,
  }) async {
    patients ??= await getAllPatients();

    if (sortByType) {
      patients.sort((a, b) {
        final comparison = a.type.index.compareTo(b.type.index);
        return ascending ? comparison : -comparison;
      });
    } else if (sortByRoom) {
      patients.sort((a, b) {
        final comparison = a.roomNumber.compareTo(b.roomNumber);
        return ascending ? comparison : -comparison;
      });
    } else {
      // Default sort by creation date
      patients.sort((a, b) {
        final comparison = a.createdAt.compareTo(b.createdAt);
        return ascending ? comparison : -comparison;
      });
    }

    return patients;
  }

  void dispose() {
    // Close box if needed (usually not necessary as Hive handles this)
  }
}