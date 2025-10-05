import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/patient.dart';
import '../providers/patient_provider.dart';
import '../services/share_service.dart';
import '../widgets/patient_card.dart';

enum ImportMode { replace, merge }

class ImportPreviewScreen extends StatefulWidget {
  final ImportResult importResult;

  const ImportPreviewScreen({super.key, required this.importResult});

  @override
  State<ImportPreviewScreen> createState() => _ImportPreviewScreenState();
}

class _ImportPreviewScreenState extends State<ImportPreviewScreen> {
  ImportMode _selectedMode = ImportMode.merge;
  List<String> _conflicts = [];
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _checkConflicts();
  }

  void _checkConflicts() {
    final patientProvider = Provider.of<PatientProvider>(
      context,
      listen: false,
    );
    _conflicts = _validateImport(
      patientProvider.patients,
      widget.importResult.patients,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Patient Data'),
        actions: [
          TextButton(
            onPressed: _isImporting ? null : _performImport,
            child: _isImporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Import',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildImportSummary(),
            const SizedBox(height: 16),
            if (_conflicts.isNotEmpty) ...[
              _buildConflictsSection(),
              const SizedBox(height: 16),
            ],
            _buildImportModeSelector(),
            const SizedBox(height: 16),
            _buildPatientsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildImportSummary() {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.download_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Import Summary',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSummaryRow('From', widget.importResult.senderName),
            const SizedBox(height: 4),
            _buildSummaryRow(
              'Exported',
              _formatDateTime(widget.importResult.exportDate),
            ),
            const SizedBox(height: 4),
            _buildSummaryRow(
              'Patients',
              '${widget.importResult.patients.length}',
            ),
            if (widget.importResult.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Notes:',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.importResult.notes,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Text(
          '$label:',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }

  Widget _buildConflictsSection() {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_outlined,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'Room Conflicts',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'The following rooms have conflicts with existing patients:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 8),
            ...(_conflicts.map(
              (conflict) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '• $conflict',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildImportModeSelector() {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import Mode',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            RadioListTile<ImportMode>(
              title: const Text('Merge with existing patients'),
              subtitle: Text(
                _conflicts.isNotEmpty
                    ? 'Conflicting rooms will be replaced with new data'
                    : 'Add new patients to existing list',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              value: ImportMode.merge,
              groupValue: _selectedMode,
              onChanged: (value) {
                setState(() {
                  _selectedMode = value!;
                });
              },
            ),
            RadioListTile<ImportMode>(
              title: const Text('Replace all patients'),
              subtitle: Text(
                'Remove all current patients and replace with imported data',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              value: ImportMode.replace,
              groupValue: _selectedMode,
              onChanged: (value) {
                setState(() {
                  _selectedMode = value!;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientsList() {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Patients to Import (${widget.importResult.patients.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (widget.importResult.patients.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'No patients to import',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ...widget.importResult.patients.map((patient) {
                final hasConflict = _conflicts.any(
                  (conflict) =>
                      conflict.contains('Room ${patient.roomNumber}:'),
                );

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: hasConflict
                      ? BoxDecoration(
                          border: Border.all(
                            color: theme.colorScheme.error,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        )
                      : null,
                  child: PatientCard(patient: patient, showDeleteButton: false),
                );
              }),
          ],
        ),
      ),
    );
  }

  List<String> _validateImport(
    List<Patient> existingPatients,
    List<Patient> newPatients,
  ) {
    final List<String> conflicts = [];

    for (final newPatient in newPatients) {
      final existingPatient = existingPatients
          .where(
            (p) =>
                p.roomNumber.toLowerCase() ==
                newPatient.roomNumber.toLowerCase(),
          )
          .firstOrNull;

      if (existingPatient != null) {
        conflicts.add(
          'Room ${newPatient.roomNumber}: ${existingPatient.initials} → ${newPatient.initials}',
        );
      }
    }

    return conflicts;
  }

  List<Patient> _mergePatients(
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

  Future<void> _performImport() async {
    setState(() {
      _isImporting = true;
    });

    try {
      final patientProvider = Provider.of<PatientProvider>(
        context,
        listen: false,
      );

      // Get merged patient list
      final mergedPatients = _mergePatients(
        patientProvider.patients,
        widget.importResult.patients,
        _selectedMode,
      );

      // Clear existing and add merged patients based on mode
      if (_selectedMode == ImportMode.replace) {
        await patientProvider.deleteAllPatients();
      }

      // Add new patients
      for (final patient in widget.importResult.patients) {
        if (_selectedMode == ImportMode.merge) {
          // Remove any existing patient with same room
          final existingPatient = patientProvider.patients
              .where(
                (p) =>
                    p.roomNumber.toLowerCase() ==
                    patient.roomNumber.toLowerCase(),
              )
              .firstOrNull;
          if (existingPatient != null) {
            await patientProvider.deletePatient(existingPatient.id);
          }
        }

        await patientProvider.addPatient(
          initials: patient.initials,
          roomNumber: patient.roomNumber,
          type: patient.type,
          age: patient.age,
          gravida: patient.gravida,
          para: patient.para,
          gestationalAge: patient.gestationalAge,
          parameters: patient.parameters,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully imported ${widget.importResult.patients.length} patients',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour > 12
        ? dateTime.hour - 12
        : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '${dateTime.month}/${dateTime.day}/${dateTime.year} $hour:${dateTime.minute.toString().padLeft(2, '0')} $period';
  }
}
