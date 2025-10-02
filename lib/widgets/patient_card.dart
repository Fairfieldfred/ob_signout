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
              Row(
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
                  const SizedBox(width: 12),
                  // Patient Information
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              patient.initials,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (patient.ageString.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                patient.ageString,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          'Room ${patient.roomNumber}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (patient.gravidaParaString.isNotEmpty || patient.gestationalAgeString.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            children: [
                              if (patient.gravidaParaString.isNotEmpty)
                                Text(
                                  patient.gravidaParaString,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              if (patient.gestationalAgeString.isNotEmpty)
                                Text(
                                  'GA: ${patient.gestationalAgeString}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  // Parameter Count
                  if (patient.parameters.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${patient.parameters.length}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
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
              // Last Updated
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Updated ${_formatLastUpdated(patient.updatedAt)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParametersPreview(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Show first 3 parameters
    final previewParams = patient.parameters.entries.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: previewParams.map((param) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${param.key}: ${_formatParameterValue(param.value)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            );
          }).toList(),
        ),
        if (patient.parameters.length > 3) ...[
          const SizedBox(height: 4),
          Text(
            '+ ${patient.parameters.length - 3} more parameters',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
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