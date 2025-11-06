import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/patient.dart';
import '../models/patient_type.dart';
import '../services/storage_service.dart';

class PatientProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();

  List<Patient> _patients = [];
  PatientType? _selectedTypeFilter;
  bool _isLoading = false;
  String? _error;

  List<Patient> get patients => _patients;
  PatientType? get selectedTypeFilter => _selectedTypeFilter;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Patient> get filteredPatients {
    if (_selectedTypeFilter == null) {
      return _patients;
    }
    return _patients.where((patient) => patient.type == _selectedTypeFilter).toList();
  }

  int get totalPatientCount => _patients.length;

  Map<PatientType, int> get patientCountsByType {
    final Map<PatientType, int> counts = {};
    for (final type in PatientType.values) {
      counts[type] = _patients.where((p) => p.type == type).length;
    }
    return counts;
  }

  PatientProvider() {
    _init();
  }

  Future<void> _init() async {
    await loadPatients();
    _storageService.watchPatients().listen(_onPatientsChanged);
  }

  void _onPatientsChanged(BoxEvent event) {
    loadPatients();
  }

  Future<void> loadPatients() async {
    _setLoading(true);
    try {
      _patients = await _storageService.getAllPatients();
      _error = null;
    } catch (e) {
      _error = 'Failed to load patients: $e';
      _patients = [];
    } finally {
      _setLoading(false);
    }
  }

  Future<String> addPatient({
    required String initials,
    required String roomNumber,
    required PatientType type,
    int? age,
    int? gravida,
    int? para,
    int? gestationalAgeWeeks,
    int? gestationalAgeDays,
    DateTime? gestationalAgeSetDate,
    List<String>? laborStatuses,
    String? notes,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      _error = null;

      final patient = Patient(
        id: '',
        initials: initials.trim(),
        roomNumber: roomNumber.trim(),
        type: type,
        age: age,
        gravida: gravida,
        para: para,
        gestationalAgeWeeks: gestationalAgeWeeks,
        gestationalAgeDays: gestationalAgeDays,
        gestationalAgeSetDate: gestationalAgeSetDate,
        laborStatuses: laborStatuses,
        notes: notes,
        parameters: parameters ?? {},
      );

      final id = await _storageService.savePatient(patient);
      await loadPatients();
      return id;
    } catch (e) {
      _error = 'Failed to add patient: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updatePatient(Patient patient) async {
    try {
      _error = null;
      await _storageService.updatePatient(patient);
      await loadPatients();
    } catch (e) {
      _error = 'Failed to update patient: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deletePatient(String id) async {
    try {
      _error = null;
      await _storageService.deletePatient(id);
      await loadPatients();
    } catch (e) {
      _error = 'Failed to delete patient: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteAllPatients() async {
    try {
      _error = null;
      await _storageService.deleteAllPatients();
      await loadPatients();
    } catch (e) {
      _error = 'Failed to delete all patients: $e';
      notifyListeners();
      rethrow;
    }
  }

  Patient? getPatientById(String id) {
    try {
      return _patients.firstWhere((patient) => patient.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<bool> isRoomNumberTaken(String roomNumber, [String? excludePatientId]) async {
    return await _storageService.isRoomNumberTaken(roomNumber, excludePatientId);
  }

  void setTypeFilter(PatientType? type) {
    if (_selectedTypeFilter != type) {
      _selectedTypeFilter = type;
      notifyListeners();
    }
  }

  void clearTypeFilter() {
    setTypeFilter(null);
  }

  Future<void> updatePatientParameter(String patientId, String key, dynamic value) async {
    final patient = getPatientById(patientId);
    if (patient != null) {
      patient.updateParameter(key, value);
      await updatePatient(patient);
    }
  }

  Future<void> removePatientParameter(String patientId, String key) async {
    final patient = getPatientById(patientId);
    if (patient != null) {
      patient.removeParameter(key);
      await updatePatient(patient);
    }
  }

  List<Patient> sortPatients({
    bool sortByType = false,
    bool sortByRoom = false,
    bool ascending = true,
  }) {
    final List<Patient> sortedPatients = List.from(filteredPatients);

    if (sortByType) {
      sortedPatients.sort((a, b) {
        final comparison = a.type.index.compareTo(b.type.index);
        return ascending ? comparison : -comparison;
      });
    } else if (sortByRoom) {
      sortedPatients.sort((a, b) {
        final comparison = a.roomNumber.compareTo(b.roomNumber);
        return ascending ? comparison : -comparison;
      });
    } else {
      // Default sort by creation date
      sortedPatients.sort((a, b) {
        final comparison = a.createdAt.compareTo(b.createdAt);
        return ascending ? comparison : -comparison;
      });
    }

    return sortedPatients;
  }

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _storageService.dispose();
    super.dispose();
  }
}