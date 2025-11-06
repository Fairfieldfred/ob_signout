import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/patient.dart';
import '../models/patient_type.dart';
import '../providers/patient_provider.dart';
import '../services/share_service.dart';
import '../widgets/clinical_conditions_dialog.dart';
import 'add_edit_patient_screen.dart';

class PatientDetailScreen extends StatefulWidget {
  final String patientId;

  const PatientDetailScreen({super.key, required this.patientId});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  final _parameterKeyController = TextEditingController();
  final _parameterValueController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _parameterKeyController.dispose();
    _parameterValueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PatientProvider>(
      builder: (context, patientProvider, child) {
        final patient = patientProvider.getPatientById(widget.patientId);

        if (patient == null) {
          return _buildPatientNotFound(context);
        }

        return Scaffold(
          appBar: _buildAppBar(context, patient),
          body: _buildBody(context, patient, patientProvider),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, Patient patient) {
    return AppBar(
      title: Column(
        children: [
          Text(patient.initials),
          Text(
            'Room ${patient.roomNumber}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: () => _sharePatient(context, patient),
          tooltip: 'Share patient info',
        ),
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => _editPatient(context, patient),
          tooltip: 'Edit patient',
        ),
        PopupMenuButton<String>(
          onSelected: (value) => _handleMenuSelection(context, patient, value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete patient', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPatientNotFound(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Patient Not Found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Patient not found',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The patient may have been deleted or moved.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    Patient patient,
    PatientProvider provider,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPatientInfo(context, patient),
          const SizedBox(height: 24),
          _buildParametersSection(context, patient, provider),
          const SizedBox(height: 24),
          _buildNotesSection(context, patient, provider),
        ],
      ),
    );
  }

  Widget _buildPatientInfo(BuildContext context, Patient patient) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InkWell(
                  onTap: () => _showChangePatientTypeDialog(context, patient),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getTypeColor(patient.type, theme.colorScheme),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      patient.type.displayName,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: _getTypeTextColor(
                          patient.type,
                          theme.colorScheme,
                        ),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                // Status options on the right
                if (patient.type == PatientType.labor)
                  // Labor status selector for Labor patients
                  _buildLaborStatusSelector(context, patient, theme)
                else
                  // Rounded and D/C checkboxes for non-Labor patients
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Rounded checkbox
                      InkWell(
                        onTap: () => _toggleRoundedStatus(context, patient),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Rounded',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Checkbox(
                              value: patient.isRounded,
                              onChanged: (_) =>
                                  _toggleRoundedStatus(context, patient),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),
                      // D/C checkbox
                      InkWell(
                        onTap: () => _toggleDischargedStatus(context, patient),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'D/C\'d',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Checkbox(
                              value: patient.isDischarged,
                              onChanged: (_) =>
                                  _toggleDischargedStatus(context, patient),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              context,
              'Initials',
              patient.initials,
              Icons.person_outline,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              context,
              'Room',
              patient.roomNumber,
              Icons.location_on_outlined,
            ),
            if (patient.age != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                context,
                'Age',
                patient.ageString,
                Icons.cake_outlined,
              ),
            ],
            if (patient.gravidaParaString.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                context,
                'Gravida/Para',
                patient.gravidaParaString,
                Icons.pregnant_woman_outlined,
              ),
            ],
            if (patient.gestationalAgeString.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                context,
                'Gestational Age',
                patient.gestationalAgeString,
                Icons.schedule_outlined,
              ),
            ],
            const SizedBox(height: 8),
            _buildInfoRow(
              context,
              'Last Updated',
              _formatDateTime(patient.updatedAt),
              Icons.access_time,
            ),
            // Clinical Parameters
            if (patient.parameters.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.medical_information_outlined,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Clinical Conditions',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: patient.parameters.entries.map((param) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatClinicalParameter(param.key, param.value),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLaborStatusSelector(
    BuildContext context,
    Patient patient,
    ThemeData theme,
  ) {
    const laborStatuses = ['Ante', 'Labor', 'Induction', 'TOLAC'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: laborStatuses.map((status) {
        final isSelected = patient.laborStatuses?.contains(status) ?? false;
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: ChoiceChip(
            label: Text(status),
            selected: isSelected,
            onSelected: (selected) {
              _toggleLaborStatus(context, patient, status, selected);
            },
            labelStyle: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildParametersSection(
    BuildContext context,
    Patient patient,
    PatientProvider provider,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Clinical Parameters',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.medical_information_outlined),
              onPressed: () => _addParameter(context, patient, provider),
              tooltip: 'Manage clinical conditions',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Tap the icon above to manage clinical conditions',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection(
    BuildContext context,
    Patient patient,
    PatientProvider provider,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Notes',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.edit_note),
              onPressed: () => _editNotes(context, patient, provider),
              tooltip: 'Edit notes',
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (patient.notes == null || patient.notes!.isEmpty)
          Text(
            'No notes yet. Tap the icon above to add notes.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                patient.notes!,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
      ],
    );
  }

  Color _getTypeColor(PatientType type, ColorScheme colorScheme) {
    switch (type) {
      case PatientType.labor:
        return Colors.red.withValues(alpha: 0.1);
      case PatientType.postpartum:
        return Colors.blue.withValues(alpha: 0.1);
      case PatientType.gynPostOp:
        return Colors.orange.withValues(alpha: 0.1);
      case PatientType.consult:
        return Colors.green.withValues(alpha: 0.1);
    }
  }

  Color _getTypeTextColor(PatientType type, ColorScheme colorScheme) {
    switch (type) {
      case PatientType.labor:
        return Colors.red.shade700;
      case PatientType.postpartum:
        return Colors.blue.shade700;
      case PatientType.gynPostOp:
        return Colors.orange.shade700;
      case PatientType.consult:
        return Colors.green.shade700;
    }
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour > 12
        ? dateTime.hour - 12
        : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '${dateTime.month}/${dateTime.day}/${dateTime.year} $hour:${dateTime.minute.toString().padLeft(2, '0')} $period';
  }

  String _formatClinicalParameter(String key, dynamic value) {
    // Clinical conditions that should display without ": Yes"
    const clinicalConditions = [
      'GHTN',
      'CHTN',
      'Pre-E',
      'DM',
      'GBS',
      'Hyperemesis',
      'Menorrhagia',
      'TOA',
      'Post-op',
      'DVT/PE',
      'Trauma',
      'Cyst',
      'Prolapse',
      'Other',
    ];

    if (clinicalConditions.contains(key)) {
      final valueStr = value?.toString() ?? '';

      // For Pre-E with SF subtype
      if (key == 'Pre-E' && valueStr == 'SF') {
        return 'Pre-E w SF';
      }

      // For Pre-E without subtype or empty subtype
      if (key == 'Pre-E' && (valueStr.isEmpty || valueStr == 'Yes')) {
        return 'Pre-E';
      }

      // For Post-op, show as "s/p {subtype}"
      if (key == 'Post-op' && valueStr.isNotEmpty && valueStr != 'Yes') {
        return 's/p $valueStr';
      }

      // For Post-op without subtype
      if (key == 'Post-op' && (valueStr.isEmpty || valueStr == 'Yes')) {
        return 'Post-op';
      }

      // For TOA, show subtype if present
      if (key == 'TOA' && valueStr.isNotEmpty && valueStr != 'Yes') {
        return valueStr; // Display just the subtype (e.g., "s/p IR Drainage")
      }

      // For TOA without subtype
      if (key == 'TOA' && (valueStr.isEmpty || valueStr == 'Yes')) {
        return 'TOA';
      }

      // For DM and GBS, show with subtype if present
      if ((key == 'DM' || key == 'GBS') &&
          valueStr.isNotEmpty &&
          valueStr != 'Yes') {
        return '$key: $valueStr';
      }

      // For Other, show the custom text if present
      if (key == 'Other' && valueStr.isNotEmpty && valueStr != 'Yes') {
        return valueStr; // Display the custom text
      }

      // For all other clinical conditions, just show the code
      return key;
    }

    // For non-clinical parameters, show key: value format
    final formattedValue = _formatParameterValue(value);
    return '$key: $formattedValue';
  }

  String _formatParameterValue(dynamic value) {
    if (value == null) return 'N/A';
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is DateTime) return _formatDateTime(value);

    final valueStr = value.toString();
    return valueStr.length > 20 ? '${valueStr.substring(0, 20)}...' : valueStr;
  }

  Future<void> _addParameter(
    BuildContext context,
    Patient patient,
    PatientProvider provider,
  ) async {
    final result = await showDialog<Map<String, String?>>(
      context: context,
      builder: (context) => ClinicalConditionsDialog(
        patientType: patient.type,
        currentParameters: patient.parameters,
      ),
    );

    if (result != null) {
      // Remove all clinical conditions first
      final conditionCodes = [
        'GHTN',
        'CHTN',
        'Pre-E',
        'DM',
        'GBS',
        'Hyperemesis',
        'Menorrhagia',
        'TOA',
        'Post-op',
      ];
      for (final code in conditionCodes) {
        if (patient.parameters.containsKey(code)) {
          await provider.removePatientParameter(patient.id, code);
        }
      }

      // Add selected conditions
      for (final entry in result.entries) {
        final value = entry.value?.isNotEmpty == true ? entry.value! : 'Yes';
        await provider.updatePatientParameter(patient.id, entry.key, value);
      }
    }
  }

  Future<void> _editParameter(
    BuildContext context,
    Patient patient,
    PatientProvider provider,
    String currentKey,
    dynamic currentValue,
  ) async {
    await _showParameterDialog(
      context,
      'Edit Parameter',
      currentKey,
      currentValue,
      (newKey, newValue) async {
        if (newKey != currentKey) {
          await provider.removePatientParameter(patient.id, currentKey);
        }
        await provider.updatePatientParameter(patient.id, newKey, newValue);
      },
    );
  }

  Future<void> _showParameterDialog(
    BuildContext context,
    String title,
    String? initialKey,
    dynamic initialValue,
    Future<void> Function(String key, String value) onSave,
  ) async {
    _parameterKeyController.text = initialKey ?? '';
    _parameterValueController.text = initialValue?.toString() ?? '';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _parameterKeyController,
              decoration: const InputDecoration(
                labelText: 'Parameter Name',
                hintText: 'e.g., Blood Pressure, Medications',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _parameterValueController,
              decoration: const InputDecoration(
                labelText: 'Value',
                hintText: 'e.g., 120/80, Tylenol 500mg',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final key = _parameterKeyController.text.trim();
              final value = _parameterValueController.text.trim();

              if (key.isNotEmpty && value.isNotEmpty) {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill in both fields')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      final key = _parameterKeyController.text.trim();
      final value = _parameterValueController.text.trim();

      try {
        await onSave(key, value);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Parameter saved')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save parameter: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteParameter(
    BuildContext context,
    Patient patient,
    PatientProvider provider,
    String key,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Parameter'),
        content: Text('Are you sure you want to delete "$key"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await provider.removePatientParameter(patient.id, key);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Parameter deleted')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete parameter: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _editNotes(
    BuildContext context,
    Patient patient,
    PatientProvider provider,
  ) async {
    _notesController.text = patient.notes ?? '';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Notes'),
        content: TextField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'Notes',
            hintText: 'Enter clinical notes here...',
            border: OutlineInputBorder(),
          ),
          maxLines: 8,
          minLines: 5,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      final notes = _notesController.text.trim();
      try {
        await provider.updatePatient(
          patient.copyWith(notes: notes.isEmpty ? null : notes),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notes saved')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save notes: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _sharePatient(BuildContext context, Patient patient) async {
    try {
      await ShareService.shareSignout(patients: [patient]);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share patient: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _editPatient(BuildContext context, Patient patient) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditPatientScreen(patient: patient),
      ),
    );

    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient updated successfully')),
      );
    }
  }

  Future<void> _handleMenuSelection(
    BuildContext context,
    Patient patient,
    String value,
  ) async {
    switch (value) {
      case 'delete':
        await _deletePatient(context, patient);
        break;
    }
  }

  Future<void> _deletePatient(BuildContext context, Patient patient) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Patient'),
        content: Text('Are you sure you want to delete ${patient.initials}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final provider = Provider.of<PatientProvider>(context, listen: false);
        await provider.deletePatient(patient.id);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${patient.initials} deleted')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete patient: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleRoundedStatus(
    BuildContext context,
    Patient patient,
  ) async {
    try {
      final provider = Provider.of<PatientProvider>(context, listen: false);
      await provider.updatePatient(
        patient.copyWith(isRounded: !patient.isRounded),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _toggleDischargedStatus(
    BuildContext context,
    Patient patient,
  ) async {
    try {
      final provider = Provider.of<PatientProvider>(context, listen: false);
      await provider.updatePatient(
        patient.copyWith(isDischarged: !patient.isDischarged),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _toggleLaborStatus(
    BuildContext context,
    Patient patient,
    String status,
    bool selected,
  ) async {
    try {
      final provider = Provider.of<PatientProvider>(context, listen: false);
      final currentStatuses = List<String>.from(patient.laborStatuses ?? []);

      if (selected) {
        // Add status if not already present
        if (!currentStatuses.contains(status)) {
          currentStatuses.add(status);
        }
      } else {
        // Remove status
        currentStatuses.remove(status);
      }

      await provider.updatePatient(
        patient.copyWith(laborStatuses: currentStatuses),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update labor status: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _showChangePatientTypeDialog(
    BuildContext context,
    Patient patient,
  ) async {
    final result = await showDialog<PatientType>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Patient Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: PatientType.values.map((type) {
            return RadioListTile<PatientType>(
              title: Text(type.displayName),
              value: type,
              groupValue: patient.type,
              onChanged: (value) {
                Navigator.pop(context, value);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (result != null && result != patient.type && context.mounted) {
      // Check if transitioning from Labor to Postpartum
      if (patient.type == PatientType.labor &&
          result == PatientType.postpartum) {
        await _showDeliveryDetailsDialog(context, patient, result);
      } else {
        // Simple type change without delivery details
        await _changePatientType(context, patient, result);
      }
    }
  }

  Future<void> _showDeliveryDetailsDialog(
    BuildContext context,
    Patient patient,
    PatientType newType,
  ) async {
    DateTime deliveryDate = DateTime.now();
    TimeOfDay deliveryTime = TimeOfDay.now();
    String? deliveryMode;
    bool hasBLS = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Delivery Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date picker
                ListTile(
                  title: const Text('Delivery Date'),
                  subtitle: Text(
                    '${deliveryDate.month}/${deliveryDate.day}/${deliveryDate.year}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: deliveryDate,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 7),
                      ),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => deliveryDate = date);
                    }
                  },
                ),
                // Time picker
                ListTile(
                  title: const Text('Delivery Time'),
                  subtitle: Text('${deliveryTime.hour}:00'),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: deliveryTime,
                      builder: (context, child) {
                        return MediaQuery(
                          data: MediaQuery.of(
                            context,
                          ).copyWith(alwaysUse24HourFormat: false),
                          child: child!,
                        );
                      },
                    );
                    if (time != null) {
                      setState(() => deliveryTime = time);
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Delivery Mode:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                // Delivery mode options
                RadioListTile<String>(
                  title: const Text('SVD'),
                  value: 'SVD',
                  groupValue: deliveryMode,
                  onChanged: (value) => setState(() => deliveryMode = value),
                ),
                RadioListTile<String>(
                  title: const Text('VAVD'),
                  value: 'VAVD',
                  groupValue: deliveryMode,
                  onChanged: (value) => setState(() => deliveryMode = value),
                ),
                RadioListTile<String>(
                  title: const Text('C/S'),
                  value: 'C/S',
                  groupValue: deliveryMode,
                  onChanged: (value) => setState(() => deliveryMode = value),
                ),
                RadioListTile<String>(
                  title: const Text('Repeat C/S'),
                  value: 'Repeat C/S',
                  groupValue: deliveryMode,
                  onChanged: (value) => setState(() => deliveryMode = value),
                ),
                const SizedBox(height: 8),
                // BLS checkbox
                CheckboxListTile(
                  title: const Text('BLS'),
                  value: hasBLS,
                  onChanged: (value) => setState(() => hasBLS = value ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: deliveryMode != null
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true && context.mounted) {
      // Combine delivery mode with BLS if checked
      String deliveryInfo = deliveryMode!;
      if (hasBLS) {
        deliveryInfo += ' + BLS';
      }

      // Create DateTime with hour (no minutes)
      final deliveryDateTime = DateTime(
        deliveryDate.year,
        deliveryDate.month,
        deliveryDate.day,
        deliveryTime.hour,
      );

      // Update patient with new type and delivery details
      await _changePatientTypeWithDelivery(
        context,
        patient,
        newType,
        deliveryDateTime,
        deliveryInfo,
      );
    }
  }

  Future<void> _changePatientType(
    BuildContext context,
    Patient patient,
    PatientType newType,
  ) async {
    try {
      final provider = Provider.of<PatientProvider>(context, listen: false);
      await provider.updatePatient(patient.copyWith(type: newType));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Changed to ${newType.displayName}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change patient type: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _changePatientTypeWithDelivery(
    BuildContext context,
    Patient patient,
    PatientType newType,
    DateTime deliveryDateTime,
    String deliveryMode,
  ) async {
    try {
      final provider = Provider.of<PatientProvider>(context, listen: false);

      // Add delivery details to parameters
      final updatedParameters = Map<String, dynamic>.from(patient.parameters);
      updatedParameters['Delivery Date'] = deliveryDateTime.toIso8601String();
      updatedParameters['Delivery Mode'] = deliveryMode;

      await provider.updatePatient(
        patient.copyWith(type: newType, parameters: updatedParameters),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Changed to ${newType.displayName} with delivery details',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change patient type: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
