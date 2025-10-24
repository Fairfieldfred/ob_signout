import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/patient.dart';
import '../models/patient_type.dart';
import '../providers/patient_provider.dart';
import '../services/share_service.dart';
import '../services/transfer_manager.dart';
import '../services/transfer_strategy.dart';
import '../widgets/patient_card.dart';
import '../widgets/transfer_method_dialog.dart';
import 'add_edit_patient_screen.dart';
import 'ble_receive_screen.dart';
import 'ble_transfer_screen.dart';
import 'import_preview_screen.dart';
import 'nearby_receive_screen.dart';
import 'nearby_transfer_screen.dart';
import 'patient_detail_screen.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  final TransferManager _transferManager = TransferManager();

  @override
  void dispose() {
    _transferManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PatientProvider>(
      builder: (context, patientProvider, child) {
        return Scaffold(
          appBar: _buildAppBar(context, patientProvider),
          body: _buildBody(context, patientProvider),
          floatingActionButton: _buildFAB(context),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    PatientProvider patientProvider,
  ) {
    final theme = Theme.of(context);
    final patientCounts = patientProvider.patientCountsByType;

    return AppBar(
      title: Column(
        children: [
          const Text('OB Signout'),
          if (patientProvider.totalPatientCount > 0)
            Text(
              '${patientProvider.totalPatientCount} patients',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.file_download_outlined),
          tooltip: 'Import patients',
          onSelected: (value) => _handleImportOption(context, value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'import_paste',
              child: Row(
                children: [
                  Icon(Icons.paste),
                  SizedBox(width: 8),
                  Text('Paste data'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'import_nearby',
              child: Row(
                children: [
                  Icon(Icons.share),
                  SizedBox(width: 8),
                  Text('Receive via nearby'),
                ],
              ),
            ),
          ],
        ),
        if (patientProvider.totalPatientCount > 0) ...[
          IconButton(
            icon: Icon(Platform.isIOS ? Icons.ios_share : Icons.share),
            tooltip: 'Smart Share',
            onPressed: () => _smartShare(context, patientProvider),
          ),
          PopupMenuButton<String>(
            onSelected: (value) =>
                _handleMenuSelection(context, patientProvider, value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.clear_all),
                    SizedBox(width: 8),
                    Text('Clear all patients'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
      bottom: patientProvider.totalPatientCount > 1
          ? _buildFilterTabs(context, patientProvider, patientCounts)
          : null,
    );
  }

  PreferredSizeWidget _buildFilterTabs(
    BuildContext context,
    PatientProvider patientProvider,
    Map<PatientType, int> patientCounts,
  ) {
    final theme = Theme.of(context);

    return PreferredSize(
      preferredSize: const Size.fromHeight(48),
      child: Container(
        color: theme.colorScheme.surface,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                context,
                'All (${patientProvider.totalPatientCount})',
                patientProvider.selectedTypeFilter == null,
                () => patientProvider.clearTypeFilter(),
              ),
              ...PatientType.values.map((type) {
                final count = patientCounts[type] ?? 0;
                if (count == 0) return const SizedBox.shrink();

                return _buildFilterChip(
                  context,
                  '${type.displayName} ($count)',
                  patientProvider.selectedTypeFilter == type,
                  () => patientProvider.setTypeFilter(type),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        backgroundColor: theme.colorScheme.surface,
        selectedColor: theme.colorScheme.primaryContainer,
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outline,
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, PatientProvider patientProvider) {
    if (patientProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (patientProvider.error != null) {
      return _buildErrorState(context, patientProvider);
    }

    final filteredPatients = patientProvider.filteredPatients;

    if (filteredPatients.isEmpty) {
      return _buildEmptyState(context, patientProvider);
    }

    return RefreshIndicator(
      onRefresh: () => patientProvider.loadPatients(),
      child: ListView.builder(
        itemCount: filteredPatients.length,
        itemBuilder: (context, index) {
          final patient = filteredPatients[index];
          return PatientCard(
            patient: patient,
            onTap: () => _navigateToPatientDetail(context, patient),
            onDelete: () => _deletePatient(context, patientProvider, patient),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    PatientProvider patientProvider,
  ) {
    final theme = Theme.of(context);
    final hasFilter = patientProvider.selectedTypeFilter != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFilter ? Icons.filter_list : Icons.local_hospital_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              hasFilter
                  ? 'No ${patientProvider.selectedTypeFilter!.displayName.toLowerCase()} patients'
                  : 'No patients yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilter
                  ? 'Try selecting a different patient type or clear the filter'
                  : 'Add your first patient to get started with signout',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (hasFilter) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: patientProvider.clearTypeFilter,
                child: const Text('Clear filter'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    PatientProvider patientProvider,
  ) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              patientProvider.error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                patientProvider.clearError();
                patientProvider.loadPatients();
              },
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _navigateToAddPatient(context),
      tooltip: 'Add patient',
      child: const Icon(Icons.add),
    );
  }

  Future<void> _navigateToAddPatient(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const AddEditPatientScreen()),
    );

    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient added successfully')),
      );
    }
  }

  Future<void> _navigateToPatientDetail(
    BuildContext context,
    Patient patient,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientDetailScreen(patientId: patient.id),
      ),
    );
  }

  Future<void> _deletePatient(
    BuildContext context,
    PatientProvider patientProvider,
    Patient patient,
  ) async {
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
        await patientProvider.deletePatient(patient.id);
        if (context.mounted) {
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


  /// Smart share - shows transfer method dialog and handles the selected method.
  Future<void> _smartShare(
    BuildContext context,
    PatientProvider patientProvider,
  ) async {
    try {
      if (!context.mounted) return;

      final patients = List<Patient>.from(patientProvider.patients);

      if (patients.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No patients to share')),
        );
        return;
      }

      // Calculate estimated data size
      final jsonData = ShareService.createObsFileData(patients, 'Sender', null);
      final dataSize = utf8.encode(jsonData).length;

      // Show transfer method dialog
      final selectedMethod = await TransferMethodDialog.show(
        context: context,
        transferManager: _transferManager,
        estimatedDataSizeBytes: dataSize,
      );

      if (selectedMethod == null || !context.mounted) return;

      // Get sender name
      final senderName = await _showSenderNameDialog(context);
      if (senderName == null || !context.mounted) return;

      // Handle the selected method
      await _executeTransfer(
        context,
        selectedMethod,
        patients,
        senderName,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Smart share failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Executes the transfer using the selected method.
  Future<void> _executeTransfer(
    BuildContext context,
    TransferMethod method,
    List<Patient> patients,
    String senderName,
  ) async {
    try {
      if (!context.mounted) return;

      // For WiFi transfer, navigate to the existing screen
      if (method == TransferMethod.wifi) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NearbyTransferScreen(
              patients: patients,
              senderName: senderName,
            ),
          ),
        );
        return;
      }

      // For Bluetooth transfer, navigate to the BLE screen
      if (method == TransferMethod.bluetooth) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BleTransferScreen(
              patients: patients,
              senderName: senderName,
            ),
          ),
        );
        return;
      }

      // For AirDrop and Nearby Share, use the transfer manager
      final result = await _transferManager.send(
        method: method,
        patients: patients,
        senderName: senderName,
        notes: 'Patient signout data from ${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}',
      );

      if (!context.mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${method.displayName} share initiated'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Transfer failed'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transfer failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }


  Future<String?> _showSenderNameDialog(BuildContext context) async {
    final controller = TextEditingController();

    try {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Share Patient Data'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter your name to identify this signout:'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Your name',
                  hintText: 'e.g., Dr. Smith',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(context, name);
                }
              },
              child: const Text('Share'),
            ),
          ],
        ),
      );
      return result;
    } finally {
      // Use a post-frame callback to dispose after the current frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.dispose();
      });
    }
  }

  Future<void> _handleImportOption(BuildContext context, String value) async {
    switch (value) {
      case 'import_paste':
        _showPasteDataDialog(context);
        break;
      case 'import_nearby':
        _navigateToNearbyReceive(context);
        break;
    }
  }

  Future<void> _showPasteDataDialog(BuildContext context) async {
    final controller = TextEditingController();

    try {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Paste Patient Data'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Paste the patient data JSON here:'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Paste JSON data here...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 10,
                minLines: 5,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final data = controller.text.trim();
                if (data.isNotEmpty) {
                  Navigator.pop(context, data);
                }
              },
              child: const Text('Import'),
            ),
          ],
        ),
      );

      if (result != null && context.mounted) {
        _processImportData(context, result);
      }
    } finally {
      // Use a post-frame callback to dispose after the current frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.dispose();
      });
    }
  }

  Future<void> _processImportData(BuildContext context, String jsonData) async {
    try {
      final importResult = ShareService.parseObsData(jsonData);

      if (!importResult.success) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(importResult.error ?? 'Import failed'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ImportPreviewScreen(importResult: importResult),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process import data: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleMenuSelection(
    BuildContext context,
    PatientProvider patientProvider,
    String value,
  ) async {
    switch (value) {
      case 'clear_all':
        await _clearAllPatients(context, patientProvider);
        break;
    }
  }

  Future<void> _clearAllPatients(
    BuildContext context,
    PatientProvider patientProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Patients'),
        content: Text(
          'Are you sure you want to delete all ${patientProvider.totalPatientCount} patients? This cannot be undone.',
        ),
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
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await patientProvider.deleteAllPatients();
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('All patients cleared')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to clear patients: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }


  Future<void> _navigateToNearbyReceive(BuildContext context) async {
    try {
      // Show dialog to choose receive method
      final method = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Choose Receive Method'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.wifi),
                title: const Text('WiFi'),
                subtitle: const Text('Faster, requires network'),
                onTap: () => Navigator.pop(context, 'wifi'),
              ),
              ListTile(
                leading: const Icon(Icons.bluetooth),
                title: const Text('Bluetooth'),
                subtitle: const Text('Slower, works offline'),
                onTap: () => Navigator.pop(context, 'bluetooth'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (method == null || !context.mounted) return;

      if (method == 'wifi') {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const NearbyReceiveScreen()),
        );
      } else if (method == 'bluetooth') {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const BleReceiveScreen()),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start receive: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
