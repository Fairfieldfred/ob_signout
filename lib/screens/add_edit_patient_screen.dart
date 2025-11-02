import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/patient.dart';
import '../models/patient_type.dart';
import '../providers/patient_provider.dart';

class AddEditPatientScreen extends StatefulWidget {
  final Patient? patient;

  const AddEditPatientScreen({super.key, this.patient});

  bool get isEditing => patient != null;

  @override
  State<AddEditPatientScreen> createState() => _AddEditPatientScreenState();
}

class _AddEditPatientScreenState extends State<AddEditPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _initialsController = TextEditingController();
  final _roomNumberController = TextEditingController();
  final _ageController = TextEditingController();
  final _gravidaController = TextEditingController();
  final _paraController = TextEditingController();
  final _gestationalWeeksController = TextEditingController();
  final _gestationalDaysController = TextEditingController();

  PatientType _selectedType = PatientType.labor;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    if (widget.isEditing) {
      final patient = widget.patient!;
      _initialsController.text = patient.initials;
      _roomNumberController.text = patient.roomNumber;
      _ageController.text = patient.age?.toString() ?? '';
      _gravidaController.text = patient.gravida?.toString() ?? '';
      _paraController.text = patient.para?.toString() ?? '';
      _gestationalWeeksController.text =
          patient.gestationalAgeWeeks?.toString() ?? '';
      _gestationalDaysController.text =
          patient.gestationalAgeDays?.toString() ?? '';
      _selectedType = patient.type;
    }
  }

  @override
  void dispose() {
    _initialsController.dispose();
    _roomNumberController.dispose();
    _ageController.dispose();
    _gravidaController.dispose();
    _paraController.dispose();
    _gestationalWeeksController.dispose();
    _gestationalDaysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Patient' : 'Add Patient'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _savePatient,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Save',
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // _buildPrivacyNotice(context),
              // const SizedBox(height: 24),
              _buildInitialsField(),
              const SizedBox(height: 16),
              _buildRoomNumberField(),
              const SizedBox(height: 16),
              _buildPatientTypeSelector(),
              const SizedBox(height: 16),
              _buildDemographicFields(),
              const SizedBox(height: 16),
              _buildObstetricFields(),
              const SizedBox(height: 24),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyNotice(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.privacy_tip_outlined,
              color: theme.colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Privacy Notice',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Only enter initials and room number. No full names, MRN, DOB, or other PHI.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialsField() {
    return TextFormField(
      controller: _initialsController,
      decoration: const InputDecoration(
        labelText: 'Patient Initials *',
        hintText: 'e.g., JD, AB',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.person_outline),
      ),
      textCapitalization: TextCapitalization.characters,
      maxLength: 5,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter patient initials';
        }
        if (value.trim().length < 2) {
          return 'Please enter at least 2 characters';
        }
        return null;
      },
    );
  }

  Widget _buildRoomNumberField() {
    return TextFormField(
      controller: _roomNumberController,
      decoration: const InputDecoration(
        labelText: 'Room Number *',
        hintText: 'e.g., L&D 5, PP 12, OR 3',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.location_on_outlined),
      ),
      textCapitalization: TextCapitalization.characters,
      maxLength: 10,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter room number';
        }
        return null;
      },
    );
  }

  Widget _buildPatientTypeSelector() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Patient Type *',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PatientType.values.map((type) {
            final isSelected = _selectedType == type;
            return FilterChip(
              label: Text(type.displayName),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedType = type;
                  });
                }
              },
              backgroundColor: theme.colorScheme.surface,
              selectedColor: theme.colorScheme.primaryContainer,
              side: BorderSide(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDemographicFields() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Demographics',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ageController,
              decoration: const InputDecoration(
                labelText: 'Age',
                hintText: 'e.g., 28',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.cake_outlined),
                suffixText: 'years',
              ),
              keyboardType: TextInputType.number,
              maxLength: 3,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final age = int.tryParse(value);
                  if (age == null || age < 0 || age > 120) {
                    return 'Please enter a valid age (0-120)';
                  }
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildObstetricFields() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Obstetric History',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _gravidaController,
                    decoration: const InputDecoration(
                      labelText: 'Gravida',
                      hintText: 'G',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.pregnant_woman_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 2,
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final gravida = int.tryParse(value);
                        if (gravida == null || gravida < 0) {
                          return 'Invalid';
                        }
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _paraController,
                    decoration: const InputDecoration(
                      labelText: 'Para',
                      hintText: 'P',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.child_care_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 2,
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final para = int.tryParse(value);
                        if (para == null || para < 0) {
                          return 'Invalid';
                        }
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _gestationalWeeksController,
                    decoration: const InputDecoration(
                      labelText: 'GA Weeks',
                      hintText: 'e.g., 38',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.schedule_outlined),
                      suffixText: 'wk',
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 2,
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final weeks = int.tryParse(value);
                        if (weeks == null || weeks < 0 || weeks > 42) {
                          return '0-42 only';
                        }
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _gestationalDaysController,
                    decoration: const InputDecoration(
                      labelText: 'GA Days',
                      hintText: 'e.g., 2',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                      suffixText: 'd',
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final days = int.tryParse(value);
                        if (days == null || days < 0 || days > 6) {
                          return '0-6 only';
                        }
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _savePatient,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                widget.isEditing ? 'Update Patient' : 'Add Patient',
                style: const TextStyle(fontSize: 16),
              ),
      ),
    );
  }

  Future<void> _savePatient() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final patientProvider = Provider.of<PatientProvider>(
      context,
      listen: false,
    );

    setState(() {
      _isLoading = true;
    });

    try {
      final initials = _initialsController.text.trim();
      final roomNumber = _roomNumberController.text.trim();
      final age = _ageController.text.trim().isNotEmpty
          ? int.tryParse(_ageController.text.trim())
          : null;
      final gravida = _gravidaController.text.trim().isNotEmpty
          ? int.tryParse(_gravidaController.text.trim())
          : null;
      final para = _paraController.text.trim().isNotEmpty
          ? int.tryParse(_paraController.text.trim())
          : null;
      final gestationalWeeks =
          _gestationalWeeksController.text.trim().isNotEmpty
          ? int.tryParse(_gestationalWeeksController.text.trim())
          : null;
      final gestationalDays = _gestationalDaysController.text.trim().isNotEmpty
          ? int.tryParse(_gestationalDaysController.text.trim())
          : null;

      // Set gestationalAgeSetDate only if both weeks and days are provided
      DateTime? gestationalAgeSetDate;
      if (gestationalWeeks != null && gestationalDays != null) {
        // If editing and GA values haven't changed, keep the original set date
        if (widget.isEditing &&
            widget.patient!.gestationalAgeWeeks == gestationalWeeks &&
            widget.patient!.gestationalAgeDays == gestationalDays) {
          gestationalAgeSetDate = widget.patient!.gestationalAgeSetDate;
        } else {
          // New GA or changed GA - set to today
          gestationalAgeSetDate = DateTime.now();
        }
      }

      // Check for room number conflicts
      final isRoomTaken = await patientProvider.isRoomNumberTaken(
        roomNumber,
        widget.isEditing ? widget.patient!.id : null,
      );

      if (isRoomTaken && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Room number is already taken by another patient'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      if (widget.isEditing) {
        // Update existing patient
        final updatedPatient = widget.patient!.copyWith(
          initials: initials,
          roomNumber: roomNumber,
          type: _selectedType,
          age: age,
          gravida: gravida,
          para: para,
          gestationalAgeWeeks: gestationalWeeks,
          gestationalAgeDays: gestationalDays,
          gestationalAgeSetDate: gestationalAgeSetDate,
        );
        await patientProvider.updatePatient(updatedPatient);
      } else {
        // Add new patient
        await patientProvider.addPatient(
          initials: initials,
          roomNumber: roomNumber,
          type: _selectedType,
          age: age,
          gravida: gravida,
          para: para,
          gestationalAgeWeeks: gestationalWeeks,
          gestationalAgeDays: gestationalDays,
          gestationalAgeSetDate: gestationalAgeSetDate,
        );
      }

      if (context.mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save patient: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
