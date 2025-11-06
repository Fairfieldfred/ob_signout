import 'package:flutter/material.dart';

import '../models/patient.dart';
import '../models/patient_type.dart';

class PatientCard extends StatelessWidget {
  final Patient patient;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool showDeleteButton;

  const PatientCard({
    super.key,
    required this.patient,
    this.onTap,
    this.onDelete,
    this.showDeleteButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row with badge and patient info inline
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient Type Badge and Room Number Column
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Patient Type Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getTypeColor(patient.type, colorScheme),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          patient.type.shortName,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _getTypeTextColor(patient.type, colorScheme),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Room Number
                      if (patient.roomNumber.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Rm. ${patient.roomNumber}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Patient Information
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // First line: Initials and Labor status
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              patient.initials,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            // Labor statuses for Labor patients (inline after initials)
                            if (patient.type == PatientType.labor &&
                                patient.laborStatuses != null &&
                                patient.laborStatuses!.isNotEmpty)
                              ...patient.laborStatuses!.map(
                                (status) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    status,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            // Post-delivery day for Postpartum patients (inline after initials)
                            if (patient.type == PatientType.postpartum &&
                                patient.postDeliveryDayString != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  patient.postDeliveryDayString!,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSecondaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        // Second line: Age, G/P, GA (always on second line)
                        if (patient.combinedInfoString.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            patient.combinedInfoString,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Status boxes (Rounded and D/C) - NOT shown for Labor patients
                  if (patient.type != PatientType.labor) ...[
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Rounded status box
                        if (patient.isRounded)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.2),
                              border: Border.all(
                                color: Colors.green.shade700,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Rounded',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (patient.isRounded && patient.isDischarged)
                          const SizedBox(height: 4),
                        // Discharged status box
                        if (patient.isDischarged)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.2),
                              border: Border.all(
                                color: Colors.blue.shade700,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'D/C\'d',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],

                  // Delete Button
                  if (showDeleteButton && onDelete != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: onDelete,
                      iconSize: 20,
                      color: colorScheme.error,
                      tooltip: 'Delete patient',
                    ),
                  ],
                ],
              ),
              // Parameters Preview
              if (patient.parameters.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildParametersPreview(context),
              ],
              // Notes Preview
              if (patient.notes != null && patient.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildNotesPreview(context),
              ],
              // Last Updated
              // const SizedBox(height: 8),
              // Row(
              //   children: [
              //     Icon(
              //       Icons.access_time,
              //       size: 14,
              //       color: colorScheme.onSurfaceVariant,
              //     ),
              //     const SizedBox(width: 4),
              //     Text(
              //       'Updated ${_formatLastUpdated(patient.updatedAt)}',
              //       style: theme.textTheme.labelSmall?.copyWith(
              //         color: colorScheme.onSurfaceVariant,
              //       ),
              //     ),
              //   ],
              // ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParametersPreview(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Show all parameters except Delivery Date and Delivery Mode
    final allParams = patient.parameters.entries
        .where(
          (param) =>
              param.key != 'Delivery Date' && param.key != 'Delivery Mode',
        )
        .toList();

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: allParams.map((param) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _formatClinicalParameter(param.key, param.value),
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNotesPreview(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Truncate notes if they're too long
    final notesText = patient.notes!;
    final displayText = notesText.length > 100
        ? '${notesText.substring(0, 100)}...'
        : notesText;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.note_outlined,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              displayText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
    return '$key: ${_formatParameterValue(value)}';
  }

  String _formatParameterValue(dynamic value) {
    if (value == null) return 'N/A';
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is DateTime) return '${value.month}/${value.day}/${value.year}';

    final valueStr = value.toString();
    return valueStr.length > 20 ? '${valueStr.substring(0, 20)}...' : valueStr;
  }

  String _formatLastUpdated(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
