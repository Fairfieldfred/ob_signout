import 'package:flutter/material.dart';

import '../models/clinical_condition.dart';
import '../models/patient_type.dart';

/// Dialog for selecting clinical conditions based on patient type.
class ClinicalConditionsDialog extends StatefulWidget {
  final PatientType patientType;
  final Map<String, dynamic> currentParameters;

  const ClinicalConditionsDialog({
    super.key,
    required this.patientType,
    required this.currentParameters,
  });

  @override
  State<ClinicalConditionsDialog> createState() =>
      _ClinicalConditionsDialogState();
}

class _ClinicalConditionsDialogState extends State<ClinicalConditionsDialog> {
  final Map<String, String?> _selectedConditions = {};
  final TextEditingController _otherController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentConditions();
  }

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  void _loadCurrentConditions() {
    final conditions = _getConditionsForType();
    for (final condition in conditions) {
      // Check if this condition exists in current parameters
      if (widget.currentParameters.containsKey(condition.code)) {
        final value = widget.currentParameters[condition.code]?.toString();
        _selectedConditions[condition.code] = value;

        // Populate the text controller for "Other"
        if (condition.code == 'Other' && value != null && value.isNotEmpty) {
          _otherController.text = value;
        }
      }
    }
  }

  List<ClinicalCondition> _getConditionsForType() {
    switch (widget.patientType) {
      case PatientType.labor:
        return ClinicalConditions.laborConditions;
      case PatientType.postpartum:
        return ClinicalConditions.postpartumConditions;
      case PatientType.gynPostOp:
        return ClinicalConditions.gynConditions;
      case PatientType.consult:
        return ClinicalConditions.consultConditions;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final conditions = _getConditionsForType();

    if (conditions.isEmpty) {
      return AlertDialog(
        title: const Text('Clinical Conditions'),
        content: const Text(
          'No clinical conditions are defined for this patient type yet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('Clinical Conditions'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: conditions.map((condition) {
            return _buildConditionTile(condition, theme);
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selectedConditions),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildConditionTile(ClinicalCondition condition, ThemeData theme) {
    final isSelected = _selectedConditions.containsKey(condition.code);
    final selectedSubtype = _selectedConditions[condition.code];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          CheckboxListTile(
            title: Text(
              condition.displayName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(condition.code, style: theme.textTheme.bodySmall),
            value: isSelected,
            onChanged: (checked) {
              setState(() {
                if (checked == true) {
                  // Default to empty string (no subtype selected)
                  _selectedConditions[condition.code] = '';
                } else {
                  _selectedConditions.remove(condition.code);
                }
              });
            },
          ),
          // Show text field for "Other" to allow custom input
          if (isSelected && condition.code == 'Other') ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _otherController,
                decoration: const InputDecoration(
                  labelText: 'Specify other condition',
                  hintText: 'Enter condition details',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) {
                  setState(() {
                    _selectedConditions[condition.code] = value;
                  });
                },
              ),
            ),
          ],
          // Show subtype selector if condition is selected and has subtypes
          if (isSelected && condition.subtypes != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Expanded(
                child: Wrap(
                  spacing: 8,
                  children: [
                    // Add "None" option for Pre-E to allow deselecting SF
                    if (condition.code == 'Pre-E')
                      ChoiceChip(
                        label: const Text('None'),
                        selected:
                            selectedSubtype == '' || selectedSubtype == null,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedConditions[condition.code] = '';
                            });
                          }
                        },
                      ),
                    ...condition.subtypes!.map((subtype) {
                      final isSubtypeSelected = selectedSubtype == subtype;
                      return ChoiceChip(
                        label: Text(subtype),
                        selected: isSubtypeSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedConditions[condition.code] = subtype;
                            });
                          }
                        },
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
