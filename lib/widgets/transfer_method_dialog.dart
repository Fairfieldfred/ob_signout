import 'package:flutter/material.dart';
import '../services/transfer_manager.dart';
import '../services/transfer_strategy.dart';

/// Dialog for selecting a transfer method.
///
/// Shows available transfer methods with descriptions, icons, and recommendations.
class TransferMethodDialog extends StatelessWidget {
  final TransferManager transferManager;
  final int estimatedDataSizeBytes;
  final TransferMethodRecommendation? recommendation;

  const TransferMethodDialog({
    super.key,
    required this.transferManager,
    this.estimatedDataSizeBytes = 50000,
    this.recommendation,
  });

  @override
  Widget build(BuildContext context) {
    final availableMethods = transferManager.getAvailableMethods();

    return AlertDialog(
      title: const Text('Choose Transfer Method'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (recommendation != null) ...[
                _buildRecommendationBanner(context, recommendation!),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
              ],
              ...availableMethods.map((method) {
                final isRecommended = recommendation?.method == method;
                return _buildMethodTile(
                  context,
                  method,
                  isRecommended: isRecommended,
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildRecommendationBanner(
    BuildContext context,
    TransferMethodRecommendation recommendation,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: Theme.of(context).primaryColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recommended: ${recommendation.method.displayName}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  recommendation.reason,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Estimated time: ${recommendation.estimatedTimeDisplay}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodTile(
    BuildContext context,
    TransferMethod method, {
    bool isRecommended = false,
  }) {
    return Card(
      elevation: isRecommended ? 3 : 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _getMethodIcon(method, context),
        title: Row(
          children: [
            Flexible(
              child: Text(
                method.displayName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isRecommended) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'BEST',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          method.description,
          style: Theme.of(context).textTheme.bodySmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => Navigator.of(context).pop(method),
      ),
    );
  }

  Widget _getMethodIcon(TransferMethod method, BuildContext context) {
    IconData iconData;
    Color iconColor;

    switch (method) {
      case TransferMethod.airdrop:
        iconData = Icons.rss_feed; // iOS-style sharing
        iconColor = Colors.blue;
        break;
      case TransferMethod.nearbyShare:
        iconData = Icons.share; // Android-style sharing
        iconColor = Colors.green;
        break;
      case TransferMethod.wifi:
        iconData = Icons.wifi;
        iconColor = Colors.orange;
        break;
      case TransferMethod.bluetooth:
        iconData = Icons.bluetooth;
        iconColor = Colors.lightBlue;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, color: iconColor, size: 28),
    );
  }

  /// Shows the transfer method dialog and returns the selected method.
  ///
  /// Returns null if the user cancels the dialog.
  static Future<TransferMethod?> show({
    required BuildContext context,
    required TransferManager transferManager,
    int estimatedDataSizeBytes = 50000,
    bool? targetIsIOS,
    bool? targetIsAndroid,
  }) async {
    final recommendation = await transferManager.recommendMethod(
      targetIsIOS: targetIsIOS,
      targetIsAndroid: targetIsAndroid,
      estimatedDataSizeBytes: estimatedDataSizeBytes,
    );

    if (!context.mounted) return null;

    return await showDialog<TransferMethod>(
      context: context,
      builder: (context) => TransferMethodDialog(
        transferManager: transferManager,
        estimatedDataSizeBytes: estimatedDataSizeBytes,
        recommendation: recommendation,
      ),
    );
  }
}
