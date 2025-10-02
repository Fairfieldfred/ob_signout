import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/patient.dart';
import '../models/patient_type.dart';
import '../providers/patient_provider.dart';
import '../services/share_service.dart';
import 'add_edit_patient_screen.dart';

class PatientDetailScreen extends StatefulWidget {
  final String patientId;

  const PatientDetailScreen({
    super.key,
    required this.patientId,
  });

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  final _parameterKeyController = TextEditingController();
  final _parameterValueController = TextEditingController();

  @override
  void dispose() {
    _parameterKeyController.dispose();
    _parameterValueController.dispose();
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

  Widget _buildBody(BuildContext context, Patient patient, PatientProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPatientInfo(context, patient),
          const SizedBox(height: 24),
          _buildParametersSection(context, patient, provider),
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
                Container(
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
                      color: _getTypeTextColor(patient.type, theme.colorScheme),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Created ${_formatDate(patient.createdAt)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
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
        Icon(
          icon,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
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
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _addParameter(context, patient, provider),
              tooltip: 'Add parameter',
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (patient.parameters.isEmpty)
          _buildNoParametersState(context)
        else
          _buildParametersList(context, patient, provider),
      ],
    );
  }

  Widget _buildNoParametersState(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.note_add_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No clinical parameters yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add clinical parameters like vitals, medications, or other relevant information.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParametersList(
    BuildContext context,
    Patient patient,
    PatientProvider provider,
  ) {
    final parameters = patient.parameters.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Column(
      children: parameters.map((param) {
        return _buildParameterCard(
          context,
          param.key,
          param.value,
          patient,
          provider,
        );
      }).toList(),
    );
  }

  Widget _buildParameterCard(
    BuildContext context,
    String key,
    dynamic value,
    Patient patient,
    PatientProvider provider,
  ) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          key,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          _formatParameterValue(value),
          style: theme.textTheme.bodyMedium,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'edit') {
              _editParameter(context, patient, provider, key, value);
            } else if (action == 'delete') {
              _deleteParameter(context, patient, provider, key);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
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
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '${dateTime.month}/${dateTime.day}/${dateTime.year} $hour:${dateTime.minute.toString().padLeft(2, '0')} $period';
  }

  String _formatParameterValue(dynamic value) {
    if (value == null) return 'N/A';
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is DateTime) return _formatDateTime(value);
    return value.toString();
  }

  Future<void> _addParameter(
    BuildContext context,
    Patient patient,
    PatientProvider provider,
  ) async {
    await _showParameterDialog(
      context,
      'Add Parameter',
      null,
      null,
      (key, value) async {
        await provider.updatePatientParameter(patient.id, key, value);
      },
    );
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
                  const SnackBar(
                    content: Text('Please fill in both fields'),
                  ),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Parameter saved')),
          );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Parameter deleted')),
          );
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
}